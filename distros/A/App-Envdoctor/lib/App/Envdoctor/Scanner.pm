package App::Envdoctor::Scanner;

# Core scanner: reconcile %ENV access in Perl source against .env definitions.
# Local-first — no network, values never printed.

use strict;
use warnings;
use File::Find ();
use File::Spec ();

our $VERSION = '0.1.0';

my @USAGE = ( qr/\$ENV\{\s*["']?([A-Za-z_]\w*)["']?\s*\}/ );

sub _blank {
    my $s = shift;
    $s =~ s/[^\n]/ /g;
    return $s;
}

sub strip_noise {
    my ($code) = @_;
    # POD blocks: =word ... =cut
    $code =~ s/(^=\w+.*?^=cut[^\n]*)/_blank($1)/gems;
    # line comments
    $code =~ s/(#[^\n]*)/_blank($1)/ge;
    return $code;
}

sub scan_source {
    my ( $path, $content ) = @_;
    my $text = strip_noise($content);
    my %used;
    for my $re (@USAGE) {
        while ( $text =~ /$re/g ) {
            my $name  = $1;
            my $start = pos($text) - length($&);
            next if exists $used{$name};
            my $pre = substr( $text, 0, $start );
            my $line = ( $pre =~ tr/\n// ) + 1;
            $used{$name} = { file => $path, line => $line };
        }
    }
    return \%used;
}

# Collect ALL occurrences per key within a single file, in order.
# Returns { KEY => [ { line => N, value => V }, ... ] }.
# The value (text right of the first '='; trimmed; one matching quote pair
# stripped) is used ONLY for detection and is NEVER emitted in output.
sub parse_env {
    my ( $path, $content ) = @_;
    my %def;
    my $i = 0;
    for my $raw ( split /\n/, $content, -1 ) {
        $i++;
        my $t = $raw;
        $t =~ s/^\s+|\s+$//g;
        next if $t eq '' || $t =~ /^#/;
        if ( $raw =~ /^\s*(?:export\s+)?([A-Za-z_]\w*)\s*=(.*)$/s ) {
            my ( $key, $val ) = ( $1, $2 );
            $val =~ s/^\s+|\s+$//g;
            if ( length($val) >= 2
                && ( ( substr( $val, 0, 1 ) eq '"' && substr( $val, -1 ) eq '"' )
                    || ( substr( $val, 0, 1 ) eq "'" && substr( $val, -1 ) eq "'" ) ) )
            {
                $val = substr( $val, 1, length($val) - 2 );
            }
            push @{ $def{$key} }, { line => $i, value => $val };
        }
    }
    return \%def;
}

# Derive an env label from a .env filename. Returns undef for *.example.
sub env_label {
    my ($name) = @_;
    return undef if $name =~ /\.example$/;
    return 'default' if $name eq '.env';
    return undef unless $name =~ /^\.env\.(.+)$/;
    my $x = $1;
    $x =~ s/\.local$// if $x ne 'local';
    return $x;
}

# Infer a coarse type from a value string.
sub infer_type {
    my ($v) = @_;
    return 'empty'   if $v eq '';
    return 'integer' if $v =~ /^-?\d+$/;
    return 'float'   if $v =~ /^-?\d+\.\d+$/;
    return 'boolean' if $v =~ /^(?:true|false)$/i;
    return 'url'     if $v =~ m{^https?://};
    if ( $v =~ /^[\{\[]/ ) {
        require JSON::PP;
        my $ok = eval { JSON::PP::decode_json($v); 1 };
        return 'json' if $ok;
    }
    return 'string';
}

# Compatibility group for a non-empty inferred type.
sub _type_group {
    my ($t) = @_;
    return 'numeric' if $t eq 'integer' || $t eq 'float';
    return $t;
}

my $SECRET_NAME = qr/SECRET|TOKEN|PASSWORD|PASSWD|PRIVATE|CREDENTIAL|API_?KEY|ACCESS_?KEY|AUTH/i;
my $WEAK_VALUE
    = qr/^(?:changeme|change_me|placeholder|x{3,}|todo|secret|password|passwd|test|example|sample|dummy|your[_-].*|<.*>|\$\{.*\})$/i;

sub _is_weak_secret {
    my ($v) = @_;
    return 1 if $v eq '' || length($v) < 8;
    return $v =~ $WEAK_VALUE ? 1 : 0;
}

# Levenshtein edit distance.
sub levenshtein {
    my ( $a, $b ) = @_;
    my @a = split //, $a;
    my @b = split //, $b;
    my @d = ( 0 .. @b );
    for my $i ( 1 .. @a ) {
        my $prev = $d[0];
        $d[0] = $i;
        for my $j ( 1 .. @b ) {
            my $tmp  = $d[$j];
            my $cost = ( $a[ $i - 1 ] eq $b[ $j - 1 ] ) ? 0 : 1;
            my $min  = $d[ $j - 1 ] + 1;
            $min = $d[$j] + 1     if $d[$j] + 1 < $min;
            $min = $prev + $cost  if $prev + $cost < $min;
            $d[$j] = $min;
            $prev  = $tmp;
        }
    }
    return $d[-1];
}

# Best typo suggestion for an undefined used name among defined names.
sub _typo_suggestion {
    my ( $u, $defined ) = @_;
    my ( $best, $best_dist );
    for my $d ( sort @$defined ) {
        next if $d eq $u;
        my $min_len = length($u) < length($d) ? length($u) : length($d);
        my $thresh  = $min_len <= 4 ? 1 : 2;
        my $dist    = levenshtein( $u, $d );
        next if $dist > $thresh;
        if ( !defined $best_dist || $dist < $best_dist ) {
            $best_dist = $dist;
            $best      = $d;
        }
    }
    return $best;
}

my @PUBLIC_PREFIXES = qw(
    NEXT_PUBLIC_ VITE_ REACT_APP_ EXPO_PUBLIC_
    GATSBY_ NUXT_PUBLIC_ VUE_APP_ PUBLIC_
);

sub _is_public_secret {
    my ($name) = @_;
    my $has_prefix = 0;
    for my $p (@PUBLIC_PREFIXES) {
        if ( index( $name, $p ) == 0 ) { $has_prefix = 1; last; }
    }
    return 0 unless $has_prefix;
    return $name =~ /SECRET|TOKEN|PASSWORD|PASSWD|PRIVATE|CREDENTIAL|API_?KEY|ACCESS_?KEY|AUTH/i
        ? 1
        : 0;
}

sub _read {
    my ($file) = @_;
    open my $fh, '<', $file or die "cannot read $file: $!";
    local $/;
    my $data = <$fh>;
    close $fh;
    return $data;
}

sub _rel {
    my ( $root, $path ) = @_;
    return File::Spec->abs2rel( $path, $root );
}

sub _find_files {
    my ( $root, $want ) = @_;
    my @out;
    File::Find::find(
        sub {
            return unless -f $_;
            my $full = $File::Find::name;
            return if $full =~ m{/(?:\.git|blib|vendor|node_modules|target)/};
            my $name = $_;
            if ( $want eq 'env' ) {
                push @out, $full
                    if $name eq '.env'
                    || ( $name =~ /^\.env\./ && $name !~ /\.example$/ );
            }
            elsif ( $name =~ /\.p[lm]$/ ) {
                push @out, $full;
            }
        },
        $root
    );
    return sort @out;
}

# Classify an infra file by its relative path + basename + content.
# Returns 'compose', 'actions', 'k8s', or undef.
sub classify_infra {
    my ( $rel, $base, $content ) = @_;
    my $norm = $rel;
    $norm =~ s{\\}{/}g;
    return 'compose' if $base =~ /^(?:docker-)?compose(?:[.-].*)?\.ya?ml$/i;
    if ( $norm =~ m{(?:^|/)\.github/workflows/} && $base =~ /\.ya?ml$/i ) {
        return 'actions';
    }
    if ( $base =~ /\.ya?ml$/i ) {
        return 'k8s'
            if $content =~ /^apiVersion:/m && $content =~ /^kind:/m;
    }
    return undef;
}

# Extract used variable NAMES (with first-by-offset origin) from an infra file.
# Dependency-free: escaped `$$` neutralised, then interpolation (+ actions
# contexts) scanned by regex. Returns { NAME => { file => $rel, line => N } }.
sub scan_infra {
    my ( $rel, $content, $type ) = @_;
    my $text = $content;
    $text =~ s/\$\$/  /g;    # neutralise escaped $$ (preserve offsets)

    my @res;                 # [ start, name ]
    my @patterns = (
        qr/\$\{([A-Za-z_][A-Za-z0-9_]*)/,
        qr/\$([A-Za-z_][A-Za-z0-9_]*)/,
    );
    push @patterns, qr/\b(?:secrets|vars|env)\.([A-Za-z_][A-Za-z0-9_]*)/
        if defined $type && $type eq 'actions';

    for my $re (@patterns) {
        while ( $text =~ /$re/g ) {
            my $name  = $1;
            my $start = pos($text) - length($&);
            push @res, [ $start, $name ];
        }
    }

    my %used;
    for my $r ( sort { $a->[0] <=> $b->[0] } @res ) {
        my ( $start, $name ) = @$r;
        next if exists $used{$name};
        my $pre  = substr( $text, 0, $start );
        my $line = ( $pre =~ tr/\n// ) + 1;
        $used{$name} = { file => $rel, line => $line };
    }
    return \%used;
}

# Find infra files (compose / actions / k8s) under root, in sorted order.
# Returns list of [ full, rel, type ].
sub _find_infra {
    my ($root) = @_;
    my @out;
    File::Find::find(
        sub {
            return unless -f $_;
            my $full = $File::Find::name;
            return if $full =~ m{/(?:\.git|blib|vendor|node_modules|target)/};
            my $base = $_;
            return unless $base =~ /\.ya?ml$/i;
            my $rel     = _rel( $root, $full );
            my $content = _read($full);
            my $type    = classify_infra( $rel, $base, $content );
            push @out, [ $full, $rel, $type ] if defined $type;
        },
        $root
    );
    return sort { $a->[1] cmp $b->[1] } @out;
}

# Map each environment label to a hashref set of variable names defined in it.
sub defined_by_label {
    my ($root) = @_;
    my %labels;
    for my $f ( _find_files( $root, 'env' ) ) {
        my ( undef, undef, $base ) = File::Spec->splitpath($f);
        my $label = env_label($base);
        next unless defined $label;
        my $d = parse_env( _rel( $root, $f ), _read($f) );
        $labels{$label}{$_} = 1 for keys %$d;
    }
    return \%labels;
}

sub diff_labels {
    my ( $root, $a, $b ) = @_;
    my $labels = defined_by_label($root);
    my %da     = %{ $labels->{$a} || {} };
    my %db     = %{ $labels->{$b} || {} };
    return {
        onlyInA => [ sort grep { !$db{$_} } keys %da ],
        onlyInB => [ sort grep { !$da{$_} } keys %db ],
        common  => [ sort grep { $db{$_} } keys %da ],
    };
}

# Append keys present in `from` but missing from `to` as `KEY=` placeholders.
# Values are never copied.
sub sync_labels {
    my ( $root, $from, $to, $dry_run ) = @_;
    my $labels  = defined_by_label($root);
    my %df      = %{ $labels->{$from} || {} };
    my %dt      = %{ $labels->{$to} || {} };
    my @missing = sort grep { !$dt{$_} } keys %df;
    if ( @missing && !$dry_run ) {
        my $target = File::Spec->catfile( $root, $to eq 'default' ? '.env' : ".env.$to" );
        my $existing = -e $target ? _read($target) : '';
        my $prefix = ( $existing eq '' || $existing =~ /\n\z/ ) ? '' : "\n";
        open my $fh, '>>', $target or die "cannot append $target: $!";
        print {$fh} $prefix . join( '', map {"$_=\n"} @missing );
        close $fh;
    }
    return \@missing;
}

# Compute the DEFINED and USED variable-name sets for a project, reusing the
# same discovery logic as scan(). Returns ( \%defined, \%used ) as name=>1 sets.
sub collect_names {
    my ($root) = @_;
    my ( %defined, %used );
    for my $f ( _find_files( $root, 'env' ) ) {
        my ( undef, undef, $base ) = File::Spec->splitpath($f);
        my $label = env_label($base);
        next unless defined $label;    # skip *.example
        my $d = parse_env( _rel( $root, $f ), _read($f) );
        $defined{$_} = 1 for keys %$d;
    }
    for my $f ( _find_files( $root, 'perl' ) ) {
        my $u = scan_source( _rel( $root, $f ), _read($f) );
        $used{$_} = 1 for keys %$u;
    }
    for my $rec ( _find_infra($root) ) {
        my ( $full, $rel, $type ) = @$rec;
        my $u = scan_infra( $rel, _read($full), $type );
        $used{$_} = 1 for keys %$u;
    }
    return ( \%defined, \%used );
}

# Render the exact `.env.example` and `ENVIRONMENT.md` contents for a project.
# Returns ( $env_example, $environment_md ). Values are NEVER written.
sub generate {
    my ($root) = @_;
    my ( $defined, $used ) = collect_names($root);
    my %all = ( %$defined, %$used );
    my @names = sort keys %all;

    my $example = "# Generated by envdoctor. Fill in values; do not commit secrets.\n";
    $example .= "$_=\n" for @names;

    my $md = "# Environment variables\n\n";
    $md .= "| Variable | Defined | Used |\n";
    $md .= "| --- | --- | --- |\n";
    for my $name (@names) {
        my $d = $defined->{$name} ? 'yes' : 'no';
        my $u = $used->{$name}    ? 'yes' : 'no';
        $md .= "| $name | $d | $u |\n";
    }
    return ( $example, $md );
}

sub scan {
    my ($root) = @_;
    my ( %def, %used, @dupes );
    my %labels_by_var;    # var => { label => value }
    my %all_labels;       # every env label present in the project

    for my $f ( _find_files( $root, 'env' ) ) {
        my $rel = _rel( $root, $f );
        my ( undef, undef, $base ) = File::Spec->splitpath($f);
        my $label = env_label($base);
        next unless defined $label;    # skip *.example
        $all_labels{$label} = 1;
        my $d = parse_env( $rel, _read($f) );
        for my $key ( keys %$d ) {
            my @occ   = @{ $d->{$key} };
            my @lines = map { $_->{line} } @occ;
            # First occurrence counts as the definition for reconciliation.
            $def{$key} //= { file => $rel, line => $lines[0], value => $occ[0]{value} };
            # First value seen for this (var, label) pair.
            $labels_by_var{$key}{$label} //= $occ[0]{value};
            if ( @occ >= 2 ) {
                push @dupes,
                    {
                    rule     => 'duplicates',
                    severity => 'error',
                    name     => $key,
                    message  => 'defined '
                        . scalar(@occ)
                        . ' times in the same file (lines '
                        . join( ', ', @lines ) . ')',
                    origin => { file => $rel, line => $lines[0] },
                    };
            }
        }
    }
    for my $f ( _find_files( $root, 'perl' ) ) {
        my $u = scan_source( _rel( $root, $f ), _read($f) );
        $used{$_} //= $u->{$_} for keys %$u;
    }
    for my $rec ( _find_infra($root) ) {
        my ( $full, $rel, $type ) = @$rec;
        my $u = scan_infra( $rel, _read($full), $type );
        $used{$_} //= $u->{$_} for keys %$u;
    }

    my @defined_names = keys %def;
    my $n_labels      = scalar keys %all_labels;

    my @errors_undef;
    for my $name ( sort keys %used ) {
        next if exists $def{$name};
        push @errors_undef,
            {
            rule     => 'undefined-in-source',
            severity => 'error',
            name     => $name,
            message  => 'referenced but not defined in any environment file',
            origin   => $used{$name},
            };
    }

    my @errors_typemismatch;
    for my $name ( sort keys %labels_by_var ) {
        my %vals = %{ $labels_by_var{$name} };
        next unless keys %vals >= 2;
        my %groups;
        for my $v ( values %vals ) {
            my $t = infer_type($v);
            next if $t eq 'empty';
            $groups{ _type_group($t) } = 1;
        }
        next unless keys %groups >= 2;
        push @errors_typemismatch,
            {
            rule     => 'type-mismatch',
            severity => 'error',
            name     => $name,
            message  => 'inferred type differs across environments',
            origin   => { file => $def{$name}{file}, line => $def{$name}{line} },
            };
    }

    my @warn_unused;
    for my $name ( sort keys %def ) {
        next if exists $used{$name};
        push @warn_unused,
            {
            rule     => 'unused',
            severity => 'warning',
            name     => $name,
            message  => 'defined but never referenced in source',
            origin   => { file => $def{$name}{file}, line => $def{$name}{line} },
            };
    }

    my @warn_envdiff;
    if ( $n_labels >= 2 ) {
        for my $name ( sort keys %labels_by_var ) {
            my @present = sort keys %{ $labels_by_var{$name} };
            my %have    = map { $_ => 1 } @present;
            my @absent  = sort grep { !$have{$_} } keys %all_labels;
            next unless @present && @absent;
            push @warn_envdiff,
                {
                rule     => 'environment-diff',
                severity => 'warning',
                name     => $name,
                message  => 'defined in '
                    . join( ', ', @present )
                    . ' but missing in '
                    . join( ', ', @absent ),
                origin => { file => $def{$name}{file}, line => $def{$name}{line} },
                };
        }
    }

    my @warn_weak;
    for my $name ( sort keys %def ) {
        next unless $name =~ $SECRET_NAME;
        next unless _is_weak_secret( $def{$name}{value} );
        push @warn_weak,
            {
            rule     => 'weak-secret',
            severity => 'warning',
            name     => $name,
            message  => 'secret-looking variable has a weak or placeholder value',
            origin   => { file => $def{$name}{file}, line => $def{$name}{line} },
            };
    }

    my @warn_typo;
    for my $name ( sort keys %used ) {
        next if exists $def{$name};
        my $d = _typo_suggestion( $name, \@defined_names );
        next unless defined $d;
        push @warn_typo,
            {
            rule     => 'typo',
            severity => 'warning',
            name     => $name,
            message  => qq{"$name" is not defined; did you mean "$d"?},
            origin   => $used{$name},
            };
    }

    my @public_prefix = map {
        {   rule     => 'public-prefix',
            severity => 'error',
            name     => $_,
            message  => 'secret-looking variable is exposed to client bundles via a public prefix',
            origin   => { file => $def{$_}{file}, line => $def{$_}{line} },
        }
    } sort grep { _is_public_secret($_) } keys %def;

    my @errors_schema;
    my $schema = _load_schema($root);
    for my $name ( sort keys %$schema ) {
        my $rule = $schema->{$name};
        next unless ref $rule eq 'HASH';
        if ( exists $def{$name} ) {
            my $msg = _schema_failure( $rule, $def{$name}{value} );
            push @errors_schema,
                {
                rule     => 'schema-validation',
                severity => 'error',
                name     => $name,
                message  => $msg,
                origin   => { file => $def{$name}{file}, line => $def{$name}{line} },
                }
                if defined $msg;
        }
        elsif ( !$rule->{optional} ) {
            push @errors_schema,
                {
                rule     => 'schema-validation',
                severity => 'error',
                name     => $name,
                message  => 'required by schema but not defined',
                origin   => { file => undef, line => undef },
                };
        }
    }

    my @findings = (
        @errors_undef,
        ( sort { $a->{name} cmp $b->{name} } @dupes ),
        @public_prefix,
        @errors_typemismatch,
        @errors_schema,
        @warn_unused,
        @warn_envdiff,
        @warn_weak,
        @warn_typo,
    );
    return \@findings;
}

sub _load_schema {
    my ($root) = @_;
    require JSON::PP;
    my $path = File::Spec->catfile( $root, 'envdoctor.schema.json' );
    return {} unless -e $path;
    my $data = eval { JSON::PP->new->decode( _read($path) ) };
    return ( ref $data eq 'HASH' ) ? $data : {};
}

sub _schema_type_ok {
    my ( $value, $declared ) = @_;
    return 1        if $declared eq 'string';
    return $value =~ /^-?\d+$/         ? 1 : 0 if $declared eq 'integer';
    return $value =~ /^-?\d+(\.\d+)?$/ ? 1 : 0 if $declared eq 'float';
    return ( lc($value) eq 'true' || lc($value) eq 'false' ) ? 1 : 0 if $declared eq 'boolean';
    return $value =~ m{^https?://} ? 1 : 0 if $declared eq 'url';
    if ( $declared eq 'json' ) {
        require JSON::PP;
        my $ok = eval { JSON::PP->new->decode($value); 1 };
        return $ok ? 1 : 0;
    }
    return 1;
}

sub _schema_failure {
    my ( $rule, $value ) = @_;
    my $t = $rule->{type};
    return "value does not match schema type $t"
        if defined $t && !ref $t && !_schema_type_ok( $value, $t );

    my $enum = $rule->{enum};
    if ( ref $enum eq 'ARRAY' ) {
        return 'value is not one of the allowed values'
            unless grep { $_ eq $value } @$enum;
    }

    my $pat = $rule->{regex};
    if ( defined $pat && !ref $pat ) {
        my $re = eval {qr/$pat/};
        return 'value does not match the required pattern' if $re && $value !~ $re;
    }

    if ( $value =~ /^-?\d+(\.\d+)?$/ ) {
        my $num = $value + 0;
        return 'value is below the minimum'
            if defined $rule->{min} && !ref $rule->{min} && $num < $rule->{min};
        return 'value exceeds the maximum'
            if defined $rule->{max} && !ref $rule->{max} && $num > $rule->{max};
    }
    return undef;
}

1;
