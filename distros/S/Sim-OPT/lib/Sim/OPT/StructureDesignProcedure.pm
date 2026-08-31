package Sim::OPT::StructureDesignProcedure;

use strict;
use warnings;
use Exporter 'import';
use Cwd qw(getcwd abs_path);
use File::Basename qw(basename dirname);
use File::Path qw(make_path);
use File::Copy qw(copy);
use File::Find qw(find);
use File::Spec;
use JSON::PP ();
use Digest::SHA qw(sha256_hex);
use Time::Piece;

our $VERSION = '0.18';
our @EXPORT_OK = qw(
    design state experience derive reembed merge imagine abstract compare reconstruct_memory
    search star surrogate medoids surrogating_with clustering_and_finding_medoids clustering_and_medoiding
    reduce_scope enlarge_scope increase_resolution decrease_resolution pan maintain_resolution
    incumbent result_of
    load_procedure run_procedure
);

# -------------------------------------------------------------------------
# Embedded-Perl DSL constructors. These only describe intent; they do not
# perform filesystem or Sim::OPT operations.
# -------------------------------------------------------------------------

sub design {
    my ($name, %a) = @_;
    die "design: name required\n" unless defined($name) && length($name);
    my $steps = delete($a{steps}) || [];
    die "design: steps must be an ARRAY reference\n" unless ref($steps) eq 'ARRAY';
    return {
        schema => 'Sim::OPT::StructureDesign/procedure-1',
        name   => $name,
        root_dir => $a{root_dir} || $ENV{HOME} || '.',
        manifest => $a{manifest},
        steps  => $steps,
        %a,
    };
}

sub _node {
    my ($type, @args) = @_;
    my %a;
    if (@args && !ref($args[0])) {
        $a{name} = shift @args;
    }
    %a = (%a, @args);
    $a{type} = $type;
    $a{enabled} = 1 unless exists $a{enabled};
    return \%a;
}

sub state      { return _node('state',      @_); }
sub experience { return _node('experience', @_); }
sub derive     { return _node('derive',     @_); }
sub reembed    { return _node('reembed',    @_); }
sub merge      { return _node('merge',      @_); }
sub imagine    { return _node('imagine',    @_); }
sub abstract   { return _node('abstract',   @_); }
sub compare    { return _node('compare',    @_); }
sub reconstruct_memory { return _node('reconstruct_memory', @_); }

sub search     { return { kind => 'search', @_ }; }
sub star       { return { kind => 'star', @_ }; }
sub surrogate  { return { kind => 'surrogate', @_ }; }
sub medoids    { return { kind => 'medoids', @_ }; }

# Article-facing vocabulary.  Keep the older constructors as compatibility aliases.
sub surrogating_with {
    my ($method, @rest) = @_;
    die "surrogating_with: method required\n" unless defined($method) && length($method);
    return { kind => 'surrogate', method => $method, @rest };
}
sub clustering_and_finding_medoids {
    return { kind => 'clustering_and_finding_medoids', @_ };
}

# Backward-compatible spelling retained for old procedure files only.
sub clustering_and_medoiding {
    return clustering_and_finding_medoids(@_);
}

sub reduce_scope        { return { op => 'reduce_scope',        @_ }; }
sub enlarge_scope       { return { op => 'enlarge_scope',       @_ }; }
sub increase_resolution { return { op => 'increase_resolution', @_ }; }
sub decrease_resolution { return { op => 'decrease_resolution', @_ }; }
sub pan                 { return { op => 'pan',                  @_ }; }
sub maintain_resolution { return { op => 'maintain_resolution', @_ }; }

sub incumbent { return { ref => 'incumbent', step => $_[0] }; }
sub result_of { return { ref => 'result',    step => $_[0], key => $_[1] }; }

# -------------------------------------------------------------------------
# Loading and manifest helpers
# -------------------------------------------------------------------------

sub load_procedure {
    my ($file) = @_;
    die "load_procedure: procedure file required\n" unless defined($file) && length($file);
    my $abs = File::Spec->rel2abs($file);
    die "Procedure file not found: $abs\n" unless -f $abs;
    my $p = do $abs;
    die "Cannot load procedure $abs: $@\n" if $@;
    die "Cannot read procedure $abs: $!\n" unless defined $p;
    die "Procedure $abs did not return a HASH reference\n" unless ref($p) eq 'HASH';
    die "Unsupported procedure schema\n" unless ($p->{schema} || '') eq 'Sim::OPT::StructureDesign/procedure-1';
    $p->{_procedure_file} = $abs;
    return $p;
}

sub _json { return JSON::PP->new->canonical(1)->pretty(1); }
sub _now  { return localtime->datetime . localtime->strftime('%z'); }

sub _step_id {
    my ($s, $i) = @_;
    return $s->{id} if defined($s->{id}) && length($s->{id});
    return sprintf('%03d_%s_%s', $i + 1, $s->{type} || 'step', $s->{name} || 'unnamed');
}

sub _step_signature {
    my ($s) = @_;
    my %copy = %$s;
    delete $copy{_runtime};
    return sha256_hex(JSON::PP->new->canonical(1)->encode(\%copy));
}

sub _read_json {
    my ($path) = @_;
    return {} unless -f $path;
    open my $fh, '<', $path or die "Cannot read $path: $!\n";
    local $/;
    my $txt = <$fh>;
    close $fh;
    return JSON::PP->new->decode($txt);
}

sub _write_json {
    my ($path, $data) = @_;
    make_path(dirname($path)) unless -d dirname($path);
    my $tmp = "$path.tmp.$$";
    open my $fh, '>', $tmp or die "Cannot write $tmp: $!\n";
    print {$fh} _json()->encode($data);
    close $fh or die "Cannot close $tmp: $!\n";
    rename $tmp, $path or die "Cannot rename $tmp -> $path: $!\n";
}

sub _manifest_path {
    my ($p) = @_;
    return File::Spec->rel2abs($p->{manifest}) if defined($p->{manifest}) && length($p->{manifest});
    return File::Spec->catfile($p->{root_dir}, '.structuredesign', $p->{name} . '.json');
}

# A run manifest is only reusable when both the declared procedure and the
# installed StructureDesign runtime that gives those declarations meaning are
# unchanged.  Step signatures alone are insufficient: a change in the zoom,
# re-embedding, launch, or reconstruction implementation can alter the meaning
# of an otherwise identical procedure step.
sub _file_sha256 {
    my ($path) = @_;
    return undef unless defined($path) && -f $path;
    open my $fh, '<', $path or die "Cannot read $path for signature: $!\n";
    binmode $fh;
    my $sha = Digest::SHA->new(256);
    $sha->addfile($fh);
    close $fh;
    return $sha->hexdigest;
}

sub _find_inc_file {
    my ($rel) = @_;
    for my $base (@INC) {
        next if ref($base);
        my $p = File::Spec->catfile($base, split m{/}, $rel);
        return $p if -f $p;
    }
    return undef;
}

sub _procedure_signature {
    my ($p) = @_;
    my @steps;
    my $i = 0;
    for my $s (@{ $p->{steps} || [] }) {
        my $sid = _step_id($s, $i++);
        next unless $s->{enabled};
        push @steps, {
            id        => $sid,
            signature => _step_signature($s),
        };
    }
    return sha256_hex(JSON::PP->new->canonical(1)->encode({
        schema    => $p->{schema},
        name      => $p->{name},
        root_dir  => File::Spec->rel2abs($p->{root_dir}),
        steps     => \@steps,
    }));
}

sub _runtime_signature {
    my @parts = ("StructureDesignProcedure-version=$VERSION");
    my $self_hash = _file_sha256(__FILE__);
    push @parts, "StructureDesignProcedure-file=$self_hash" if defined $self_hash;
    my $sd = _find_inc_file('Sim/OPT/StructureDesign.pm');
    my $sd_hash = _file_sha256($sd);
    push @parts, "StructureDesign-file=$sd_hash" if defined $sd_hash;
    return sha256_hex(join("\n", @parts));
}

sub _generated_state_names {
    my ($p) = @_;
    my %seen;
    my @names;
    for my $s (@{ $p->{steps} || [] }) {
        next unless $s->{enabled};
        my $type = $s->{type} || '';
        my $generated = ($type =~ /^(?:derive|reembed|merge|reconstruct_memory)$/)
            || ($type eq 'state' && !$s->{existing});
        next unless $generated;
        my $name = $s->{name};
        next unless defined($name) && length($name) && !$seen{$name}++;
        push @names, $name;
    }
    return @names;
}

sub _archive_stale_run {
    my (%a) = @_;
    my $p = $a{procedure} or die "archive stale run: procedure required\n";
    my $manifest_path = $a{manifest_path} or die "archive stale run: manifest_path required\n";
    my $stamp = localtime->strftime('%Y%m%d-%H%M%S');
    my $archive = File::Spec->catdir(
        $p->{root_dir}, '.structuredesign', 'archive',
        $p->{name} . '-' . $stamp . '-' . $$,
    );
    make_path(File::Spec->catdir($archive, 'states'));

    if (-f $manifest_path) {
        my $dst = File::Spec->catfile($archive, 'manifest.json');
        rename $manifest_path, $dst
            or die "Cannot archive stale manifest $manifest_path -> $dst: $!\n";
    }

    my @moved;
    for my $name (_generated_state_names($p)) {
        my $src = _state_dir($p, $name);
        next unless -e $src;
        my $dst = File::Spec->catdir($archive, 'states', $name);
        rename $src, $dst
            or die "Cannot archive stale generated state $src -> $dst: $!\n";
        push @moved, $name;
    }

    my $record = {
        schema => 'Sim::OPT::StructureDesign/stale-run-archive-1',
        archived_at => _now(),
        procedure => $p->{name},
        reason => $a{reason},
        old_procedure_signature => $a{old_procedure_signature},
        new_procedure_signature => $a{new_procedure_signature},
        old_runtime_signature => $a{old_runtime_signature},
        new_runtime_signature => $a{new_runtime_signature},
        generated_states_archived => \@moved,
    };
    _write_json(File::Spec->catfile($archive, 'archive.json'), $record);
    return ($archive, \@moved);
}

sub _prepare_manifest {
    my (%a) = @_;
    my $p = $a{procedure} or die "prepare manifest: procedure required\n";
    my $path = $a{manifest_path} or die "prepare manifest: manifest_path required\n";
    my $commit = $a{commit} ? 1 : 0;
    my $old = _read_json($path);
    my $proc_sig = _procedure_signature($p);
    my $runtime_sig = _runtime_signature();

    my @reasons;
    if (-f $path) {
        push @reasons, 'manifest schema differs'
            if ($old->{schema} || '') ne 'Sim::OPT::StructureDesign/procedure-run-1';
        push @reasons, 'procedure name differs'
            if defined($old->{procedure}) && ($old->{procedure} || '') ne ($p->{name} || '');
        push @reasons, 'root directory differs'
            if defined($old->{root_dir})
                && File::Spec->rel2abs($old->{root_dir}) ne File::Spec->rel2abs($p->{root_dir});
        push @reasons, 'procedure declaration changed'
            if !defined($old->{procedure_signature}) || $old->{procedure_signature} ne $proc_sig;
        push @reasons, 'StructureDesign runtime changed'
            if !defined($old->{runtime_signature}) || $old->{runtime_signature} ne $runtime_sig;
    }

    if (@reasons) {
        my $reason = join('; ', @reasons);

        # A narrowly-scoped repair resume is safe when the procedure declaration
        # itself is unchanged and only the StructureDesign runtime changed. The
        # caller must opt in explicitly and resume from a named step; normal stale
        # handling remains conservative. Prerequisite step signatures are still
        # checked by run_procedure before execution reaches --from.
        my $runtime_only = (@reasons == 1 && $reasons[0] eq 'StructureDesign runtime changed') ? 1 : 0;
        my %tail_allowed = map { $_ => 1 } ('procedure declaration changed', 'StructureDesign runtime changed');
        my $has_proc_change = scalar grep { $_ eq 'procedure declaration changed' } @reasons;
        my $tail_change = $has_proc_change && !grep { !$tail_allowed{$_} } @reasons;
        if ($a{accept_runtime_change} && $a{from} && $runtime_only) {
            print "[StructureDesign] ACCEPT runtime-only change for explicit --from resume: $a{from}\n";
            print "[StructureDesign] PRESERVE completed prerequisite states; step signatures will be revalidated.\n";
        } elsif ($a{accept_tail_change} && $a{from} && $tail_change) {
            print "[StructureDesign] ACCEPT procedure tail change for explicit --from resume: $a{from}\n";
            print "[StructureDesign] PRESERVE completed prerequisite states; every prerequisite step signature will be revalidated.\n";
        } elsif ($a{from} || $a{only}) {
            die "Run manifest is stale ($reason). A partial --from/--only execution is unsafe. For an intentional runtime-only bugfix use --accept-runtime-change with --from. If only the selected step or later procedure declarations changed, use --accept-tail-change with --from; completed prerequisite step signatures will be checked. Otherwise run once without --from/--only so stale generated states are archived.\n";
        } elsif ($commit) {
            my ($archive, $moved) = _archive_stale_run(
                procedure => $p,
                manifest_path => $path,
                reason => $reason,
                old_procedure_signature => $old->{procedure_signature},
                new_procedure_signature => $proc_sig,
                old_runtime_signature => $old->{runtime_signature},
                new_runtime_signature => $runtime_sig,
            );
            print "[StructureDesign] STALE run manifest: $reason\n";
            print "[StructureDesign] ARCHIVED stale run at $archive\n";
            print "[StructureDesign] ARCHIVED generated states: " . join(', ', @$moved) . "\n" if @$moved;
            $old = {};
        } else {
            print "[StructureDesign] PLAN stale manifest would be archived before execution: $reason\n";
        }
    }

    $old->{schema} = 'Sim::OPT::StructureDesign/procedure-run-1';
    $old->{procedure} = $p->{name};
    $old->{procedure_file} = $p->{_procedure_file} if $p->{_procedure_file};
    $old->{root_dir} = $p->{root_dir};
    $old->{procedure_signature} = $proc_sig;
    $old->{runtime_signature} = $runtime_sig;
    $old->{runtime_version} = $VERSION;
    $old->{steps} ||= {};
    $old->{updated_at} = _now();
    return $old;
}

# -------------------------------------------------------------------------
# Filesystem/config helpers
# -------------------------------------------------------------------------

sub _state_dir {
    my ($p, $name) = @_;
    die "State name required\n" unless defined($name) && length($name);
    return File::Spec->catdir($p->{root_dir}, $name);
}

sub _state_config {
    my ($p, $state_name, $config) = @_;
    $config ||= $state_name . '.pl';
    return File::Spec->catfile(_state_dir($p, $state_name), $config);
}

sub _read_text_file {
    my ($path) = @_;
    open my $fh, '<', $path or die "Cannot read $path: $!\n";
    local $/;
    my $txt = <$fh>;
    close $fh;
    return $txt;
}

sub _write_text_file {
    my ($path, $txt) = @_;
    open my $fh, '>', $path or die "Cannot write $path: $!\n";
    print {$fh} $txt;
    close $fh or die "Cannot close $path: $!\n";
}

sub _config_quote {
    my ($v) = @_;
    $v = '' unless defined $v;
    $v =~ s/\\/\\\\/g;
    $v =~ s/"/\\"/g;
    return '"' . $v . '"';
}

sub _format_sweeps_assignment {
    my ($cases) = @_;
    die "config variant: sweeps must be an ARRAY reference\n"
        unless ref($cases) eq 'ARRAY' && @$cases;
    my @out;
    for my $case (@$cases) {
        die "config variant: each sweep case must be an ARRAY reference\n"
            unless ref($case) eq 'ARRAY' && @$case;
        my @atoms;
        for my $v (@$case) {
            die "config variant: sweep atom must be scalar\n" if ref($v);
            push @atoms, (defined($v) && "$v" =~ /^-?(?:\d+(?:\.\d*)?|\.\d+)$/)
                ? "$v" : _config_quote($v);
        }
        push @out, '[ [ ' . join(' , ', @atoms) . ' ] ]';
    }
    return '@sweeps = ( ' . join(', ', @out) . ' );';
}

sub _set_dowhat_string {
    my ($txt, $key, $value) = @_;
    die "config variant: invalid dowhat key '$key'\n" unless defined($key) && $key =~ /^\w+$/;
    my $q = _config_quote($value);

    my $n = ($txt =~ s/^(\s*)\Q$key\E\s*=>\s*["'][^"']*["']\s*,[^\n]*$/$1$key => $q,/m);
    return $txt if $n == 1;
    die "config variant: multiple active '$key' entries\n" if $n > 1;

    $n = ($txt =~ s/^\s*#\s*\Q$key\E\s*=>[^\n]*$/$key => $q,/m);
    return $txt if $n == 1;
    die "config variant: multiple commented '$key' entries\n" if $n > 1;

    $n = ($txt =~ s/(%dowhat\s*=\s*\(.*?)(^\s*\);[^\n]*$)/$1$key => $q,\n$2/ms);
    die "config variant: could not insert '$key' into %dowhat\n" unless $n == 1;
    return $txt;
}


sub _format_starpositions_value {
    my ($positions) = @_;
    die "config variant: starpositions must be an ARRAY reference\n"
        unless ref($positions) eq 'ARRAY';
    my @rows;
    for my $h (@$positions) {
        die "config variant: each starposition must be a HASH reference\n"
            unless ref($h) eq 'HASH';
        my @pairs;
        for my $v (sort { $a <=> $b } keys %$h) {
            my $lev = $h->{$v};
            die "config variant: starposition variable '$v' or level '$lev' is not an integer\n"
                unless "$v" =~ /^\d+$/ && defined($lev) && "$lev" =~ /^\d+$/;
            push @pairs, "$v => $lev";
        }
        push @rows, '        { ' . join(', ', @pairs) . ' }';
    }
    return "[\n" . join(",\n", @rows) . "\n    ]";
}

sub _set_dowhat_perl_value {
    my ($txt, $key, $value_text) = @_;
    die "config variant: perl value text required for '$key'\n"
        unless defined($value_text) && length($value_text);

    my $n = ($txt =~ s/^(\s*)\Q$key\E\s*=>\s*[^,\n]+\s*,[^\n]*$/$1$key => $value_text,/m);
    return $txt if $n == 1;
    die "config variant: multiple active '$key' entries\n" if $n > 1;

    $n = ($txt =~ s/^\s*#\s*\Q$key\E\s*=>[^\n]*$/$key => $value_text,/m);
    return $txt if $n == 1;
    die "config variant: multiple commented '$key' entries\n" if $n > 1;

    $n = ($txt =~ s/(%dowhat\s*=\s*\(.*?)(^\s*\);[^\n]*$)/$1$key => $value_text,\n$2/ms);
    die "config variant: could not insert '$key' into %dowhat\n" unless $n == 1;
    return $txt;
}

sub _render_config_variant {
    my (%a) = @_;
    my $source = $a{source} or die "config variant: source required\n";
    my $variant = $a{variant} || {};
    die "config variant: variant must be a HASH reference\n" unless ref($variant) eq 'HASH';
    my $txt = _read_text_file($source);

    if (defined($a{mypath}) && length($a{mypath})) {
        my $q = _config_quote($a{mypath});
        my $n = ($txt =~ s/^(?!\s*#)(\s*\$mypath\s*=\s*)["'][^"']+["']/$1$q/m);
        die "config variant: could not patch \$mypath in $source\n" unless $n == 1;
    }

    if (exists $variant->{sweeps}) {
        my $assignment = _format_sweeps_assignment($variant->{sweeps});
        my $n = ($txt =~ s/^(?!\s*#)\s*\@sweeps\s*=\s*[^;]+;/$assignment/m);
        die "config variant: could not patch active \@sweeps in $source\n" unless $n == 1;
    }

    if (exists $variant->{starpositions}) {
        my $v = _format_starpositions_value($variant->{starpositions});
        $txt = _set_dowhat_perl_value($txt, 'starpositions', $v);
    }

    if (exists $variant->{dowhat}) {
        die "config variant: dowhat must be a HASH reference\n"
            unless ref($variant->{dowhat}) eq 'HASH';
        for my $key (sort keys %{ $variant->{dowhat} }) {
            $txt = _set_dowhat_string($txt, $key, $variant->{dowhat}{$key});
        }
    }

    return "# Generated config variant by Sim::OPT::StructureDesignProcedure $VERSION\n" . $txt;
}

sub _validate_config_variant_text {
    my ($txt, $variant) = @_;
    $variant ||= {};
    die "config variant validation: text required\n" unless defined $txt;
    die "config variant validation: variant must be a HASH reference\n"
        unless ref($variant) eq 'HASH';

    if (exists $variant->{sweeps}) {
        my $want = _format_sweeps_assignment($variant->{sweeps});
        my ($got_rhs) = $txt =~ /^(?!\s*#)\s*\@sweeps\s*=\s*([^;]+);/m;
        die "config variant validation: cannot parse active \@sweeps\n" unless defined $got_rhs;
        my $got = '@sweeps = ' . $got_rhs . ';';
        (my $gc = $got) =~ s/\s+//g;
        (my $wc = $want) =~ s/\s+//g;
        die "config variant validation: active \@sweeps differs (got $got, expected $want)\n"
            unless $gc eq $wc;
    }

    if (exists $variant->{starpositions}) {
        die "config variant validation: starpositions must be an ARRAY reference\n"
            unless ref($variant->{starpositions}) eq 'ARRAY';
        my ($body) = $txt =~ /^(?!\s*#)\s*starpositions\s*=>\s*\[(.*?)\]\s*,/ms;
        die "config variant validation: cannot parse active starpositions in %dowhat\n"
            unless defined $body;
        my $count = () = $body =~ /\{[^{}]*\}/g;
        die "config variant validation: starposition count differs (got $count, expected "
            . scalar(@{ $variant->{starpositions} }) . ")\n"
            unless $count == @{ $variant->{starpositions} };
    }

    if (exists $variant->{dowhat}) {
        die "config variant validation: dowhat must be a HASH reference\n"
            unless ref($variant->{dowhat}) eq 'HASH';
        for my $key (sort keys %{ $variant->{dowhat} }) {
            my ($got) = $txt =~ /^(?!\s*#)\s*\Q$key\E\s*=>\s*["']([^"']*)["']/m;
            die "config variant validation: cannot parse active '$key' in %dowhat\n"
                unless defined $got;
            my $want = defined($variant->{dowhat}{$key}) ? "$variant->{dowhat}{$key}" : '';
            die "config variant validation: '$key' differs (got '$got', expected '$want')\n"
                unless $got eq $want;
        }
    }
    return 1;
}

sub _materialize_config_variant {
    my (%a) = @_;
    my $source = $a{source} or die "config variant: source required\n";
    my $target = $a{target} or die "config variant: target required\n";
    die "config variant: source configuration not found: $source\n" unless -f $source;
    my $variant = $a{variant} || {};
    my $txt = _render_config_variant(
        source => $source,
        mypath => $a{mypath},
        variant => $variant,
    );
    _validate_config_variant_text($txt, $variant);
    if (defined($a{geometry_manifest}) && length($a{geometry_manifest})) {
        my $gm = $a{geometry_manifest};
        die "config variant: geometry manifest not found: $gm\n" unless -f $gm;
        my $plan = _read_json($gm);
        require Sim::OPT::StructureDesign;
        Sim::OPT::StructureDesign::validate_enlarge_pan_config_text(
            $txt, $plan, target_dir => ($a{mypath} || dirname($target)),
        );
    }
    _write_text_file($target, $txt);
    return $target;
}

sub _materialize_cloned_scope_manifest {
    my (%a) = @_;
    my $source = $a{source} or die "cloned scope manifest: source required\n";
    my $target = $a{target} or die "cloned scope manifest: target required\n";
    my $source_config = $a{source_config} or die "cloned scope manifest: source_config required\n";
    my $target_config = $a{target_config} or die "cloned scope manifest: target_config required\n";
    my $source_dir = $a{source_dir} or die "cloned scope manifest: source_dir required\n";
    my $target_dir = $a{target_dir} or die "cloned scope manifest: target_dir required\n";
    die "cloned scope manifest: source not found: $source\n" unless -f $source;
    die "cloned scope manifest: source config not found: $source_config\n" unless -f $source_config;
    die "cloned scope manifest: target config not found: $target_config\n" unless -f $target_config;

    my $plan = _read_json($source);
    require Sim::OPT::StructureDesign;
    my $source_text = _read_text_file($source_config);
    Sim::OPT::StructureDesign::validate_enlarge_pan_config_text(
        $source_text, $plan, target_dir => $source_dir,
    );

    # Deep-copy the structural plan and retarget only the state identity.  The
    # target lattice, physical operations and maintained resolution remain
    # unchanged because btre is a sibling experience on btrd's design space.
    my $copy = JSON::PP->new->decode(JSON::PP->new->encode($plan));
    $copy->{child_dir} = $target_dir;
    $copy->{child_config} = basename($target_config);
    $copy->{state_clone_from} = {
        state_dir => $source_dir,
        config => basename($source_config),
        geometry_manifest => $source,
    };
    $copy->{geometry_role} = 'cloned_design_space';

    my $target_text = _read_text_file($target_config);
    Sim::OPT::StructureDesign::validate_enlarge_pan_config_text(
        $target_text, $copy, target_dir => $target_dir,
    );
    _write_json($target, $copy);
    return $target;
}


sub _copy_tree_exact {
    my ($src, $dst) = @_;
    die "copy_tree: source directory does not exist: $src\n" unless -d $src;
    die "copy_tree: destination already exists: $dst\n" if -e $dst;
    make_path($dst);
    find({
        no_chdir => 1,
        wanted => sub {
            my $path = $File::Find::name;
            return if $path eq $src;
            my $rel = File::Spec->abs2rel($path, $src);
            my $out = File::Spec->catfile($dst, $rel);
            if (-l $path) {
                my $link = readlink($path);
                die "Cannot read symlink $path: $!\n" unless defined $link;
                symlink($link, $out) or die "Cannot create symlink $out: $!\n";
                return;
            }
            if (-d $path) {
                make_path($out) unless -d $out;
                my $mode = (stat($path))[2];
                chmod($mode & 07777, $out) if defined $mode;
                return;
            }
            copy($path, $out) or die "Cannot copy $path -> $out: $!\n";
            my $mode = (stat($path))[2];
            chmod($mode & 07777, $out) if defined $mode;
        },
    }, $src);
}

sub _cryptolink_rows {
    my (%a) = @_;
    my $source = $a{source};
    my $root = $a{root};
    die "cryptolink_rows: source HASH required\n" unless ref($source) eq 'HASH';
    die "cryptolink_rows: model root required\n" unless defined($root) && length($root);

    my %by_short;
    my $add = sub {
        my ($short, $clear) = @_;
        return unless defined($short) && defined($clear);
        if (exists $by_short{$short} && $by_short{$short} ne $clear) {
            die "Conflicting cryptolink mappings for short id $short: '$by_short{$short}' vs '$clear'\n";
        }
        $by_short{$short} = $clear;
    };

    for my $k (keys %$source) {
        my $v = $source->{$k};
        next if ref($v) || !defined($v);

        # Compatibility with numeric short-id => clear-id maps, if encountered.
        if ($k =~ /^(\d+)$/) {
            my $short = 0 + $1;
            if ($v =~ /^((?:\d+-\d+)(?:_\d+-\d+)+)$/) {
                my $clear = $1;
                $add->($short, $clear);
                next;
            }
        }

        # Sim::OPT's native cryptolinks are absolute-path pairs in both directions:
        #   .../bt_7 <=> .../bt_1-1_2-3_...
        my $kb = basename($k);
        my $vb = basename("$v");
        if ($kb =~ /^\Q$root\E_(\d+)$/) {
            my $short = 0 + $1;
            if ($vb =~ /^\Q$root\E_((?:\d+-\d+)(?:_\d+-\d+)+)$/) {
                my $clear = $1;
                $add->($short, $clear);
                next;
            }
        }
        if ($vb =~ /^\Q$root\E_(\d+)$/) {
            my $short = 0 + $1;
            if ($kb =~ /^\Q$root\E_((?:\d+-\d+)(?:_\d+-\d+)+)$/) {
                my $clear = $1;
                $add->($short, $clear);
                next;
            }
        }
    }

    die "No Sim::OPT short-id/clear-id mappings found in source cryptolinks\n" unless keys %by_short;
    return [ map { { short => 0 + $_, local => $by_short{$_} } }
             sort { $a <=> $b } keys %by_short ];
}

sub _write_reembedded_cryptolinks {
    my (%a) = @_;
    my $path = $a{path};
    my $rows = $a{rows};
    my $target_dir = $a{target_dir};
    my $root = $a{root};
    my $mapper = $a{mapper};
    die "write_reembedded_cryptolinks: rows ARRAY required\n" unless ref($rows) eq 'ARRAY';
    die "write_reembedded_cryptolinks: mapper CODE required\n" unless ref($mapper) eq 'CODE';

    my %out;
    my @mapped;
    for my $row (@$rows) {
        my $short = $row->{short};
        my $local = $row->{local};
        my $global = $mapper->($local);
        my $short_path = File::Spec->catfile($target_dir, $root . '_' . $short);
        my $clear_path = File::Spec->catfile($target_dir, $root . '_' . $global);
        die "Re-embedding collision on clear instance '$global'\n" if exists $out{$clear_path};
        $out{$short_path} = $clear_path;
        $out{$clear_path} = $short_path;
        push @mapped, { short => 0 + $short, local => $local, global => $global };
    }
    die "No cryptolink mappings to write\n" unless @mapped;

    open my $fh, '>', $path or die "Cannot write $path: $!\n";
    print {$fh} "{\n";
    for my $k (sort keys %out) {
        my $v = $out{$k};
        (my $qk = $k) =~ s/([\\\"])/\\$1/g;
        (my $qv = $v) =~ s/([\\\"])/\\$1/g;
        print {$fh} qq{  "$qk" => "$qv",\n};
    }
    print {$fh} "}\n";
    close $fh or die "Cannot close $path: $!\n";
    return \@mapped;
}

sub _rewrite_totres_clear_names {
    my (%a) = @_;
    my $source = $a{source};
    my $target = $a{target};
    my $mapper = $a{mapper};
    die "rewrite_totres: source file not found: $source\n" unless -f $source;
    die "rewrite_totres: mapper CODE required\n" unless ref($mapper) eq 'CODE';
    open my $in, '<', $source or die "Cannot read $source: $!\n";
    open my $out, '>', $target or die "Cannot write $target: $!\n";
    my ($rows, %seen) = (0);
    while (my $line = <$in>) {
        if ($line =~ /^((?:\d+-\d+)(?:_\d+-\d+)+)(,.*)$/s) {
            my ($local, $rest) = ($1, $2);
            my $global = $mapper->($local);
            die "Re-embedding collision in result file on '$global'\n" if $seen{$global}++;
            print {$out} $global, $rest;
            $rows++;
        } elsif ($line =~ /\S/) {
            die "Unexpected non-result line in $source: $line";
        } else {
            print {$out} $line;
        }
    }
    close $in;
    close $out or die "Cannot close $target: $!\n";
    die "No result rows found in $source\n" unless $rows;
    return $rows;
}

sub _execute_reembed {
    my (%a) = @_;
    my $s = $a{step};
    my $p = $a{procedure};
    my $manifest = $a{manifest};
    my $commit = $a{commit};

    my $from = $s->{from} or die "reembed '$s->{name}': from required\n";
    my $to = $s->{name} or die "reembed: target state name required\n";
    my $source_dir = _state_dir($p, $from);
    my $target_dir = _state_dir($p, $to);
    die "reembed '$to': source state directory not found: $source_dir\n" unless -d $source_dir;

    my $zoom_file = $s->{zoom_plan} || 'structuredesign-zoom.json';
    my $zoom_path = File::Spec->file_name_is_absolute($zoom_file)
        ? $zoom_file : File::Spec->catfile($source_dir, $zoom_file);
    die "reembed '$to': zoom plan not found: $zoom_path\n" unless -f $zoom_path;
    my $zoom = _read_json($zoom_path);
    die "reembed '$to': source plan is not a zoom_in plan\n"
        unless ref($zoom) eq 'HASH' && ($zoom->{operation} || '') eq 'zoom_in';

    require Sim::OPT::StructureDesign;
    my $root = $s->{model_root} || $zoom->{model_root} || 'bt';
    my $config_name = $s->{config} || "$to.pl";
    my $config_path = File::Spec->catfile($target_dir, $config_name);
    my $config_text = Sim::OPT::StructureDesign::render_refined_parent_config(
        $zoom,
        target_dir => $target_dir,
    );
    Sim::OPT::StructureDesign::validate_refined_parent_config_text(
        $config_text,
        $zoom,
        target_dir => $target_dir,
    );

    my $totres_name = $s->{totres} || $root . '-0_totres.csv';
    my $crypt_name = $s->{cryptolinks} || $root . '_0_cryptolinks.pl';
    my $source_totres = File::Spec->catfile($source_dir, $totres_name);
    my $source_crypt = File::Spec->catfile($source_dir, $crypt_name);
    die "reembed '$to': source result file not found: $source_totres\n" unless -f $source_totres;
    die "reembed '$to': source cryptolinks not found: $source_crypt\n" unless -f $source_crypt;

    my $mapper = sub {
        return Sim::OPT::StructureDesign::map_local_instance_to_global($_[0], $zoom);
    };
    my $inc_local = exists($s->{incumbent}) ? _resolve_reference($s->{incumbent}, $manifest) : undef;
    my $inc_global = defined($inc_local) ? $mapper->($inc_local) : undef;

    return {
        state => $to,
        from => $from,
        operation => 'reembed',
        source_totres => $source_totres,
        target_totres => File::Spec->catfile($target_dir, $totres_name),
        config => $config_path,
        incumbent_local => $inc_local,
        incumbent_global => $inc_global,
    } unless $commit;

    die "reembed '$to': refusing to overwrite existing target directory $target_dir\n" if -e $target_dir;
    my $crypt = _load_cryptolinks($source_crypt);
    die "reembed '$to': cannot parse $source_crypt\n" unless ref($crypt) eq 'HASH' && keys %$crypt;
    my $crypt_rows = _cryptolink_rows(source => $crypt, root => $root);

    make_path($target_dir);
    _write_text_file($config_path, $config_text);
    my $base_model = File::Spec->catdir($zoom->{parent_dir} || $source_dir, $root);
    _copy_tree_exact($base_model, File::Spec->catdir($target_dir, $root)) if -d $base_model;

    for my $row (@$crypt_rows) {
        my $short = $row->{short};
        my $src_model = File::Spec->catdir($source_dir, $root . '_' . $short);
        die "reembed '$to': model directory referenced by cryptolinks is missing: $src_model\n" unless -d $src_model;
        _copy_tree_exact($src_model, File::Spec->catdir($target_dir, $root . '_' . $short));
    }

    my $rows = _rewrite_totres_clear_names(
        source => $source_totres,
        target => File::Spec->catfile($target_dir, $totres_name),
        mapper => $mapper,
    );
    my $mappings = _write_reembedded_cryptolinks(
        path => File::Spec->catfile($target_dir, $crypt_name),
        rows => $crypt_rows,
        target_dir => $target_dir,
        root => $root,
        mapper => $mapper,
    );
    die "reembed '$to': result-row count ($rows) differs from cryptolink mapping count (" . scalar(@$mappings) . ")\n"
        unless $rows == @$mappings;

    my $record = {
        schema => 'Sim::OPT::StructureDesign/reembed-state-1',
        operation => 'reembed',
        from_state => $from,
        to_state => $to,
        source_dir => $source_dir,
        target_dir => $target_dir,
        model_root => $root,
        zoom_plan => $zoom_path,
        variables => $zoom->{variables},
        global_counts => $zoom->{refined_counts},
        windows => $zoom->{windows},
        result_file => $totres_name,
        cryptolinks_file => $crypt_name,
        config_file => $config_name,
        result_rows => $rows,
        incumbent_local => $inc_local,
        incumbent_global => $inc_global,
        mappings => $mappings,
    };
    _write_json(File::Spec->catfile($target_dir, 'structuredesign-reembed.json'), $record);

    return {
        state => $to,
        from => $from,
        operation => 'reembed',
        result_rows => $rows,
        incumbent => $inc_global,
        manifest => File::Spec->catfile($target_dir, 'structuredesign-reembed.json'),
        totres => File::Spec->catfile($target_dir, $totres_name),
        cryptolinks => File::Spec->catfile($target_dir, $crypt_name),
        config => $config_path,
    };
}

sub _simopt_payload_base {
    my ($payload) = @_;
    my @f = split /,/, $payload, -1;
    die "Cannot interpret empty Sim::OPT result payload\n" unless @f;

    # A finalized Sim::OPT totres row has, after the clear instance id:
    #   name,value ... (k pairs), normalized_value ... (k), weighted_sum
    # i.e. 3*k+1 payload fields.  We deliberately recover only the
    # invariant name/value pairs here; normalization is landscape-relative.
    die "Cannot infer Sim::OPT objective layout from payload '$payload'\n"
        unless @f >= 4 && ((@f - 1) % 3) == 0;
    my $k = int((@f - 1) / 3);
    die "Cannot infer Sim::OPT objective layout from payload '$payload'\n" unless $k >= 1;

    my $num = qr/^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[Ee][+-]?\d+)?$/;
    my (@names, @raw_text, @raw);
    for my $i (0 .. $k - 1) {
        my $name = $f[2 * $i];
        my $val  = $f[2 * $i + 1];
        die "Missing objective name in payload '$payload'\n" unless defined($name) && length($name);
        die "Non-numeric raw objective '$val' in payload '$payload'\n" unless defined($val) && $val =~ $num;
        push @names, $name;
        push @raw_text, $val;
        push @raw, 0 + $val;
    }
    return {
        objective_count => $k,
        names => \@names,
        raw_text => \@raw_text,
        raw => \@raw,
    };
}

sub _result_payloads_compatible {
    my ($a, $b, $tol) = @_;
    $tol = 1e-9 unless defined $tol;
    my $aa = _simopt_payload_base($a);
    my $bb = _simopt_payload_base($b);
    return 0 unless $aa->{objective_count} == $bb->{objective_count};
    for my $i (0 .. $aa->{objective_count} - 1) {
        return 0 unless $aa->{names}[$i] eq $bb->{names}[$i];
        my ($x, $y) = ($aa->{raw}[$i], $bb->{raw}[$i]);
        my $scale = abs($x) > abs($y) ? abs($x) : abs($y);
        $scale = 1 if $scale < 1;
        return 0 if abs($x - $y) > $tol * $scale;
    }
    return 1;
}

sub _weights_from_config {
    my ($path, $k) = @_;
    die "Cannot read merge parent config $path: $!\n" unless -f $path;
    open my $fh, '<', $path or die "Cannot read $path: $!\n";
    local $/;
    my $txt = <$fh>;
    close $fh;
    my ($body) = $txt =~ /\@weights\s*=\s*\((.*?)\)\s*;/s;
    die "Cannot find active \@weights in $path\n" unless defined $body;
    $body =~ s/#.*$//mg;
    my @w;
    for my $part (split /,/, $body) {
        $part =~ s/^\s+|\s+$//g;
        next unless length $part;
        die "Non-numeric weight '$part' in $path\n"
            unless $part =~ /^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[Ee][+-]?\d+)?$/;
        push @w, 0 + $part;
    }
    die "Weight count in $path (" . scalar(@w) . ") does not match objective count $k\n"
        unless @w == $k;
    return \@w;
}

sub _renormalize_merged_payloads {
    my (%a) = @_;
    my $merged = $a{merged};
    my $order = $a{order};
    my $weights = $a{weights};
    die "renormalize_merged_payloads: merged HASH required\n" unless ref($merged) eq 'HASH';
    die "renormalize_merged_payloads: order ARRAY required\n" unless ref($order) eq 'ARRAY' && @$order;

    my $first = _simopt_payload_base($merged->{$order->[0]}{payload});
    my $k = $first->{objective_count};
    die "renormalize_merged_payloads: weights ARRAY required\n"
        unless ref($weights) eq 'ARRAY' && @$weights == $k;

    my @absmax = (0) x $k;
    my %base;
    for my $clear (@$order) {
        my $b = _simopt_payload_base($merged->{$clear}{payload});
        die "Merged objective count differs at '$clear'\n" unless $b->{objective_count} == $k;
        for my $i (0 .. $k - 1) {
            die "Merged objective name differs at '$clear'\n"
                unless $b->{names}[$i] eq $first->{names}[$i];
            my $av = abs($b->{raw}[$i]);
            $absmax[$i] = $av if $av > $absmax[$i];
        }
        $base{$clear} = $b;
    }

    for my $clear (@$order) {
        my $b = $base{$clear};
        my @norm;
        for my $i (0 .. $k - 1) {
            push @norm, $absmax[$i] ? ($b->{raw}[$i] / $absmax[$i]) : '';
        }
        my $wsum = 0;
        for my $i (0 .. $k - 1) {
            next if $norm[$i] eq '';
            $wsum += $norm[$i] * abs($weights->[$i]);
        }
        my @payload;
        for my $i (0 .. $k - 1) {
            push @payload, $b->{names}[$i], $b->{raw_text}[$i];
        }
        push @payload, @norm, $wsum;
        $merged->{$clear}{payload} = join(',', @payload);
    }
    return { objective_count => $k, absmaxes => \@absmax, weights => [ @$weights ] };
}

sub _read_totres_rows {
    my (%a) = @_;
    my $source = $a{source};
    my $mapper = $a{mapper};
    my $label = $a{label} || $source;
    die "read_totres_rows: source file not found: $source\n" unless -f $source;
    die "read_totres_rows: mapper CODE required\n" unless ref($mapper) eq 'CODE';
    open my $fh, '<', $source or die "Cannot read $source: $!\n";
    my (@rows, %seen);
    while (my $line = <$fh>) {
        $line =~ s/\r?\n\z//;
        next unless length($line);
        die "Unexpected non-result line in $source: $line\n"
            unless $line =~ /^((?:\d+-\d+)(?:_\d+-\d+)+),(.*)$/s;
        my ($local, $payload) = ($1, $2);
        my $clear = $mapper->($local);
        die "Duplicate mapped result '$clear' in $label\n" if $seen{$clear}++;
        push @rows, { source_clear => $local, clear => $clear, payload => $payload };
    }
    close $fh;
    die "No result rows found in $source\n" unless @rows;
    return \@rows;
}

sub _write_native_cryptolinks {
    my (%a) = @_;
    my $path = $a{path};
    my $rows = $a{rows};
    my $target_dir = $a{target_dir};
    my $root = $a{root};
    die "write_native_cryptolinks: rows ARRAY required\n" unless ref($rows) eq 'ARRAY';
    my %out;
    for my $row (@$rows) {
        my ($short, $clear) = @{$row}{qw(short clear)};
        die "write_native_cryptolinks: short and clear required\n"
            unless defined($short) && defined($clear);
        my $short_path = File::Spec->catfile($target_dir, $root . '_' . $short);
        my $clear_path = File::Spec->catfile($target_dir, $root . '_' . $clear);
        die "Cryptolink collision on '$clear'\n" if exists $out{$clear_path};
        $out{$short_path} = $clear_path;
        $out{$clear_path} = $short_path;
    }
    open my $fh, '>', $path or die "Cannot write $path: $!\n";
    print {$fh} "{\n";
    for my $k (sort keys %out) {
        my $v = $out{$k};
        (my $qk = $k) =~ s/([\\\"])/\\$1/g;
        (my $qv = $v) =~ s/([\\\"])/\\$1/g;
        print {$fh} qq{  "$qk" => "$qv",\n};
    }
    print {$fh} "}\n";
    close $fh or die "Cannot close $path: $!\n";
}

sub _payload_weighted_scalar {
    my ($payload) = @_;
    die "Cannot extract weighted scalar from undefined payload\n" unless defined $payload;
    my @f = split /,/, $payload, -1;
    die "Cannot extract weighted scalar from payload '$payload'\n" unless @f;
    my $x = $f[-1];
    my $num = qr/^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[Ee][+-]?\d+)?$/;
    die "Non-numeric weighted scalar '$x' in payload '$payload'\n"
        unless defined($x) && $x =~ $num;
    return 0 + $x;
}

sub _best_merged_scalar_incumbent {
    my (%a) = @_;
    my $merged = $a{merged};
    my $order = $a{order};
    die "best_merged_scalar: merged HASH required\n" unless ref($merged) eq 'HASH';
    die "best_merged_scalar: order ARRAY required\n" unless ref($order) eq 'ARRAY' && @$order;
    my ($best, $best_score);
    for my $clear (@$order) {
        my $score = _payload_weighted_scalar($merged->{$clear}{payload});
        if (!defined($best) || $score > $best_score) {
            ($best, $best_score) = ($clear, $score);
        }
    }
    return ($best, $best_score);
}

sub _execute_merge {
    my (%a) = @_;
    my $s = $a{step};
    my $p = $a{procedure};
    my $manifest = $a{manifest};
    my $commit = $a{commit};

    my $to = $s->{name} or die "merge: target state name required\n";
    my $parent = $s->{parent} or die "merge '$to': parent state required\n";
    my $refined = $s->{refined} or die "merge '$to': refined state required\n";
    my $parent_dir = _state_dir($p, $parent);
    my $refined_dir = _state_dir($p, $refined);
    my $target_dir = _state_dir($p, $to);
    die "merge '$to': parent state directory not found: $parent_dir\n" unless -d $parent_dir;
    die "merge '$to': refined state directory not found: $refined_dir\n" unless -d $refined_dir;

    my $zoom_file = $s->{zoom_plan} || File::Spec->catfile('btra', 'structuredesign-zoom.json');
    my $zoom_path = File::Spec->file_name_is_absolute($zoom_file)
        ? $zoom_file : File::Spec->catfile($p->{root_dir}, $zoom_file);
    die "merge '$to': zoom plan not found: $zoom_path\n" unless -f $zoom_path;
    my $zoom = _read_json($zoom_path);
    die "merge '$to': invalid zoom plan\n"
        unless ref($zoom) eq 'HASH' && ($zoom->{operation} || '') eq 'zoom_in';

    my $root = $s->{model_root} || $zoom->{model_root} || 'bt';
    my $totres_name = $s->{totres} || $root . '-0_totres.csv';
    my $crypt_name = $s->{cryptolinks} || $root . '_0_cryptolinks.pl';
    my $parent_totres = File::Spec->catfile($parent_dir, $totres_name);
    my $refined_totres = File::Spec->catfile($refined_dir, $totres_name);
    my $parent_crypt_path = File::Spec->catfile($parent_dir, $crypt_name);
    my $refined_crypt_path = File::Spec->catfile($refined_dir, $crypt_name);
    for my $f ($parent_totres, $refined_totres, $parent_crypt_path, $refined_crypt_path) {
        die "merge '$to': required source file not found: $f\n" unless -f $f;
    }

    require Sim::OPT::StructureDesign;

    # A merge changes accumulated experience, not state geometry.  The merged
    # state therefore receives an exact clone of the refined state's canonical
    # configuration, with only $mypath changed to the target directory.
    my $refined_cfg_name = $s->{refined_config} || "$refined.pl";
    my $refined_cfg_path = File::Spec->catfile($refined_dir, $refined_cfg_name);
    die "merge '$to': refined canonical config not found: $refined_cfg_path\n"
        unless -f $refined_cfg_path;
    my $refined_cfg_text = _read_text_file($refined_cfg_path);
    Sim::OPT::StructureDesign::validate_refined_parent_config_text(
        $refined_cfg_text,
        $zoom,
        target_dir => $refined_dir,
    );

    my $config_name = $s->{config} || "$to.pl";
    my $config_path = File::Spec->catfile($target_dir, $config_name);
    my $config_text = Sim::OPT::StructureDesign::render_cloned_state_config(
        $refined_cfg_path,
        target_dir => $target_dir,
    );
    Sim::OPT::StructureDesign::validate_cloned_state_config_text(
        $config_text,
        $refined_cfg_path,
        target_dir => $target_dir,
    );
    Sim::OPT::StructureDesign::validate_refined_parent_config_text(
        $config_text,
        $zoom,
        target_dir => $target_dir,
    );

    my %active = map { $_ => 1 } @{ $zoom->{variables} || [] };
    my $parent_mapper = sub {
        my ($clear) = @_;
        my $h = Sim::OPT::StructureDesign::parse_instance($clear);
        my %out = %$h;
        for my $v (keys %out) {
            next unless $active{$v};
            my $factor = 1;
            if (ref($zoom->{resolution_factors}) eq 'HASH' && exists $zoom->{resolution_factors}{$v}) {
                $factor = $zoom->{resolution_factors}{$v};
            } elsif (ref($zoom->{per_variable_axes}) eq 'HASH'
                     && ref($zoom->{per_variable_axes}{$v}) eq 'HASH'
                     && exists $zoom->{per_variable_axes}{$v}{resolution_factor}) {
                $factor = $zoom->{per_variable_axes}{$v}{resolution_factor};
            }
            my $offset = 0;
            if (ref($zoom->{parent_level_offsets}) eq 'HASH' && exists $zoom->{parent_level_offsets}{$v}) {
                $offset = 0 + $zoom->{parent_level_offsets}{$v};
            } elsif (ref($zoom->{per_variable_axes}) eq 'HASH'
                     && ref($zoom->{per_variable_axes}{$v}) eq 'HASH'
                     && exists $zoom->{per_variable_axes}{$v}{parent_level_offset}) {
                $offset = 0 + $zoom->{per_variable_axes}{$v}{parent_level_offset};
            }
            $out{$v} = $offset + Sim::OPT::StructureDesign::rescale_level($out{$v}, $factor);
        }
        return Sim::OPT::StructureDesign::format_instance(\%out);
    };
    my $identity = sub { return $_[0] };

    my $parent_rows = _read_totres_rows(source => $parent_totres, mapper => $parent_mapper, label => $parent);
    my $refined_rows = _read_totres_rows(source => $refined_totres, mapper => $identity, label => $refined);
    my $parent_crypt = _load_cryptolinks($parent_crypt_path);
    my $refined_crypt = _load_cryptolinks($refined_crypt_path);
    my $parent_links = _cryptolink_rows(source => $parent_crypt, root => $root);
    my $refined_links = _cryptolink_rows(source => $refined_crypt, root => $root);

    my (%parent_short, %refined_short);
    my $parent_max = 0;
    for my $r (@$parent_links) {
        my $g = $parent_mapper->($r->{local});
        die "merge '$to': parent cryptolink collision on '$g'\n" if exists $parent_short{$g};
        $parent_short{$g} = 0 + $r->{short};
        $parent_max = $r->{short} if $r->{short} > $parent_max;
    }
    for my $r (@$refined_links) {
        my $g = $r->{local};
        die "merge '$to': refined cryptolink collision on '$g'\n" if exists $refined_short{$g};
        $refined_short{$g} = 0 + $r->{short};
    }
    die "merge '$to': parent result/cryptolink counts differ\n" unless @$parent_rows == keys(%parent_short);
    die "merge '$to': refined result/cryptolink counts differ\n" unless @$refined_rows == keys(%refined_short);

    my (%merged, @order, @out_links, @overlaps, @copies);
    for my $r (@$parent_rows) {
        my $clear = $r->{clear};
        die "merge '$to': no parent model mapping for '$clear'\n" unless exists $parent_short{$clear};
        $merged{$clear} = { %$r, target_short => $parent_short{$clear}, source_state => $parent };
        push @order, $clear;
        push @out_links, { short => $parent_short{$clear}, clear => $clear };
        push @copies, { source_state => $parent, source_short => $parent_short{$clear}, target_short => $parent_short{$clear}, clear => $clear };
    }

    my $next_short = $parent_max;
    my $tol = exists($s->{overlap_tolerance}) ? 0 + $s->{overlap_tolerance} : 1e-9;
    for my $r (@$refined_rows) {
        my $clear = $r->{clear};
        die "merge '$to': no refined model mapping for '$clear'\n" unless exists $refined_short{$clear};
        if (exists $merged{$clear}) {
            die "merge '$to': overlapping point '$clear' has incompatible results\n"
                unless _result_payloads_compatible($merged{$clear}{payload}, $r->{payload}, $tol);
            push @overlaps, {
                clear => $clear,
                parent_short => $merged{$clear}{target_short},
                refined_short => $refined_short{$clear},
            };
            next;
        }
        my $target_short = ++$next_short;
        $merged{$clear} = { %$r, target_short => $target_short, source_state => $refined };
        push @order, $clear;
        push @out_links, { short => $target_short, clear => $clear };
        push @copies, { source_state => $refined, source_short => $refined_short{$clear}, target_short => $target_short, clear => $clear };
    }

    die "merge '$to': specify either incumbent or incumbent_policy, not both\n"
        if exists($s->{incumbent}) && defined($s->{incumbent_policy});
    my $inc = exists($s->{incumbent}) ? _resolve_reference($s->{incumbent}, $manifest) : undef;
    die "merge '$to': requested incumbent '$inc' is not in merged landscape\n"
        if defined($inc) && !exists($merged{$inc});
    my $incumbent_policy = $s->{incumbent_policy};

    # The model root names the physical model family (for example 'bt');
    # it is not necessarily the parent state's canonical configuration name.
    # For btr, for example, model_root is 'bt' while the state config is btr.pl.
    my $parent_cfg_name = $s->{parent_config} || ($parent . '.pl');
    my $parent_cfg = File::Spec->file_name_is_absolute($parent_cfg_name)
        ? $parent_cfg_name
        : File::Spec->catfile($parent_dir, $parent_cfg_name);
    my $first_base = _simopt_payload_base($merged{$order[0]}{payload});
    my $weights = ref($s->{weights}) eq 'ARRAY'
        ? [ @{ $s->{weights} } ]
        : _weights_from_config($parent_cfg, $first_base->{objective_count});
    my $normalization = _renormalize_merged_payloads(
        merged => \%merged, order => \@order, weights => $weights,
    );

    my $incumbent_score;
    if (defined($incumbent_policy)) {
        die "merge '$to': unsupported incumbent_policy '$incumbent_policy'\n"
            unless $incumbent_policy eq 'best_merged_scalar';
        ($inc, $incumbent_score) = _best_merged_scalar_incumbent(
            merged => \%merged, order => \@order,
        );
    } elsif (defined($inc)) {
        $incumbent_score = _payload_weighted_scalar($merged{$inc}{payload});
    }

    my $summary = {
        state => $to,
        operation => 'merge',
        parent => $parent,
        refined => $refined,
        parent_rows => scalar(@$parent_rows),
        refined_rows => scalar(@$refined_rows),
        overlap_rows => scalar(@overlaps),
        result_rows => scalar(@order),
        incumbent => $inc,
        incumbent_policy => $incumbent_policy,
        incumbent_score => $incumbent_score,
        overlap_comparison => 'objective_names_and_raw_values',
        normalization => $normalization,
        config => $config_path,
        geometry_source_config => $refined_cfg_path,
        target_totres => File::Spec->catfile($target_dir, $totres_name),
    };
    return $summary unless $commit;

    die "merge '$to': refusing to overwrite existing target directory $target_dir\n" if -e $target_dir;
    make_path($target_dir);
    _write_text_file($config_path, $config_text);
    my $base_model = File::Spec->catdir($parent_dir, $root);
    _copy_tree_exact($base_model, File::Spec->catdir($target_dir, $root)) if -d $base_model;

    for my $c (@copies) {
        my $src_dir = $c->{source_state} eq $parent ? $parent_dir : $refined_dir;
        my $src_model = File::Spec->catdir($src_dir, $root . '_' . $c->{source_short});
        my $dst_model = File::Spec->catdir($target_dir, $root . '_' . $c->{target_short});
        die "merge '$to': source model directory missing: $src_model\n" unless -d $src_model;
        _copy_tree_exact($src_model, $dst_model);
    }

    my $target_totres = File::Spec->catfile($target_dir, $totres_name);
    open my $tfh, '>', $target_totres or die "Cannot write $target_totres: $!\n";
    for my $clear (@order) {
        print {$tfh} $clear, ',', $merged{$clear}{payload}, "\n";
    }
    close $tfh or die "Cannot close $target_totres: $!\n";

    my $target_crypt = File::Spec->catfile($target_dir, $crypt_name);
    _write_native_cryptolinks(
        path => $target_crypt,
        rows => \@out_links,
        target_dir => $target_dir,
        root => $root,
    );

    my $record = {
        schema => 'Sim::OPT::StructureDesign/merge-state-1',
        operation => 'merge',
        parent_state => $parent,
        refined_state => $refined,
        to_state => $to,
        parent_dir => $parent_dir,
        refined_dir => $refined_dir,
        target_dir => $target_dir,
        zoom_plan => $zoom_path,
        model_root => $root,
        global_counts => $zoom->{refined_counts},
        parent_level_rule => 'new_level = parent_level_offset + 1 + resolution_factor * (old_level - 1)',
        parent_rows => scalar(@$parent_rows),
        refined_rows => scalar(@$refined_rows),
        overlap_rows => scalar(@overlaps),
        added_refined_rows => scalar(@$refined_rows) - scalar(@overlaps),
        result_rows => scalar(@order),
        overlap_tolerance => $tol,
        overlap_comparison => 'objective_names_and_raw_values',
        normalization => $normalization,
        incumbent => $inc,
        incumbent_policy => $incumbent_policy,
        incumbent_score => $incumbent_score,
        overlaps => \@overlaps,
        mappings => \@out_links,
        config_file => $config_name,
        geometry_source_config => $refined_cfg_path,
        result_file => $totres_name,
        cryptolinks_file => $crypt_name,
    };
    my $record_path = File::Spec->catfile($target_dir, 'structuredesign-merge.json');
    _write_json($record_path, $record);

    return {
        %$summary,
        config => $config_path,
        totres => $target_totres,
        cryptolinks => $target_crypt,
        manifest => $record_path,
    };
}

sub _perl_sq {
    my ($s) = @_;
    $s = '' unless defined $s;
    $s =~ s/\\/\\\\/g;
    $s =~ s/'/\\'/g;
    return "'$s'";
}

sub _infer_fixed_levels_from_totres {
    my (%a) = @_;
    my $path = $a{path};
    my $counts = $a{counts};
    die "infer_fixed_levels: results file required\n" unless defined($path) && -f $path;
    die "infer_fixed_levels: counts HASH required\n" unless ref($counts) eq 'HASH' && keys %$counts;

    my %seen;
    my %seen_clear;
    my $rows = 0;
    open my $fh, '<', $path or die "Cannot read $path: $!\n";
    while (my $line = <$fh>) {
        chomp $line;
        next unless length $line;
        my ($clear) = split /,/, $line, 2;
        die "Cannot read clear instance id from $path row " . ($rows + 1) . "\n"
            unless defined($clear) && length($clear);
        die "Duplicate clear instance '$clear' in $path\n" if $seen_clear{$clear}++;
        my %coord;
        while ($clear =~ /(?:^|_)(\d+)-(\d+)(?=_|$)/g) {
            $coord{0 + $1} = 0 + $2;
        }
        my @vars = sort { $a <=> $b } keys %$counts;
        my @missing = grep { !exists $coord{$_} } @vars;
        my @extra = grep { !exists $counts->{$_} && !exists $counts->{"$_"} } keys %coord;
        die "Results row " . ($rows + 1) . " variable mismatch; missing=[@missing], extra=[@extra]\n"
            if @missing || @extra;
        for my $v (@vars) {
            my $max = exists($counts->{$v}) ? $counts->{$v} : $counts->{"$v"};
            my $lev = $coord{$v};
            die "Results row " . ($rows + 1) . ": variable $v level $lev outside 1..$max\n"
                if $lev < 1 || $lev > $max;
            $seen{$v}{$lev} = 1;
        }
        $rows++;
    }
    close $fh;
    die "Results file is empty: $path\n" unless $rows;

    my %fixed;
    for my $v (sort { $a <=> $b } keys %$counts) {
        my @lev = sort { $a <=> $b } keys %{ $seen{$v} || {} };
        $fixed{$v} = $lev[0] if @lev == 1;
    }
    return (\%fixed, $rows);
}

sub _write_clustermedoid_config {
    my (%a) = @_;
    my $path = $a{path};
    my $state_dir = $a{state_dir};
    my $root = $a{root};
    my $counts = $a{counts};
    my $fixed = $a{fixed};
    die "write_clustermedoid_config: path required\n" unless defined($path) && length($path);
    die "write_clustermedoid_config: counts HASH required\n" unless ref($counts) eq 'HASH';
    die "write_clustermedoid_config: fixed HASH required\n" unless ref($fixed) eq 'HASH';

    open my $fh, '>', $path or die "Cannot write $path: $!\n";
    print {$fh} "# Generated by Sim::OPT::StructureDesignProcedure for abstraction only.\n";
    print {$fh} '$mypath = ', _perl_sq($state_dir), ";\n";
    print {$fh} '$file = ', _perl_sq($root), ";\n";
    print {$fh} "\@varinumbers = ({\n";
    for my $v (sort { $a <=> $b } keys %$counts) {
        my $L = exists($counts->{$v}) ? $counts->{$v} : $counts->{"$v"};
        print {$fh} "    $v => $L,\n";
    }
    print {$fh} "});\n";
    print {$fh} "%landscapecluster = (\n";
    print {$fh} "    sweep_index => 0,\n";
    print {$fh} "    combination_column => 0,\n";
    print {$fh} "    performance_column => 2,\n";
    print {$fh} "    header => 0,\n";
    print {$fh} "    fixed_levels => {\n";
    for my $v (sort { $a <=> $b } keys %$fixed) {
        print {$fh} "        $v => $fixed->{$v},\n";
    }
    print {$fh} "    },\n";
    print {$fh} "    context_variables => [],\n";
    print {$fh} "    lambda => 0.5,\n";
    print {$fh} "    performance => { divisions => 100 },\n";
    print {$fh} "    clustering => {\n";
    print {$fh} "        clusters => 'auto',\n";
    print {$fh} "        k_min => 2,\n";
    print {$fh} "        k_max => 12,\n";
    print {$fh} "        max_iterations => 50,\n";
    print {$fh} "        silhouette_sample => 600,\n";
    print {$fh} "    },\n";
    print {$fh} ");\n1;\n";
    close $fh or die "Cannot close $path: $!\n";
}

sub _execute_abstract {
    my (%a) = @_;
    my $s = $a{step};
    my $p = $a{procedure};
    my $commit = $a{commit};
    my $state = $s->{name} || $s->{state} or die "abstract: state required\n";
    my $using = $s->{using};
    my $kind = ref($using) eq 'HASH' ? ($using->{kind} || '') : '';
    die "abstract '$state': installed executor supports clustering_and_finding_medoids only\n"
        unless $kind eq 'clustering_and_finding_medoids' || $kind eq 'medoids';

    my $state_dir = _state_dir($p, $state);
    die "abstract '$state': state directory not found: $state_dir\n" unless -d $state_dir;
    my $root = $s->{model_root} || 'bt';
    my $results = File::Spec->catfile($state_dir, $s->{results_file} || ($root . '-0_totres.csv'));
    die "abstract '$state': results file not found: $results\n" unless -f $results;

    my $lattice_manifest = $s->{lattice_manifest};
    if (!defined($lattice_manifest) || !length($lattice_manifest)) {
        for my $candidate ('structuredesign-merge.json', 'structuredesign-reembed.json') {
            my $path = File::Spec->catfile($state_dir, $candidate);
            if (-f $path) { $lattice_manifest = $path; last; }
        }
    } elsif (!File::Spec->file_name_is_absolute($lattice_manifest)) {
        $lattice_manifest = File::Spec->catfile($state_dir, $lattice_manifest);
    }
    die "abstract '$state': no lattice manifest found\n"
        unless defined($lattice_manifest) && -f $lattice_manifest;
    my $lattice = _read_json($lattice_manifest);
    my $counts = $lattice->{global_counts} || $lattice->{target_counts};
    die "abstract '$state': lattice manifest has no global_counts or target_counts\n"
        unless ref($counts) eq 'HASH' && keys %$counts;

    my ($fixed, $rows) = _infer_fixed_levels_from_totres(path => $results, counts => $counts);
    if (defined($lattice->{result_rows})) {
        die "abstract '$state': source row count $rows differs from lattice manifest result_rows $lattice->{result_rows}\n"
            unless $rows == 0 + $lattice->{result_rows};
    }
    my $rel = $s->{output_dir} || 'abstract';
    my $out_dir = File::Spec->catdir($state_dir, $rel);
    my $prefix_name = $s->{output_prefix} || $state;
    my $prefix = File::Spec->catfile($out_dir, $prefix_name);
    my $cfg = File::Spec->catfile($out_dir, $prefix_name . '-clustermedoid.pl');

    my $summary = {
        state => $state,
        operation => 'abstract',
        method => 'clustering_and_finding_medoids',
        rows => $rows,
        fixed_levels => { %$fixed },
        results_file => $results,
        lattice_manifest => $lattice_manifest,
        output_dir => $out_dir,
        output_prefix => $prefix,
    };
    return $summary unless $commit;

    die "abstract '$state': refusing to overwrite existing output directory $out_dir\n" if -e $out_dir;
    make_path($out_dir);
    _write_clustermedoid_config(
        path => $cfg, state_dir => $state_dir, root => $root,
        counts => $counts, fixed => $fixed,
    );

    require Sim::OPT::ClusterMedoid;
    my $res = Sim::OPT::ClusterMedoid::cluster_medoid(
        search_config => $cfg,
        results_file => $results,
        output_prefix => $prefix,
        verbose => $s->{verbose} ? 1 : 0,
    );
    die "abstract '$state': ClusterMedoid returned no result hash\n" unless ref($res) eq 'HASH';
    die "abstract '$state': ClusterMedoid row count $res->{rows} does not match source row count $rows\n"
        unless defined($res->{rows}) && $res->{rows} == $rows;

    my $record = {
        schema => 'Sim::OPT::StructureDesign/abstraction-1',
        operation => 'abstract',
        method => 'clustering_and_finding_medoids',
        state => $state,
        source => $s->{source} || 'experienced_landscape',
        rows => 0 + $res->{rows},
        clusters => 0 + $res->{clusters},
        silhouette => 0 + $res->{silhouette},
        lambda => 0 + $res->{lambda},
        fixed_levels => { %$fixed },
        fixed_variables => $res->{fixed_variables},
        context_variables => $res->{context_variables},
        problem_variables => $res->{problem_variables},
        performance_column => $res->{performance_column},
        lattice_manifest => $lattice_manifest,
        clustering_config => $cfg,
        results_file => $results,
        files => $res->{files},
        medoids => $res->{medoids},
        silhouette_scores => $res->{silhouette_scores},
    };
    my $record_path = File::Spec->catfile($out_dir, 'structuredesign-abstraction.json');
    _write_json($record_path, $record);

    return {
        %$summary,
        clusters => 0 + $res->{clusters},
        silhouette => 0 + $res->{silhouette},
        medoid_count => scalar(@{ $res->{medoids} || [] }),
        files => $res->{files},
        config => $cfg,
        manifest => $record_path,
    };
}

sub _resolve_executable {
    my ($state_dir, $requested, $root_dir) = @_;
    $requested ||= 'opt';
    if (!File::Spec->file_name_is_absolute($requested)) {
        my $local = File::Spec->catfile($state_dir, $requested);
        return $local if -f $local && -x $local;
        # A blank-slate procedure commonly has the launcher only in the initial
        # bt workspace. Reuse that launcher for generated sibling states.
        if (defined($root_dir) && length($root_dir)) {
            my $initial = File::Spec->catfile($root_dir, 'bt', $requested);
            return $initial if -f $initial && -x $initial;
        }
    }
    return $requested; # exec will resolve via PATH when appropriate
}

sub _load_cryptolinks {
    my ($path) = @_;
    return {} unless -f $path;
    my $data = do $path;
    return $data if ref($data) eq 'HASH';
    open my $fh, '<', $path or return {};
    local $/; my $txt = <$fh>; close $fh;
    my %h;
    while ($txt =~ /["']([^"']+)["']\s*=>\s*(?:["']([^"']*)["']|(\d+))/g) {
        $h{$1} = defined($2) ? $2 : $3;
    }
    return \%h;
}

sub _clear_from_token {
    my (%a) = @_;
    my $token = $a{token};
    return unless defined $token;
    if ($token =~ /((?:\d+-\d+)(?:_\d+-\d+)+)/) {
        return $1;
    }
    my $short;
    if ($token =~ /^\s*(\d+)\s*$/) {
        $short = $1;
    } elsif ($token =~ /\Q$a{root}\E_(\d+)/) {
        $short = $1;
    }
    return unless defined $short;
    my $crypt = _load_cryptolinks($a{cryptolinks});
    for my $clear (keys %$crypt) {
        return $clear if defined($crypt->{$clear}) && "$crypt->{$clear}" eq "$short";
    }
    return;
}

sub _detect_winner {
    my (%a) = @_;
    my $dir  = $a{state_dir};
    my $root = $a{model_root} || 'bt';
    my $crypt = File::Spec->catfile($dir, $root . '_0_cryptolinks.pl');

    # Preferred durable source: Descend's response.txt.
    my $response = File::Spec->catfile($dir, 'response.txt');
    if (-f $response) {
        open my $fh, '<', $response or die "Cannot read $response: $!\n";
        my @candidates;
        while (my $line = <$fh>) {
            if ($line =~ /#Optimal option for case\s+\d+\s*:\s*(.*?)\.?\s*$/) {
                push @candidates, $1;
            }
        }
        close $fh;
        for my $tok (reverse @candidates) {
            my $clear = _clear_from_token(token => $tok, root => $root, cryptolinks => $crypt);
            return $clear if defined $clear;
        }
    }

    # Fallback: newest tofile/debug log, looking only for winner-labelled lines.
    opendir my $dh, $dir or die "Cannot open $dir: $!\n";
    my @logs = map { File::Spec->catfile($dir, $_) }
               grep { /tofile.*\.txt$/ && -f File::Spec->catfile($dir, $_) } readdir($dh);
    closedir $dh;
    @logs = sort { (stat($b))[9] <=> (stat($a))[9] } @logs;
    for my $log (@logs) {
        open my $fh, '<', $log or next;
        my $last;
        while (my $line = <$fh>) {
            next unless $line =~ /winner/i;
            if ($line =~ /((?:\d+-\d+)(?:_\d+-\d+)+)/) {
                $last = $1;
            } elsif ($line =~ /winneritem[^0-9]*(\d+)/i) {
                $last = $1;
            }
        }
        close $fh;
        if (defined $last) {
            my $clear = _clear_from_token(token => $last, root => $root, cryptolinks => $crypt);
            return $clear if defined $clear;
        }
    }

    return;
}

sub _read_text {
    my ($path) = @_;
    open my $fh, '<', $path or die "Cannot read $path: $!\n";
    local $/;
    my $txt = <$fh>;
    close $fh;
    return $txt;
}

sub _write_text_atomic {
    my ($path, $txt) = @_;
    my $tmp = "$path.tmp.$$";
    open my $fh, '>', $tmp or die "Cannot write $tmp: $!\n";
    print {$fh} $txt;
    close $fh or die "Cannot close $tmp: $!\n";
    rename $tmp, $path or die "Cannot rename $tmp -> $path: $!\n";
}

sub _replace_active_sweeps {
    my (%a) = @_;
    my $text = $a{text};
    my $replacement = $a{replacement};
    die "replace_active_sweeps: text required\n" unless defined $text;
    die "replace_active_sweeps: replacement required\n" unless defined $replacement;

    my @lines = split /(?<=\n)/, $text;
    my ($start, $end);
    for (my $i = 0; $i < @lines; $i++) {
        next unless $lines[$i] =~ /^\s*\@sweeps\s*=/;
        $start = $i;
        for (my $j = $i; $j < @lines; $j++) {
            if ($lines[$j] =~ /;/) { $end = $j; last; }
        }
        last;
    }
    die "Could not find active \@sweeps assignment in acquisition source config\n"
        unless defined($start) && defined($end);
    splice @lines, $start, ($end - $start + 1), $replacement . "\n";
    return join('', @lines);
}

sub _force_dowhat_setting {
    my (%a) = @_;
    my $text = $a{text};
    my $key = $a{key};
    my $value = $a{value};
    die "force_dowhat_setting: text required\n" unless defined $text;
    die "force_dowhat_setting: key required\n" unless defined($key) && length($key);
    die "force_dowhat_setting: value required\n" unless defined $value;

    my @lines = split /(?<=\n)/, $text;
    my ($start, $end);
    for (my $i = 0; $i < @lines; $i++) {
        next unless $lines[$i] =~ /^\s*%dowhat\s*=\s*\(/;
        $start = $i;
        for (my $j = $i + 1; $j < @lines; $j++) {
            if ($lines[$j] =~ /^\s*\)\s*;\s*(?:#.*)?$/) { $end = $j; last; }
        }
        last;
    }
    die "Could not find active %dowhat assignment in acquisition source config\n"
        unless defined($start) && defined($end);

    my $replacement = qq{${key} => "$value",\n};
    for (my $i = $start + 1; $i < $end; $i++) {
        next if $lines[$i] =~ /^\s*#/;
        if ($lines[$i] =~ /^\s*\Q$key\E\s*=>/) {
            my ($indent) = $lines[$i] =~ /^(\s*)/;
            $lines[$i] = $indent . $replacement;
            return join('', @lines);
        }
    }

    my ($indent) = $lines[$start] =~ /^(\s*)/;
    splice @lines, $start + 1, 0, $indent . $replacement;
    return join('', @lines);
}

sub _compile_star_experience {
    my (%a) = @_;
    my $s = $a{step};
    my $p = $a{procedure};
    my $commit = $a{commit};
    my $state = $s->{name} || $s->{state} or die "star experience: state required\n";
    my $using = $s->{using};
    die "star experience '$state': using HASH required\n" unless ref($using) eq 'HASH';

    my $divisions = $using->{divisions};
    die "star experience '$state': divisions must be a positive integer\n"
        unless defined($divisions) && $divisions =~ /^\d+$/ && $divisions >= 1;
    die "star experience '$state': sparse real-simulation acquisition currently requires divisions => 1. In Sim::OPT, divisions > 1 creates multiple star centres and launches an axial block search from every centre; it is not a count of sampled designs.\n"
        unless $divisions == 1;

    my $vars = $using->{variables};
    die "star experience '$state': variables must be a non-empty ARRAY\n"
        unless ref($vars) eq 'ARRAY' && @$vars;
    my @vars = map {
        die "star experience '$state': variable ids must be positive integers\n"
            unless defined($_) && /^\d+$/ && $_ >= 1;
        0 + $_;
    } @$vars;
    my %seen;
    die "star experience '$state': variable ids must be unique\n"
        if grep { $seen{$_}++ } @vars;

    my $dir = _state_dir($p, $state);
    die "star experience '$state': state directory not found: $dir\n" unless -d $dir;
    my $base_name = $s->{config} || "$state.pl";
    my $base_cfg = File::Spec->catfile($dir, $base_name);
    die "star experience '$state': source config not found: $base_cfg\n" unless -f $base_cfg;

    my $compiled_name = $using->{compiled_config} || ($state . '-star.pl');
    my $compiled_cfg = File::Spec->catfile($dir, $compiled_name);
    my $marker = '1>' . $vars[0];
    my @sweep_items = ('"' . $marker . '"', map { "$_" } @vars[1 .. $#vars]);
    my $sweep_assignment = '\@sweeps = ( [ [ ' . join(' , ', @sweep_items) . ' ] ] );';
    $sweep_assignment =~ s/^\\@/@/;

    my $scope_path = File::Spec->catfile($dir, 'structuredesign-scope.json');
    die "star experience '$state': scope manifest not found: $scope_path\n" unless -f $scope_path;
    my $scope = _read_json($scope_path);
    my $counts = $scope->{target_counts};
    die "star experience '$state': scope manifest has no target_counts\n" unless ref($counts) eq 'HASH';

    my %active_counts;
    my $expected_rows = 1; # common centre is shared by every axial line
    for my $v (@vars) {
        my $L = exists($counts->{$v}) ? $counts->{$v} : $counts->{"$v"};
        die "star experience '$state': target count missing for variable $v\n" unless defined($L) && $L =~ /^\d+$/ && $L >= 1;
        $active_counts{$v} = 0 + $L;
        $expected_rows += $L - 1;
    }

    my $plan = {
        schema => 'Sim::OPT::StructureDesign/star-experience-2',
        operation => 'experience',
        acquisition => 'star',
        star_mode => 'single_centre_axial',
        state => $state,
        source_config => $base_cfg,
        acquisition_config => $compiled_cfg,
        divisions => 1,
        variables => \@vars,
        active_counts => \%active_counts,
        encoded_sweep => $sweep_assignment,
        star_centres => 1,
        expected_result_rows => 0 + $expected_rows,
        metamodel => 'n',
        outstarmode => 'n',
    };
    return $plan unless $commit;

    my $txt = _read_text($base_cfg);
    my $compiled = _replace_active_sweeps(text => $txt, replacement => $sweep_assignment);
    $compiled = _force_dowhat_setting(text => $compiled, key => 'metamodel', value => 'n');
    $compiled = _force_dowhat_setting(text => $compiled, key => 'outstarmode', value => 'n');
    _write_text_atomic($compiled_cfg, $compiled);
    return $plan;
}

sub _count_result_rows {
    my ($path) = @_;
    die "Results file not found: $path\n" unless -f $path;
    open my $fh, '<', $path or die "Cannot read $path: $!\n";
    my $n = 0;
    while (my $line = <$fh>) {
        $n++ if $line =~ /\S/;
    }
    close $fh;
    return $n;
}

# Detect exactly one plain numeric sweep block, e.g. [ [ 2, 4 ] ]. Encoded
# sparse/star sweep atoms such as "2>2" deliberately do not match.
sub _plain_full_factorial_variables {
    my ($config_path) = @_;
    return undef unless defined($config_path) && -f $config_path;
    my $txt = _read_text_file($config_path);
    my ($rhs) = $txt =~ /^(?!\s*#)\s*\@sweeps\s*=\s*([^;]+);/m;
    return undef unless defined $rhs;
    return undef unless $rhs =~ /^\s*\(\s*\[\s*\[\s*(\d+(?:\s*,\s*\d+)*)\s*\]\s*\]\s*\)\s*$/;
    my @vars = map { 0 + $_ } split /\s*,\s*/, $1;
    return @vars ? \@vars : undef;
}

sub _validate_expected_factorial {
    my (%a) = @_;
    my ($state, $vars, $counts, $results) = @a{qw(state variables counts results)};
    die "experience '$state': factorial variables must be a non-empty ARRAY reference\n"
        unless ref($vars) eq 'ARRAY' && @$vars;
    die "experience '$state': factorial counts must be a HASH reference\n"
        unless ref($counts) eq 'HASH' && keys %$counts;
    my $expected = 1;
    for my $v (@$vars) {
        die "experience '$state': lattice/config lacks variable $v\n"
            unless exists($counts->{$v}) || exists($counts->{"$v"});
        my $L = exists($counts->{$v}) ? $counts->{$v} : $counts->{"$v"};
        die "experience '$state': variable $v has invalid level count '$L'\n"
            unless defined($L) && "$L" =~ /^\d+$/ && $L >= 1;
        $expected *= 0 + $L;
    }
    my $rows = _count_result_rows($results);
    die "experience '$state': expected full-factorial "
        . join('x', map { exists($counts->{$_}) ? $counts->{$_} : $counts->{"$_"} } @$vars)
        . " = $expected result rows but found $rows in $results\n"
        unless $rows == $expected;
    return ($expected, $rows);
}

sub _ensure_local_opt_launcher {
    my (%a) = @_;
    my $dir = $a{state_dir};
    my $resolved = $a{resolved};
    die "local OPT launcher: state directory required\n" unless defined($dir) && -d $dir;

    my $local = File::Spec->catfile($dir, 'opt');
    if (-e $local || -l $local) {
        die "local OPT launcher exists but is not executable: $local\n" unless -x $local;
        return $local;
    }

    # For generated StructureDesign states, preserve the user's normal launch
    # convention: every simulation is entered through a local ./opt.  The
    # configured source launcher remains authoritative; a symlink avoids
    # creating stale independent copies.  Fall back to a byte-for-byte copy on
    # filesystems where symlinks are unavailable.
    my $source = $resolved;
    $source = abs_path($source) if defined($source) && -e $source;
    die "Cannot stage local ./opt in $dir: resolved launcher '$resolved' is not an executable file\n"
        unless defined($source) && -f $source && -x $source;

    if (!symlink($source, $local)) {
        copy($source, $local) or die "Cannot copy OPT launcher $source -> $local: $!\n";
        my $mode = (stat($source))[2] & 07777;
        chmod($mode, $local) or die "Cannot chmod local OPT launcher $local: $!\n";
    }
    die "Staged local OPT launcher is not executable: $local\n" unless -x $local;
    return $local;
}

sub _run_opt {
    my (%a) = @_;
    my $dir = $a{state_dir};
    my $config = $a{config};
    die "run_opt: state directory does not exist: $dir\n" unless -d $dir;
    die "run_opt: configuration filename contains a newline\n"
        if !defined($config) || $config =~ /[\r\n]/;
    my $cfg = File::Spec->catfile($dir, $config);
    die "run_opt: configuration does not exist: $cfg\n" unless -f $cfg;
    my $resolved = _resolve_executable($dir, $a{executable}, $a{root_dir});
    _ensure_local_opt_launcher(state_dir => $dir, resolved => $resolved);

    my $cwd = getcwd();
    chdir $dir or die "Cannot chdir to $dir: $!\n";
    print "[StructureDesign] launching ./opt by heredoc in $dir with $config\n";

    # Use the same interactive entry point as a manual run:
    #
    #   ./opt <<XXX
    #   ./config.pl
    #   XXX
    #
    # The quoted delimiter prevents shell expansion of the configuration line.
    # Invoking the state-local ./opt is intentional: launch wrappers that create
    # timestamped tofile_.txt diagnostics relative to their invocation directory
    # now see exactly the same launch form as a manual run.
    my $script = "./opt <<'STRUCTUREDESIGN_OPT_CONFIG'\n"
               . "./$config\n"
               . "STRUCTUREDESIGN_OPT_CONFIG\n";
    my $rc = system('/bin/sh', '-c', $script);
    my $status = $?;
    chdir $cwd or die "Cannot restore cwd $cwd: $!\n";

    if ($rc == -1) {
        die "Cannot launch local './opt' for state $a{state}: $!\n";
    }
    if ($status & 127) {
        die "OPT failed for state $a{state} (signal " . ($status & 127) . ")\n";
    }
    my $exit = $status >> 8;
    die "OPT failed for state $a{state} (status $exit)\n" unless $exit == 0;
    return { exit_status => 0, launcher => './opt', input_mode => 'heredoc' };
}

sub _resolve_reference {
    my ($ref, $manifest) = @_;
    return $ref unless ref($ref) eq 'HASH' && $ref->{ref};
    my $sid = $ref->{step} or die "Reference has no step id\n";
    my $rec = $manifest->{steps}{$sid} or die "Reference points to unknown step '$sid'\n";
    die "Referenced step '$sid' is not COMPLETE\n" unless ($rec->{status} || '') eq 'COMPLETE';
    my $key = $ref->{ref} eq 'incumbent' ? 'incumbent' : ($ref->{key} || 'result');
    die "Referenced step '$sid' has no '$key' result\n" unless exists $rec->{result}{$key};
    return $rec->{result}{$key};
}

sub _compile_zoom {
    my (%a) = @_;
    my $step = $a{step};
    my $p = $a{procedure};
    my $manifest = $a{manifest};
    my $from = $step->{from} or die "derive '$step->{name}': from required\n";
    my $to   = $step->{name} or die "derive: target state name required\n";
    my $by = $step->{by} || [];
    die "derive '$to': by must be ARRAY\n" unless ref($by) eq 'ARRAY';

    my ($scope, $res);
    for my $op (@$by) {
        $scope = $op if ($op->{op} || '') eq 'reduce_scope';
        $res   = $op if ($op->{op} || '') eq 'increase_resolution';
    }
    die "derive '$to': the installed executor currently supports reduce_scope + optional increase_resolution; requested procedure remains valid but needs another StructureDesign executor\n"
        unless $scope;

    my @vars = @{ $scope->{variables} || [] };
    die "derive '$to': reduce_scope.variables required\n" unless @vars;
    my $levels = $scope->{levels} // 3;
    my %factors = map { $_ => 1 } @vars;
    my %strides = map { $_ => 1 } @vars;
    if ($res) {
        my $factor = $res->{factor} // 2;
        for my $v (@{ $res->{variables} || [] }) {
            $factors{$v} = (ref($res->{factors}) eq 'HASH' && exists $res->{factors}{$v})
                ? $res->{factors}{$v} : $factor;
            $strides{$v} = (ref($res->{local_strides}) eq 'HASH' && exists $res->{local_strides}{$v})
                ? $res->{local_strides}{$v} : 1;
        }
    }
    my %local = map { $_ => $levels } @vars;

    my $around = _resolve_reference($step->{around}, $manifest);
    die "derive '$to': around/incumbent required\n" unless defined($around) && length($around);

    my $parent_cfg = _state_config($p, $from, $step->{parent_config} || "$from.pl");
    my $child_dir  = _state_dir($p, $to);
    my $child_cfg  = $step->{config} || "$to.pl";

    require Sim::OPT::StructureDesign;
    my $plan = Sim::OPT::StructureDesign::plan_zoom_in(
        parent_config => $parent_cfg,
        incumbent => $around,
        variables => \@vars,
        resolution_factors => \%factors,
        local_levels => \%local,
        local_strides => \%strides,
        child_dir => $child_dir,
        child_config => $child_cfg,
    );
    return $plan;
}

sub _compile_enlarge_pan {
    my (%a) = @_;
    my $step = $a{step};
    my $p = $a{procedure};
    my $manifest = $a{manifest};
    my $from = $step->{from} or die "derive '$step->{name}': from required\n";
    my $to = $step->{name} or die "derive: target state name required\n";
    my $by = $step->{by} || [];
    die "derive '$to': by must be ARRAY\n" unless ref($by) eq 'ARRAY';

    my ($enlarge, $maintain, $pan);
    for my $op (@$by) {
        $enlarge = $op if ($op->{op} || '') eq 'enlarge_scope';
        $maintain = $op if ($op->{op} || '') eq 'maintain_resolution';
        $pan = $op if ($op->{op} || '') eq 'pan';
    }
    die "derive '$to': enlarge_scope + maintain_resolution + pan required by this executor\n"
        unless $enlarge && $maintain && $pan;

    my @vars = @{ $enlarge->{variables} || [] };
    die "derive '$to': enlarge_scope.variables required\n" unless @vars;
    if (ref($maintain->{variables}) eq 'ARRAY' && @{ $maintain->{variables} }) {
        my $vars_a = join(',', sort { $a <=> $b } @vars);
        my $vars_b = join(',', sort { $a <=> $b } @{ $maintain->{variables} });
        die "derive '$to': maintain_resolution.variables must match enlarge_scope.variables\n"
            unless $vars_a eq $vars_b;
    }

    my $around_ref = exists($pan->{around}) ? $pan->{around} : $step->{around};
    my $around = _resolve_reference($around_ref, $manifest);
    die "derive '$to': pan.around/incumbent required\n"
        unless defined($around) && length($around);

    my $source_dir = _state_dir($p, $from);
    die "derive '$to': source state directory not found: $source_dir\n" unless -d $source_dir;
    my $lm_name = $step->{lattice_manifest} || 'structuredesign-merge.json';
    my $lm_path = File::Spec->file_name_is_absolute($lm_name)
        ? $lm_name : File::Spec->catfile($source_dir, $lm_name);
    die "derive '$to': lattice manifest not found: $lm_path\n" unless -f $lm_path;
    my $lm = _read_json($lm_path);
    die "derive '$to': lattice manifest has no global_counts\n"
        unless ref($lm->{global_counts}) eq 'HASH' && keys %{ $lm->{global_counts} };
    if (defined($lm->{incumbent}) && length($lm->{incumbent}) && $lm->{incumbent} ne $around) {
        die "derive '$to': requested pan incumbent '$around' differs from source lattice incumbent '$lm->{incumbent}'\n";
    }

    my $template_name = $step->{template_config} || $step->{parent_config} || 'bt.pl';
    my $template = File::Spec->file_name_is_absolute($template_name)
        ? $template_name : File::Spec->catfile($source_dir, $template_name);
    $template = abs_path($template) || $template;
    die "derive '$to': template config not found: $template\n" unless -f $template;

    my $child_dir = _state_dir($p, $to);
    my $child_cfg = $step->{config} || "$to.pl";
    my $factor = exists($enlarge->{factor}) ? $enlarge->{factor} : 2;

    require Sim::OPT::StructureDesign;
    return Sim::OPT::StructureDesign::plan_enlarge_pan(
        template_config => $template,
        source_dir => $source_dir,
        source_counts => $lm->{global_counts},
        source_incumbent => $around,
        variables => \@vars,
        scope_factor => $factor,
        child_dir => $child_dir,
        child_config => $child_cfg,
        model_root => $step->{model_root} || $lm->{model_root} || 'bt',
        lattice_manifest => $lm_path,
    );
}


sub _reconstruct_memory_artifacts_ok {
    my (%a) = @_;
    my $s = $a{step};
    my $p = $a{procedure};
    my $old = $a{old} || {};
    if (($s->{type} || '') eq 'compare') {
        my $left = $s->{left} || return 0;
        my $dir = _state_dir($p, $left);
        my $name = $s->{output_file} || 'structuredesign-comparison.json';
        my $path = File::Spec->file_name_is_absolute($name) ? $name : File::Spec->catfile($dir, $name);
        return -f $path && -s $path ? 1 : 0;
    }
    return 1 unless ($s->{type} || '') eq 'reconstruct_memory';
    my $dir = _state_dir($p, $s->{name});
    return 0 unless -d $dir;
    my $r = ref($old->{result}) eq 'HASH' ? $old->{result} : {};
    my $mp = $r->{manifest} || File::Spec->catfile($dir, 'structuredesign-memory.json');
    return 0 unless -f $mp && -s $mp;
    my $m = eval { _read_json($mp) };
    return 0 if $@ || ref($m) ne 'HASH';
    return 0 unless ($m->{schema} || '') eq 'Sim::OPT::StructureDesign/memory-reconstruction-3';
    return 0 unless ($m->{mode} || '') eq 'shared_multistar_compressed';
    my $tot = $m->{totres};
    my $w = $m->{weightordmeta};
    return 0 unless defined($tot) && -f $tot && -s $tot;
    return 0 unless defined($w) && -f $w && -s $w;
    return 0 unless defined($m->{sampled_rows}) && defined($m->{expected_sample_rows})
        && 0 + $m->{sampled_rows} == 0 + $m->{expected_sample_rows};
    return 0 unless defined($m->{reconstructed_rows}) && defined($m->{expected_lattice_rows})
        && 0 + $m->{reconstructed_rows} == 0 + $m->{expected_lattice_rows};
    return 1;
}

sub _execute_reconstruct_memory {
    my (%a) = @_;
    my $s = $a{step};
    my $p = $a{procedure};
    my $manifest = $a{manifest};
    my $commit = $a{commit};
    my $to = $s->{name} or die "reconstruct_memory: target state name required\n";
    my $from = $s->{from} or die "reconstruct_memory '$to': from required\n";
    my $source_dir = _state_dir($p, $from);
    my $target_dir = _state_dir($p, $to);
    my $source_root = $s->{model_root} || 'bt';
    my $memory_root = $s->{memory_model_root} || 'btmed';
    die "reconstruct_memory '$to': memory_model_root must be a simple model-directory name\n"
        unless $memory_root =~ /^[A-Za-z0-9_.-]+$/;
    my $source_cfg_name = $s->{source_config} || "$from.pl";
    my $source_cfg = File::Spec->file_name_is_absolute($source_cfg_name)
        ? $source_cfg_name : File::Spec->catfile($source_dir, $source_cfg_name);
    die "reconstruct_memory '$to': source config not found: $source_cfg\n" unless -f $source_cfg;

    my $abs_ref = $s->{abstraction} or die "reconstruct_memory '$to': abstraction reference required\n";
    my $abs_path = _resolve_reference($abs_ref, $manifest);
    die "reconstruct_memory '$to': abstraction manifest not found: $abs_path\n" unless -f $abs_path;
    my $abs = _read_json($abs_path);
    die "reconstruct_memory '$to': unsupported abstraction manifest\n"
        unless ref($abs) eq 'HASH'
            && ($abs->{schema} || '') eq 'Sim::OPT::StructureDesign/abstraction-1'
            && ref($abs->{medoids}) eq 'ARRAY'
            && @{ $abs->{medoids} };

    my $vars = $s->{variables};
    $vars = $abs->{problem_variables} unless ref($vars) eq 'ARRAY' && @$vars;
    die "reconstruct_memory '$to': no problem variables available\n"
        unless ref($vars) eq 'ARRAY' && @$vars;
    my @vars = sort { $a <=> $b } map { 0 + $_ } @$vars;

    my @medoid_records = @{ $abs->{medoids} };
    if (defined $s->{medoid_limit}) {
        my $lim = 0 + $s->{medoid_limit};
        die "reconstruct_memory '$to': medoid_limit must be >= 1\n" if $lim < 1;
        @medoid_records = @medoid_records[0 .. ($lim - 1)] if @medoid_records > $lim;
    }
    my @medoids;
    for my $i (0 .. $#medoid_records) {
        my $m = $medoid_records[$i];
        die "reconstruct_memory '$to': malformed medoid record at index $i\n"
            unless ref($m) eq 'HASH' && defined($m->{instance});
        push @medoids, $m->{instance};
    }

    if (exists $s->{star_divisions}) {
        print "[StructureDesign] NOTE reconstruct_memory '$to': star_divisions is obsolete in shared multi-star mode; retained medoids themselves are the explicit starpositions.\n";
    }

    require Sim::OPT::StructureDesign;
    my $plan = Sim::OPT::StructureDesign::plan_memory_reconstruction(
        source_config => $source_cfg,
        medoids => \@medoids,
        variables => \@vars,
        child_dir => $target_dir,
        child_config => ($s->{config} || 'memory.pl'),
        memory_model_root => $memory_root,
    );

    return {
        state => $to, from => $from, operation => 'reconstruct_memory',
        mode => $plan->{mode}, abstraction => $abs_path,
        medoids => scalar(@medoids), variables => \@vars,
        expected_sample_rows => $plan->{expected_sample_rows},
        expected_lattice_rows => $plan->{expected_lattice_rows},
        source_model_root => $source_root, memory_model_root => $memory_root,
        target_dir => $target_dir, planned => 1,
    } unless $commit;

    die "reconstruct_memory '$to': refusing to overwrite existing target directory $target_dir\n"
        if -e $target_dir;

    # One canonical source root, one target workspace, one multi-star search.
    # The medoids are sampling centres, not separate root workspaces.
    my $root_model = File::Spec->catdir($source_dir, $source_root);
    die "reconstruct_memory '$to': canonical source root not found: $root_model\n"
        unless -d $root_model;

    Sim::OPT::StructureDesign::create_memory_workspace(
        plan => $plan, commit => 1, root_model_dir => $root_model,
    );
    my $run = _run_opt(
        state => $to,
        state_dir => $target_dir,
        config => $plan->{child_config},
        executable => $s->{executable}, root_dir => $p->{root_dir},
    );

    my $totres = File::Spec->catfile($target_dir, $memory_root . '-0_totres.csv');
    my $weight = File::Spec->catfile(
        $target_dir, $memory_root . '-report-0-0.csv_sortm.csv_weightordmeta.csv'
    );
    die "reconstruct_memory '$to': sampled totres missing or empty: $totres\n"
        unless -f $totres && -s $totres;
    die "reconstruct_memory '$to': reconstructed surrogate missing or empty: $weight\n"
        unless -f $weight && -s $weight;

    my $sample_rows = _count_result_rows($totres);
    my $reconstructed_rows = _count_result_rows($weight);
    die "reconstruct_memory '$to': multi-star totres has $sample_rows rows; expected exactly $plan->{expected_sample_rows} unique sampled instances\n"
        unless $sample_rows == $plan->{expected_sample_rows};
    die "reconstruct_memory '$to': surrogate reconstruction is incomplete: $reconstructed_rows rows in weightordmeta, expected full $plan->{expected_lattice_rows}-row lattice\n"
        unless $reconstructed_rows == $plan->{expected_lattice_rows};

    my @manifest_medoids;
    for my $i (0 .. $#medoid_records) {
        my $m = $medoid_records[$i];
        push @manifest_medoids, {
            medoid_index => $i + 1,
            cluster => (defined($m->{cluster}) ? 0 + $m->{cluster} : $i + 1),
            medoid => $m->{instance},
            (exists($m->{performance}) ? (performance => 0 + $m->{performance}) : ()),
        };
    }

    my $record = {
        schema => 'Sim::OPT::StructureDesign/memory-reconstruction-3',
        operation => 'reconstruct_memory',
        mode => $plan->{mode},
        state => $to,
        from_state => $from,
        source_dir => $source_dir,
        source_config => $source_cfg,
        abstraction_manifest => $abs_path,
        source_model_root => $source_root,
        model_root => $memory_root,
        variables => \@vars,
        medoid_count => scalar(@manifest_medoids),
        medoids => \@manifest_medoids,
        source_starpositions => $plan->{source_starpositions},
        starpositions => $plan->{starpositions},
        lattice_counts => $plan->{lattice_counts},
        per_variable_axes => $plan->{per_variable_axes},
        workspace => $target_dir,
        config => File::Spec->catfile($target_dir, $plan->{child_config}),
        local_manifest => File::Spec->catfile($target_dir, 'structuredesign-memory-local.json'),
        totres => $totres,
        weightordmeta => $weight,
        expected_sample_rows => 0 + $plan->{expected_sample_rows},
        sampled_rows => 0 + $sample_rows,
        expected_lattice_rows => 0 + $plan->{expected_lattice_rows},
        reconstructed_rows => 0 + $reconstructed_rows,
        exit_status => 0 + ($run->{exit_status} || 0),
    };
    my $record_path = File::Spec->catfile($target_dir, 'structuredesign-memory.json');
    _write_json($record_path, $record);
    return {
        state => $to, from => $from, operation => 'reconstruct_memory',
        mode => $plan->{mode}, medoid_count => scalar(@manifest_medoids),
        variables => \@vars, sampled_rows => $sample_rows,
        reconstructed_rows => $reconstructed_rows,
        manifest => $record_path, totres => $totres, weightordmeta => $weight,
    };
}

sub _read_prediction_scores_for_ids {
    my (%a) = @_;
    my $path = $a{path};
    my $wanted = $a{wanted};
    die "prediction reader: file not found: $path\n" unless defined($path) && -f $path;
    die "prediction reader: wanted HASH required\n" unless ref($wanted) eq 'HASH';
    my %scores;
    my $num = qr/^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[Ee][+-]?\d+)?$/;
    open my $fh, '<', $path or die "Cannot read $path: $!\n";
    while (my $line = <$fh>) {
        $line =~ s/\r?\n\z//;
        next unless length($line);
        next unless $line =~ /^((?:\d+-\d+)(?:_\d+-\d+)+),(.*)$/s;
        my ($id, $rest) = ($1, $2);
        next unless exists $wanted->{$id};
        my @f = split /,/, $rest, -1;
        my $v = $f[-1];
        die "Non-numeric prediction for '$id' in $path: '$v'\n"
            unless defined($v) && $v =~ $num;
        die "Duplicate prediction for '$id' in $path\n" if exists $scores{$id};
        $scores{$id} = 0 + $v;
    }
    close $fh;
    return \%scores;
}

sub _reference_normalization_from_rows {
    my ($rows) = @_;
    die "reference normalization: rows ARRAY required\n" unless ref($rows) eq 'ARRAY' && @$rows;
    my $first = _simopt_payload_base($rows->[0]{payload});
    my $k = $first->{objective_count};
    my @absmax = (0) x $k;
    for my $r (@$rows) {
        my $b = _simopt_payload_base($r->{payload});
        die "Reference objective count differs at '$r->{clear}'\n" unless $b->{objective_count} == $k;
        for my $i (0 .. $k - 1) {
            die "Reference objective name differs at '$r->{clear}'\n"
                unless $b->{names}[$i] eq $first->{names}[$i];
            my $av = abs($b->{raw}[$i]);
            $absmax[$i] = $av if $av > $absmax[$i];
        }
    }
    return { names => [ @{$first->{names}} ], absmaxes => \@absmax, objective_count => $k };
}

sub _payload_score_on_reference_scale {
    my (%a) = @_;
    my $b = _simopt_payload_base($a{payload});
    my $reference = $a{reference};
    my $weights = $a{weights};
    die "payload score: reference HASH required\n" unless ref($reference) eq 'HASH';
    die "payload score: weights ARRAY required\n" unless ref($weights) eq 'ARRAY';
    my $k = $reference->{objective_count};
    die "payload score: objective count mismatch\n" unless $b->{objective_count} == $k && @$weights == $k;
    my $score = 0;
    for my $i (0 .. $k - 1) {
        die "payload score: objective name mismatch '$b->{names}[$i]' vs '$reference->{names}[$i]'\n"
            unless $b->{names}[$i] eq $reference->{names}[$i];
        my $den = $reference->{absmaxes}[$i];
        next unless $den;
        $score += ($b->{raw}[$i] / $den) * abs($weights->[$i]);
    }
    return $score;
}

sub _regression_metrics {
    my ($pairs) = @_;
    die "regression metrics: pairs ARRAY required\n" unless ref($pairs) eq 'ARRAY' && @$pairs;
    my $n = scalar(@$pairs);
    my ($sum_err, $sum_abs, $sum_sq, $max_abs, $sum_y) = (0,0,0,0,0);
    for my $p (@$pairs) {
        my $e = $p->{predicted} - $p->{actual};
        my $ae = abs($e);
        $sum_err += $e;
        $sum_abs += $ae;
        $sum_sq += $e * $e;
        $max_abs = $ae if $ae > $max_abs;
        $sum_y += $p->{actual};
    }
    my $mean_y = $sum_y / $n;
    my $sst = 0;
    for my $p (@$pairs) {
        my $d = $p->{actual} - $mean_y;
        $sst += $d * $d;
    }
    return {
        n => $n,
        mean_signed_error => $sum_err / $n,
        mae => $sum_abs / $n,
        rmse => sqrt($sum_sq / $n),
        max_absolute_error => $max_abs,
        r_squared => $sst > 0 ? 1 - ($sum_sq / $sst) : undef,
    };
}

sub _execute_compare {
    my (%a) = @_;
    my $s = $a{step};
    my $p = $a{procedure};
    my $commit = $a{commit};
    my $left = $s->{left} or die "compare: left state required\n";
    my $right = $s->{right} or die "compare: right state required\n";
    my $root = $s->{model_root} || 'bt';
    my $left_dir = _state_dir($p, $left);
    my $right_dir = _state_dir($p, $right);
    die "compare: left state directory not found: $left_dir\n" unless -d $left_dir;
    die "compare: right state directory not found: $right_dir\n" unless -d $right_dir;
    my $left_tot = File::Spec->catfile($left_dir, $s->{left_results_file} || ($root . '-0_totres.csv'));
    my $right_tot = File::Spec->catfile($right_dir, $s->{right_results_file} || ($root . '-0_totres.csv'));
    my $identity = sub { $_[0] };
    my $lr = _read_totres_rows(source => $left_tot, mapper => $identity, label => $left);
    my $rr = _read_totres_rows(source => $right_tot, mapper => $identity, label => $right);

    if (defined $s->{expected_left_rows}) {
        die "compare '$left/$right': expected $s->{expected_left_rows} left rows but found " . scalar(@$lr) . "\n"
            unless @$lr == 0 + $s->{expected_left_rows};
    }
    if (defined $s->{expected_right_rows}) {
        die "compare '$left/$right': expected $s->{expected_right_rows} right rows but found " . scalar(@$rr) . "\n"
            unless @$rr == 0 + $s->{expected_right_rows};
    }

    my (%L, %R);
    $L{$_->{clear}} = $_ for @$lr;
    $R{$_->{clear}} = $_ for @$rr;
    my @overlap = grep { exists $R{$_} } keys %L;
    my @holdout = grep { !exists $L{$_} } keys %R;
    if (defined $s->{expected_overlap_rows}) {
        die "compare '$left/$right': expected $s->{expected_overlap_rows} overlap rows but found " . scalar(@overlap) . "\n"
            unless @overlap == 0 + $s->{expected_overlap_rows};
    }
    if (defined $s->{expected_holdout_rows}) {
        die "compare '$left/$right': expected $s->{expected_holdout_rows} holdout rows but found " . scalar(@holdout) . "\n"
            unless @holdout == 0 + $s->{expected_holdout_rows};
    }
    my $tol = exists($s->{overlap_tolerance}) ? 0 + $s->{overlap_tolerance} : 1e-9;
    for my $id (@overlap) {
        die "compare '$left/$right': shared physical result differs at '$id'\n"
            unless _result_payloads_compatible($L{$id}{payload}, $R{$id}{payload}, $tol);
    }

    my $prediction_state = $s->{prediction_state} || $left;
    my $pred_dir = _state_dir($p, $prediction_state);
    my $prediction_name = $s->{prediction_file}
        or die "compare '$left/$right': prediction_file required\n";
    my $prediction_path = File::Spec->file_name_is_absolute($prediction_name)
        ? $prediction_name : File::Spec->catfile($pred_dir, $prediction_name);
    my %wanted = map { $_ => 1 } @holdout;
    my $pred = _read_prediction_scores_for_ids(path => $prediction_path, wanted => \%wanted);
    my @missing = grep { !exists $pred->{$_} } @holdout;
    die "compare '$left/$right': prediction file lacks " . scalar(@missing) . " holdout instances; first missing '$missing[0]'\n"
        if @missing;

    my $reference = _reference_normalization_from_rows($lr);
    my $left_cfg = File::Spec->catfile($left_dir, $s->{left_config} || ($left . '.pl'));
    my $weights = ref($s->{weights}) eq 'ARRAY'
        ? [ @{$s->{weights}} ]
        : _weights_from_config($left_cfg, $reference->{objective_count});
    my @pairs;
    for my $id (sort @holdout) {
        my $actual = _payload_score_on_reference_scale(
            payload => $R{$id}{payload}, reference => $reference, weights => $weights,
        );
        push @pairs, { instance => $id, predicted => $pred->{$id}, actual => $actual };
    }
    my $metrics = _regression_metrics(\@pairs);
    my $output_name = $s->{output_file} || 'structuredesign-comparison.json';
    my $output = File::Spec->file_name_is_absolute($output_name)
        ? $output_name : File::Spec->catfile($left_dir, $output_name);
    my $record = {
        schema => 'Sim::OPT::StructureDesign/comparison-1',
        operation => 'compare',
        left_state => $left,
        right_state => $right,
        left_results => $left_tot,
        right_results => $right_tot,
        prediction_state => $prediction_state,
        prediction_file => $prediction_path,
        left_rows => scalar(@$lr),
        right_rows => scalar(@$rr),
        overlap_rows => scalar(@overlap),
        holdout_rows => scalar(@holdout),
        overlap_tolerance => $tol,
        shared_physical_results_agree => JSON::PP::true,
        score_reference => {
            state => $left,
            objective_names => $reference->{names},
            absmaxes => $reference->{absmaxes},
            weights => $weights,
        },
        metrics => $metrics,
        threshold_applied => JSON::PP::false,
    };
    _write_json($output, $record) if $commit;
    return { %$record, output => $output };
}

sub _execute_step {
    my (%a) = @_;
    my $s = $a{step};
    my $p = $a{procedure};
    my $manifest = $a{manifest};
    my $commit = $a{commit};
    my $type = $s->{type} || '';

    if ($type eq 'state') {
        my $name = $s->{name} or die "state: name required\n";
        my $dir = _state_dir($p, $name);
        my $cfg_name = $s->{config} || "$name.pl";
        my $cfg = File::Spec->catfile($dir, $cfg_name);
        if ($s->{existing}) {
            die "Existing state directory not found: $dir\n" unless -d $dir;
            die "Existing state config not found: $cfg\n" unless -f $cfg;
            return { state => $name, state_dir => $dir, config => $cfg_name };
        }

        if (defined($s->{from}) && length($s->{from})) {
            my $from = $s->{from};
            my $source_dir = _state_dir($p, $from);
            my $source_cfg_name = $s->{source_config} || "$from.pl";
            my $source_cfg = File::Spec->catfile($source_dir, $source_cfg_name);
            my $root = $s->{model_root} || 'bt';
            my $source_model = File::Spec->catdir($source_dir, $root);
            return {
                state => $name, state_dir => $dir, config => $cfg_name,
                from => $from, source_config => $source_cfg_name, planned => 1,
            } unless $commit;

            die "state '$name': source state directory not found: $source_dir\n" unless -d $source_dir;
            die "state '$name': source config not found: $source_cfg\n" unless -f $source_cfg;
            die "state '$name': source root model not found: $source_model\n" unless -d $source_model;
            die "state '$name': refusing to overwrite existing target directory $dir\n" if -e $dir;

            my $source_geometry_manifest;
            my $target_geometry_manifest;
            if (defined($s->{geometry_manifest}) && length($s->{geometry_manifest})) {
                $source_geometry_manifest = File::Spec->file_name_is_absolute($s->{geometry_manifest})
                    ? $s->{geometry_manifest}
                    : File::Spec->catfile($source_dir, $s->{geometry_manifest});
                die "state '$name': source geometry manifest not found: $source_geometry_manifest\n"
                    unless -f $source_geometry_manifest;
                my $target_geometry_name = $s->{target_geometry_manifest}
                    || basename($s->{geometry_manifest});
                $target_geometry_manifest = File::Spec->catfile($dir, $target_geometry_name);
            }

            # Preflight the entire state contract before creating the target
            # directory.  A stale/corrupt source geometry must not leave a
            # half-created sibling state behind.
            my $variant = $s->{config_variant} || {};
            my $preview = _render_config_variant(
                source => $source_cfg, mypath => $dir, variant => $variant,
            );
            _validate_config_variant_text($preview, $variant);
            if (defined $source_geometry_manifest) {
                my $plan = _read_json($source_geometry_manifest);
                require Sim::OPT::StructureDesign;
                my $source_text = _read_text_file($source_cfg);
                Sim::OPT::StructureDesign::validate_enlarge_pan_config_text(
                    $source_text, $plan, target_dir => $source_dir,
                );
                Sim::OPT::StructureDesign::validate_enlarge_pan_config_text(
                    $preview, $plan, target_dir => $dir,
                );
            }

            make_path($dir);
            _copy_tree_exact($source_model, File::Spec->catdir($dir, $root));
            _write_text_file($cfg, $preview);
            if (defined $source_geometry_manifest) {
                _materialize_cloned_scope_manifest(
                    source => $source_geometry_manifest,
                    target => $target_geometry_manifest,
                    source_config => $source_cfg,
                    target_config => $cfg,
                    source_dir => $source_dir,
                    target_dir => $dir,
                );
            }
            return {
                state => $name, state_dir => $dir, config => $cfg_name,
                from => $from, generated => 1,
                (defined($target_geometry_manifest) ? (geometry_manifest => $target_geometry_manifest) : ()),
            };
        }

        return { state => $name, state_dir => $dir, config => $cfg_name };
    }

    if ($type eq 'experience') {
        my $state = $s->{name} || $s->{state} or die "experience: state required\n";
        my $using = $s->{using} || search();
        my $kind = $using->{kind} || 'search';
        die "experience '$state': '$kind' is represented by the procedure language, but its config compiler is not yet installed; this guard prevents silently running the wrong acquisition method\n"
            unless $kind eq 'search' || $kind eq 'star';

        my $dir = _state_dir($p, $state);
        my $cfg;
        my $star_plan;
        if ($kind eq 'star') {
            $star_plan = _compile_star_experience(step => $s, procedure => $p, commit => $commit);
            return {
                state => $state,
                planned => 1,
                acquisition => 'star',
                divisions => $star_plan->{divisions},
                variables => $star_plan->{variables},
                expected_result_rows => $star_plan->{expected_result_rows},
                acquisition_config => $star_plan->{acquisition_config},
            } unless $commit;
            $cfg = basename($star_plan->{acquisition_config});
        } else {
            return { state => $state, planned => 1, acquisition => $kind } unless $commit;
            $cfg = $s->{config} || "$state.pl";
            if (defined($s->{config_from}) && length($s->{config_from})) {
                my $source_cfg = File::Spec->file_name_is_absolute($s->{config_from})
                    ? $s->{config_from} : File::Spec->catfile($dir, $s->{config_from});
                my $geometry_manifest;
                if (defined($s->{geometry_manifest}) && length($s->{geometry_manifest})) {
                    $geometry_manifest = File::Spec->file_name_is_absolute($s->{geometry_manifest})
                        ? $s->{geometry_manifest}
                        : File::Spec->catfile($dir, $s->{geometry_manifest});
                }
                _materialize_config_variant(
                    source => $source_cfg,
                    target => File::Spec->catfile($dir, $cfg),
                    mypath => $dir,
                    variant => $s->{config_variant} || {},
                    geometry_manifest => $geometry_manifest,
                );
            }
        }

        my $r = _run_opt(state => $state, state_dir => $dir, config => $cfg, executable => $s->{executable}, root_dir => $p->{root_dir});
        my $root = $s->{model_root} || 'bt';
        my $winner = _detect_winner(state_dir => $dir, model_root => $root);
        die "OPT completed for '$state', but StructureDesign could not determine the final clear incumbent automatically. response.txt or a winner-labelled tofile entry is required before the next incumbent-dependent operation.\n"
            unless defined $winner;

        if ($kind eq 'star') {
            my $results = File::Spec->catfile($dir, $root . '-0_totres.csv');
            my $rows = _count_result_rows($results);
            die "star experience '$state': expected $star_plan->{expected_result_rows} result rows but found $rows in $results\n"
                unless $rows == $star_plan->{expected_result_rows};
            my $record = {
                %$star_plan,
                result_rows => 0 + $rows,
                results_file => $results,
                incumbent => $winner,
            };
            my $record_path = File::Spec->catfile($dir, 'structuredesign-star.json');
            _write_json($record_path, $record);
            return {
                %$r,
                state => $state,
                acquisition => 'star',
                divisions => $star_plan->{divisions},
                variables => $star_plan->{variables},
                expected_result_rows => $star_plan->{expected_result_rows},
                result_rows => 0 + $rows,
                results_file => $results,
                acquisition_config => $star_plan->{acquisition_config},
                manifest => $record_path,
                incumbent => $winner,
            };
        }

        my $results_path = File::Spec->catfile($dir, $root . '-0_totres.csv');
        my %post;

        if (exists $s->{expected_result_rows}) {
            my $expected = 0 + $s->{expected_result_rows};
            my $rows = _count_result_rows($results_path);
            die "experience '$state': expected $expected result rows but found $rows in $results_path\n"
                unless $rows == $expected;
            $post{expected_result_rows} = $expected;
            $post{result_rows} = 0 + $rows;
            $post{results_file} = $results_path;
        }

        if (ref($s->{required_output_files}) eq 'ARRAY') {
            my @checked;
            for my $name (@{ $s->{required_output_files} }) {
                die "experience '$state': required output filename must be scalar\n" if ref($name);
                my $path = File::Spec->file_name_is_absolute($name)
                    ? $name : File::Spec->catfile($dir, $name);
                die "experience '$state': required output missing or empty: $path\n"
                    unless -f $path && -s $path;
                push @checked, $path;
            }
            $post{required_output_files} = \@checked;
        }

        # Plain numeric search sweeps are automatically guarded as complete
        # factorial searches. This protects btr and btra without changing their
        # already-completed procedure-step signatures in an existing manifest.
        my $factorial_vars = exists($s->{expected_full_factorial})
            ? $s->{expected_full_factorial}
            : _plain_full_factorial_variables(File::Spec->catfile($dir, $cfg));
        if (defined $factorial_vars) {
            die "experience '$state': expected_full_factorial must be a non-empty ARRAY reference\n"
                unless ref($factorial_vars) eq 'ARRAY' && @$factorial_vars;
            my ($counts, $count_source, $lm_path);
            if (defined($s->{lattice_manifest}) && length($s->{lattice_manifest})) {
                my $lm_name = $s->{lattice_manifest};
                $lm_path = File::Spec->file_name_is_absolute($lm_name)
                    ? $lm_name : File::Spec->catfile($dir, $lm_name);
                die "experience '$state': lattice manifest not found: $lm_path\n" unless -f $lm_path;
                my $lm = _read_json($lm_path);
                $counts = $lm->{target_counts} || $lm->{global_counts};
                die "experience '$state': lattice manifest has no target_counts or global_counts\n"
                    unless ref($counts) eq 'HASH' && keys %$counts;
                $count_source = $lm_path;
            } else {
                require Sim::OPT::StructureDesign;
                my $cfg_path = File::Spec->catfile($dir, $cfg);
                my $ci = Sim::OPT::StructureDesign::inspect_config($cfg_path);
                $counts = $ci->{varinumbers};
                $count_source = $cfg_path;
            }
            my ($expected, $rows) = _validate_expected_factorial(
                state => $state, variables => $factorial_vars,
                counts => $counts, results => $results_path,
            );
            $post{expected_result_rows} = 0 + $expected;
            $post{result_rows} = 0 + $rows;
            $post{results_file} = $results_path;
            $post{factorial_count_source} = $count_source;
            $post{full_factorial_variables} = [ map { 0 + $_ } @$factorial_vars ];
            $post{lattice_manifest} = $lm_path if defined $lm_path;
        }

        return { %$r, state => $state, acquisition => $kind, incumbent => $winner, %post };
    }

    if ($type eq 'derive') {
        my %ops = map { (($_->{op} || '') => 1) } @{ $s->{by} || [] };
        my $plan;
        if ($ops{reduce_scope}) {
            $plan = _compile_zoom(step => $s, procedure => $p, manifest => $manifest);
        } elsif ($ops{enlarge_scope}) {
            $plan = _compile_enlarge_pan(step => $s, procedure => $p, manifest => $manifest);
        } else {
            die "derive '$s->{name}': no installed structural executor matches requested operators\n";
        }
        return { state => $s->{name}, operation => $plan->{operation}, plan => $plan } unless $commit;
        require Sim::OPT::StructureDesign;
        if (($plan->{operation} || '') eq 'zoom_in') {
            Sim::OPT::StructureDesign::create_zoom_workspace(plan => $plan, commit => 1);
            return {
                state => $s->{name},
                operation => 'reduce_scope+increase_resolution',
                incumbent_parent => $plan->{incumbent_parent},
                incumbent_refined => $plan->{incumbent_refined},
                manifest => File::Spec->catfile($plan->{child_dir}, 'structuredesign-zoom.json'),
            };
        }
        if (($plan->{operation} || '') eq 'enlarge_scope+maintain_resolution+pan') {
            Sim::OPT::StructureDesign::create_enlarge_pan_workspace(plan => $plan, commit => 1);
            return {
                state => $s->{name},
                operation => $plan->{operation},
                incumbent_source => $plan->{source_incumbent},
                incumbent_target => $plan->{target_incumbent},
                target_counts => $plan->{target_counts},
                manifest => File::Spec->catfile($plan->{child_dir}, 'structuredesign-scope.json'),
            };
        }
        die "derive '$s->{name}': compiled unsupported operation '$plan->{operation}'\n";
    }

    if ($type eq 'reembed') {
        return _execute_reembed(step => $s, procedure => $p, manifest => $manifest, commit => $commit);
    }
    if ($type eq 'merge') {
        return _execute_merge(step => $s, procedure => $p, manifest => $manifest, commit => $commit);
    }
    if ($type eq 'imagine') {
        my $method = (ref($s->{using}) eq 'HASH' && defined($s->{using}{method})) ? $s->{using}{method} : 'unspecified surrogate';
        die "Procedure operator 'imagine by surrogating with $method' is defined, but star/surrogate config compilation is not yet installed in the procedure runtime. Refusing to claim that a surrogate was generated.\n";
    }
    if ($type eq 'reconstruct_memory') {
        return _execute_reconstruct_memory(step => $s, procedure => $p, manifest => $manifest, commit => $commit);
    }
    if ($type eq 'abstract') {
        return _execute_abstract(step => $s, procedure => $p, manifest => $manifest, commit => $commit);
    }
    if ($type eq 'compare') {
        return _execute_compare(step => $s, procedure => $p, manifest => $manifest, commit => $commit);
    }

    die "Unknown procedure step type '$type'\n";
}

sub run_procedure {
    my ($p, %opts) = @_;
    die "run_procedure: procedure HASH required\n" unless ref($p) eq 'HASH';
    my $commit = $opts{commit} ? 1 : 0;
    my $manifest_path = _manifest_path($p);
    my $manifest = _prepare_manifest(
        procedure => $p,
        manifest_path => $manifest_path,
        commit => $commit,
        from => $opts{from},
        only => $opts{only},
        accept_runtime_change => $opts{accept_runtime_change},
        accept_tail_change => $opts{accept_tail_change},
    );

    my $from_seen = !$opts{from};
    my $i = 0;
    for my $s (@{ $p->{steps} || [] }) {
        my $sid = _step_id($s, $i++);
        next unless $s->{enabled};
        if (!$from_seen) {
            if ($sid eq $opts{from}) {
                $from_seen = 1;
            } else {
                if ($commit) {
                    my $sig = _step_signature($s);
                    my $old = $manifest->{steps}{$sid};
                    die "Cannot resume --from '$opts{from}': prerequisite step '$sid' is not COMPLETE in the run manifest\n"
                        unless $old && ($old->{status} || '') eq 'COMPLETE';
                    die "Cannot resume --from '$opts{from}': prerequisite step '$sid' changed since it completed; rerun from '$sid' or earlier\n"
                        unless ($old->{signature} || '') eq $sig;
                    die "Cannot resume --from '$opts{from}': prerequisite step '$sid' is marked COMPLETE but its required output artifacts are missing; rerun from '$sid' or earlier\n"
                        unless _reconstruct_memory_artifacts_ok(step => $s, procedure => $p, old => $old);
                }
                next;
            }
        }
        next if $opts{only} && $sid ne $opts{only};

        my $sig = _step_signature($s);
        my $old = $manifest->{steps}{$sid};
        if ($commit && $old && ($old->{status} || '') eq 'COMPLETE' && ($old->{signature} || '') eq $sig && !$opts{force}) {
            if (_reconstruct_memory_artifacts_ok(step => $s, procedure => $p, old => $old)) {
                print "[StructureDesign] SKIP complete $sid\n";
                next;
            }
            print "[StructureDesign] REBUILD $sid: checkpoint is COMPLETE but required output artifacts are missing\n";
        }
        if ($commit && $old && ($old->{status} || '') eq 'COMPLETE' && ($old->{signature} || '') ne $sig && !$opts{force}) {
            if ($opts{accept_tail_change} && $opts{from}) {
                print "[StructureDesign] REBUILD changed tail step $sid under --accept-tail-change\n";
            } else {
                die "Step '$sid' changed since its completed execution. Refusing to reuse stale state; rerun with --force only after deciding how existing filesystem state should be handled.\n";
            }
        }

        print "[StructureDesign] " . ($commit ? 'RUN' : 'PLAN') . " $sid ($s->{type})\n";
        if (!$commit) {
            # A procedure dry run validates the graph and reports intent; it must not
            # require results (incumbents) or committed executors for later states.
            if ($s->{type} eq 'derive') {
                my @ops = map { $_->{op} || '?' } @{ $s->{by} || [] };
                print "  target=$s->{name} from=$s->{from}; operators=" . join('+', @ops) . "; detailed lattice plan deferred until execution inputs are available\n";
                next;
            }
            if ($s->{type} eq 'experience') {
                my $kind = ref($s->{using}) eq 'HASH' ? ($s->{using}{kind} || 'search') : 'search';
                print "  state=$s->{name}; acquisition=$kind; execution deferred\n";
                next;
            }
            if ($s->{type} eq 'imagine') {
                my $method = ref($s->{using}) eq 'HASH' ? ($s->{using}{method} || '?') : '?';
                print "  state=$s->{name}; imagine by surrogating with $method; execution deferred\n";
                next;
            }
            if ($s->{type} eq 'abstract') {
                my $rel = $s->{output_dir} || 'abstract';
                my $out = File::Spec->catdir(_state_dir($p, $s->{name}), $rel);
                print "  state=$s->{name}; abstract by clustering and finding medoids; outputs=$out; execution deferred\n";
                next;
            }
            if ($s->{type} eq 'reconstruct_memory') {
                my $vars = ref($s->{variables}) eq 'ARRAY' ? join(',', @{ $s->{variables} }) : 'from-abstraction';
                print "  state=$s->{name}; reconstruct memory from=$s->{from}; variables=$vars; retained medoids become explicit centres in one shared multi-star Sim::OPT workspace; one totres and one surrogate output\n";
                next;
            }
            if ($s->{type} =~ /^(?:reembed|merge|compare)$/) {
                print "  declared high-level operator; executor availability is checked at commit time\n";
                next;
            }
        }

        $manifest->{steps}{$sid} = {
            status => 'RUNNING', signature => $sig, started_at => _now(),
            type => $s->{type}, name => $s->{name},
        } if $commit;
        _write_json($manifest_path, $manifest) if $commit;

        my $result;
        my $ok = eval {
            $result = _execute_step(step => $s, procedure => $p, manifest => $manifest, commit => $commit);
            1;
        };
        if (!$ok) {
            my $err = $@ || 'unknown error';
            if ($commit) {
                $manifest->{steps}{$sid}{status} = 'FAILED';
                $manifest->{steps}{$sid}{failed_at} = _now();
                $manifest->{steps}{$sid}{error} = "$err";
                _write_json($manifest_path, $manifest);
            }
            die $err;
        }
        if ($commit) {
            $manifest->{steps}{$sid}{status} = 'COMPLETE';
            $manifest->{steps}{$sid}{completed_at} = _now();
            $manifest->{steps}{$sid}{result} = $result || {};
            _write_json($manifest_path, $manifest);
        }
        print "[StructureDesign] DONE $sid\n" if $commit;
    }

    die "Requested --from step '$opts{from}' was not found in the enabled procedure\n"
        if $opts{from} && !$from_seen;
    print $commit
        ? "[StructureDesign] procedure reached the end of all currently executable enabled steps. Manifest: $manifest_path\n"
        : "[StructureDesign] dry plan complete; nothing was executed. Manifest would be: $manifest_path\n";
    return $manifest;
}

1;

__END__

=head1 NAME

Sim::OPT::StructureDesignProcedure - executable high-level procedure language for design operations

=head1 PURPOSE

The procedure language separates the description of a design process from the
implementation of individual operators. Case-study order, state names, branch
choices and acquisition/inference choices belong in a procedure file; filesystem
rewrites and Sim::OPT calls belong in installed modules.  Article-facing inference
uses the phrase 'imagine by surrogating with ...'; representation uses 'abstract by
clustering and finding medoids'.  Abstraction products are scoped to the directory of the
state being abstracted.

=cut
