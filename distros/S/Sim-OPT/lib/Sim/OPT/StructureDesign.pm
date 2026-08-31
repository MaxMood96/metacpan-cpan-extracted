package Sim::OPT::StructureDesign;

use strict;
use warnings;
use Exporter 'import';
use File::Basename qw(dirname basename);
use File::Path qw(make_path);
use File::Copy qw(copy);
use File::Find qw(find);
use JSON::PP ();

our $VERSION = '0.05';
our @EXPORT_OK = qw(
    parse_instance format_instance
    refined_level_count rescale_level rescale_instance
    inspect_config plan_zoom_in render_zoom_config
    memory_level_count plan_memory_reconstruction render_memory_config create_memory_workspace
    plan_enlarge_pan render_enlarge_pan_config validate_enlarge_pan_config_text
    write_manifest create_zoom_workspace create_enlarge_pan_workspace
    map_local_instance_to_global
    rewrite_clear_instances_in_text
    resolve_incumbent_model
    render_refined_parent_config validate_refined_parent_config_text
    render_cloned_state_config validate_cloned_state_config_text
    plan_zoom_out_merge scan_max_short_id
);

# -------------------------------------------------------------------------
# Pure lattice/name functions
# -------------------------------------------------------------------------

sub parse_instance {
    my ($s) = @_;
    die "parse_instance: undefined instance\n" unless defined $s;

    my %h;
    while ($s =~ /(?:^|_)(\d+)-(\d+)(?=_|$)/g) {
        $h{0 + $1} = 0 + $2;
    }
    die "parse_instance: no variable-level pairs in '$s'\n" unless keys %h;
    return \%h;
}

sub format_instance {
    my ($h) = @_;
    die "format_instance: HASH reference required\n" unless ref($h) eq 'HASH';
    return join('_', map { $_ . '-' . $h->{$_} } sort { $a <=> $b } keys %$h);
}

sub refined_level_count {
    my ($n, $factor) = @_;
    $factor = 2 unless defined $factor;
    die "refined_level_count: n must be >= 1\n" unless defined($n) && $n >= 1;
    die "refined_level_count: factor must be a positive integer\n"
        unless $factor =~ /^\d+$/ && $factor >= 1;
    return 1 + $factor * ($n - 1);
}

sub rescale_level {
    my ($level, $factor) = @_;
    $factor = 2 unless defined $factor;
    die "rescale_level: level must be >= 1\n" unless defined($level) && $level >= 1;
    return 1 + $factor * ($level - 1);
}

sub rescale_instance {
    my ($s, $factor, $vars) = @_;
    $factor = 2 unless defined $factor;
    my $h = parse_instance($s);
    my %wanted = $vars ? map { $_ => 1 } @$vars : map { $_ => 1 } keys %$h;
    my %out = %$h;
    for my $v (keys %out) {
        $out{$v} = rescale_level($out{$v}, $factor) if $wanted{$v};
    }
    return format_instance(\%out);
}

# -------------------------------------------------------------------------
# Conservative parser for the subset of a Sim::OPT config needed here.
# It does not execute the configuration file.
# -------------------------------------------------------------------------

sub _slurp {
    my ($path) = @_;
    open my $fh, '<', $path or die "Cannot read $path: $!\n";
    local $/;
    my $txt = <$fh>;
    close $fh;
    return $txt;
}

sub _spit {
    my ($path, $txt) = @_;
    open my $fh, '>', $path or die "Cannot write $path: $!\n";
    print {$fh} $txt;
    close $fh or die "Cannot close $path: $!\n";
}

sub _parse_hash_assignment {
    my ($txt, $name) = @_;
    my ($body) = $txt =~ /^\s*\Q$name\E\s*=\s*\(\s*\{(.*?)\}\s*\)\s*;/ms;
    die "Cannot parse $name from config\n" unless defined $body;
    my %h;
    while ($body =~ /(\d+)\s*=>\s*([+-]?(?:\d+(?:\.\d*)?|\.\d+))/g) {
        $h{0 + $1} = 0 + $2;
    }
    die "No entries parsed from $name\n" unless keys %h;
    return \%h;
}

sub _parse_active_sweeps {
    my ($txt) = @_;
    my ($line) = $txt =~ /^(?!\s*#)\s*\@sweeps\s*=\s*([^;]+);/m;
    die "Cannot find active \@sweeps assignment\n" unless defined $line;
    my @vars = map { 0 + $_ } ($line =~ /\b(\d+)\b/g);
    return \@vars;
}

sub _num_list {
    my ($s) = @_;
    my @n = map { 0 + $_ } ($s =~ /["']?([+-]?(?:\d+(?:\.\d*)?|\.\d+))["']?/g);
    return \@n;
}

sub _extract_operation {
    my ($txt, $v) = @_;
    my ($apply) = $txt =~ /\$vals\{1\}\{\Q$v\E\}\{applytype\}\s*=\s*(\[.*?\])\s*;/ms;
    die "Variable $v has no parseable applytype\n" unless defined $apply;
    my ($type) = $apply =~ /\[\s*["']([^"']+)["']/;
    die "Cannot identify operation type for variable $v\n" unless defined $type;

    if ($type eq 'rotate') {
        my ($block) = $txt =~ /\$vals\{1\}\{\Q$v\E\}\{rotate\}\s*=\s*\[(.*?)\]\s*;/ms;
        die "Cannot parse rotate block for variable $v\n" unless defined $block;
        my ($arg) = $block =~ /\[\s*["'][^"']*["']\s*,\s*(\[[^\]]+\]|["']?[+-]?(?:\d+(?:\.\d*)?|\.\d+)["']?)/s;
        die "Cannot parse rotate interval for variable $v\n" unless defined $arg;
        my ($begin, $end);
        if ($arg =~ /^\s*\[/) {
            my $n = _num_list($arg);
            die "rotate endpoints need two numbers for variable $v\n" unless @$n >= 2;
            ($begin, $end) = @$n[0,1];
        } else {
            $arg =~ s/["']//g;
            my $h = 0 + $arg;
            ($begin, $end) = (-$h, $h);
        }
        return { type => 'rotate', begin => [$begin], end => [$end] };
    }

    if ($type eq 'translate') {
        my ($block) = $txt =~ /\$vals\{1\}\{\Q$v\E\}\{translate\}\s*=\s*\[(.*?)\]\s*;/ms;
        die "Cannot parse translate block for variable $v\n" unless defined $block;
        my ($arg) = $block =~ /\[\s*["'][^"']*["']\s*,\s*(\[.*?\])\s*,\s*["']/s;
        die "Cannot parse translate coordinates for variable $v\n" unless defined $arg;

        # explicit endpoints: [[x,y,z],[x,y,z]]
        if ($arg =~ /^\s*\[\s*\[/) {
            my @inner = $arg =~ /\[([^\[\]]+)\]/g;
            die "translate endpoints need two vectors for variable $v\n" unless @inner >= 2;
            my $a = _num_list($inner[0]);
            my $b = _num_list($inner[1]);
            die "translate vectors must have three components for variable $v\n" unless @$a >= 3 && @$b >= 3;
            return { type => 'translate', begin => [@$a[0..2]], end => [@$b[0..2]] };
        }
        my $h = _num_list($arg);
        die "translate swing must have three components for variable $v\n" unless @$h >= 3;
        return {
            type  => 'translate',
            begin => [ @$h[0..2] ],
            end   => [ map { -$_ } @$h[0..2] ],
        };
    }

    if ($type eq 'obs_modify') {
        my ($block) = $txt =~ /\$vals\{1\}\{\Q$v\E\}\{obs_modify\}\s*=\s*\[(.*?)\]\s*;/ms;
        die "Cannot parse obs_modify block for variable $v\n" unless defined $block;
        my ($mode) = $block =~ /\]\s*,\s*["']([^"']+)["']\s*,/s;
        die "Cannot parse obs_modify mode for variable $v\n" unless defined $mode;
        die "StructureDesign v$VERSION currently supports vector obs_modify modes a/b only (variable $v uses '$mode')\n"
            unless $mode eq 'a' || $mode eq 'b';
        my ($arg) = $block =~ /\]\s*,\s*["'][^"']+["']\s*,\s*(\[.*\])\s*\]/s;
        die "Cannot parse obs_modify values for variable $v\n" unless defined $arg;

        if ($arg =~ /^\s*\[\s*\[/) {
            my @inner = $arg =~ /\[([^\[\]]+)\]/g;
            die "obs_modify endpoints need two vectors for variable $v\n" unless @inner >= 2;
            my $a = _num_list($inner[0]);
            my $b = _num_list($inner[1]);
            die "obs_modify vectors must have three components for variable $v\n" unless @$a >= 3 && @$b >= 3;
            return { type => 'obs_modify', mode => $mode, begin => [@$a[0..2]], end => [@$b[0..2]] };
        }
        my $h = _num_list($arg);
        die "obs_modify swing must have three components for variable $v\n" unless @$h >= 3;
        return {
            type  => 'obs_modify', mode => $mode,
            begin => [ @$h[0..2] ],
            end   => [ map { -$_ } @$h[0..2] ],
        };
    }

    die "StructureDesign v$VERSION does not yet know how to zoom operation '$type' for variable $v\n";
}

sub inspect_config {
    my ($path) = @_;
    my $txt = _slurp($path);
    my ($mypath) = $txt =~ /^(?!\s*#)\s*\$mypath\s*=\s*["']([^"']+)["']/m;
    my ($file)   = $txt =~ /^(?!\s*#)\s*\$file\s*=\s*["']([^"']+)["']/m;
    die "Cannot parse \$mypath from $path\n" unless defined $mypath;
    die "Cannot parse \$file from $path\n" unless defined $file;

    return {
        path        => $path,
        text        => $txt,
        mypath      => $mypath,
        file        => $file,
        sweeps      => _parse_active_sweeps($txt),
        varinumbers => _parse_hash_assignment($txt, '@varinumbers'),
        mediumiters => _parse_hash_assignment($txt, '@mediumiters'),
    };
}

sub _clamp {
    my ($x, $lo, $hi) = @_;
    return $lo if $x < $lo;
    return $hi if $x > $hi;
    return $x;
}

sub _interp_vec {
    my ($a, $b, $pos, $last) = @_;
    return [ @$a ] if $last == 0;
    my @out;
    for my $i (0 .. $#$a) {
        push @out, $a->[$i] + ($b->[$i] - $a->[$i]) * $pos / $last;
    }
    return \@out;
}

sub _vec_sub {
    my ($a, $b) = @_;
    return [ map { $a->[$_] - $b->[$_] } 0 .. $#$a ];
}

sub plan_zoom_in {
    my (%a) = @_;
    my $parent_config = $a{parent_config} or die "plan_zoom_in: parent_config required\n";
    my $incumbent     = $a{incumbent}     or die "plan_zoom_in: incumbent required\n";
    my $variables     = $a{variables} || [1,2,3,4,5];
    my $factor_default = defined($a{resolution_factor}) ? $a{resolution_factor} : 2;
    my $factor_map     = $a{resolution_factors};
    die "resolution_factors must be a HASH reference\n"
        if defined($factor_map) && ref($factor_map) ne 'HASH';
    my $local_levels_arg = defined($a{local_levels}) ? $a{local_levels} : 3;
    die "local_levels must be a scalar or HASH reference\n"
        if ref($local_levels_arg) && ref($local_levels_arg) ne 'HASH';
    my $local_stride_arg = defined($a{local_strides}) ? $a{local_strides} : 1;
    die "local_strides must be a scalar or HASH reference\n"
        if ref($local_stride_arg) && ref($local_stride_arg) ne 'HASH';

    my $cfg = inspect_config($parent_config);
    my $inc = parse_instance($incumbent);
    my %wanted = map { $_ => 1 } @$variables;

    my (%global_counts, %global_medium, %global_inc, %local_counts, %local_medium,
        %windows, %ops, %resolution_factors, %local_strides, %parent_level_offsets,
        %per_variable_axes);

    for my $v (sort { $a <=> $b } keys %{ $cfg->{varinumbers} }) {
        my $n = $cfg->{varinumbers}{$v};
        if ($wanted{$v}) {
            die "Incumbent lacks variable $v\n" unless exists $inc->{$v};
            my $factor = ref($factor_map) eq 'HASH' && exists($factor_map->{$v})
                ? $factor_map->{$v} : $factor_default;
            die "resolution factor for variable $v must be a positive integer\n"
                unless defined($factor) && $factor =~ /^\d+$/ && $factor >= 1;

            my $local_levels = ref($local_levels_arg) eq 'HASH'
                ? $local_levels_arg->{$v} : $local_levels_arg;
            $local_levels = 3 unless defined $local_levels;
            die "local_levels for variable $v must be an odd integer >= 3 so the incumbent is the unique centre\n"
                unless $local_levels =~ /^\d+$/ && $local_levels >= 3 && $local_levels % 2 == 1;

            my $local_stride = ref($local_stride_arg) eq 'HASH'
                ? $local_stride_arg->{$v} : $local_stride_arg;
            $local_stride = 1 unless defined $local_stride;
            die "local_stride for variable $v must be a positive integer\n"
                unless $local_stride =~ /^\d+$/ && $local_stride >= 1;

            $factor = 0 + $factor;
            $local_levels = 0 + $local_levels;
            $local_stride = 0 + $local_stride;
            $resolution_factors{$v} = $factor;
            $local_strides{$v} = $local_stride;
            $local_counts{$v} = $local_levels;

            # First construct the parent-refined coordinate system. Parent
            # levels lie at 1, 1+r, 1+2r, ... and therefore retain their exact
            # physical positions while the increment is divided by r.
            my $parent_refined_count  = refined_level_count($n, $factor);
            my $parent_medium_raw     = rescale_level($cfg->{mediumiters}{$v}, $factor);
            my $inc_raw               = rescale_level($inc->{$v}, $factor);

            # A zoom workspace is centred on the incumbent model.  It must not
            # become one-sided merely because the incumbent is at a boundary of
            # the old scope: the new local scope is a symmetric, finer search.
            my $center = int(($local_levels + 1) / 2);
            my $left_steps  = ($center - 1) * $local_stride;
            my $right_steps = ($local_levels - $center) * $local_stride;
            my $local_start_raw = $inc_raw - $left_steps;
            my $local_end_raw   = $inc_raw + $right_steps;

            # The canonical refined lattice is the union of the rescaled parent
            # scope and the centred local zoom.  If the incumbent was on an old
            # boundary, the union grows by the necessary fine-grid levels rather
            # than clipping the zoom.  Shift only the integer coordinate origin
            # so every global level remains >= 1.
            my $raw_min = $local_start_raw < 1 ? $local_start_raw : 1;
            my $raw_max = $local_end_raw > $parent_refined_count
                ? $local_end_raw : $parent_refined_count;
            my $offset = 1 - $raw_min;
            $parent_level_offsets{$v} = $offset;
            $global_counts{$v} = $raw_max - $raw_min + 1;
            $global_medium{$v} = $parent_medium_raw + $offset;
            $global_inc{$v} = $inc_raw + $offset;
            $windows{$v} = [ $local_start_raw + $offset, $local_end_raw + $offset ];
            $local_medium{$v} = $center;

            my $op = _extract_operation($cfg->{text}, $v);
            my @fine_step;
            for my $i (0 .. $#{ $op->{begin} }) {
                push @fine_step,
                    ($op->{end}[$i] - $op->{begin}[$i]) / ($parent_refined_count - 1);
            }
            my @child_begin = map { -$left_steps  * $_ } @fine_step;
            my @child_end   = map {  $right_steps * $_ } @fine_step;
            my @global_begin = map {
                $op->{begin}[$_] + ($raw_min - 1) * $fine_step[$_]
            } 0 .. $#fine_step;
            my @global_end = map {
                $op->{begin}[$_] + ($raw_max - 1) * $fine_step[$_]
            } 0 .. $#fine_step;

            $ops{$v} = {
                %$op,
                child_begin => \@child_begin,
                child_end   => \@child_end,
                global_begin => \@global_begin,
                global_end   => \@global_end,
            };
            $per_variable_axes{$v} = {
                resolution_factor          => $factor,
                local_levels               => $local_levels,
                local_stride               => $local_stride,
                parent_refined_count       => $parent_refined_count,
                parent_level_offset        => $offset,
                physical_step_per_level    => \@fine_step,
            };
        } else {
            $global_counts{$v} = $n;
            $global_medium{$v} = $cfg->{mediumiters}{$v};
            $global_inc{$v}    = $inc->{$v} if exists $inc->{$v};
            $parent_level_offsets{$v} = 0;
            # A deferred variable remains fixed in the child workspace.
            $local_counts{$v}  = 1;
            $local_medium{$v}  = 1;
        }
    }

    my $global_inc_name = format_instance(\%global_inc);
    return {
        schema              => 'Sim::OPT::StructureDesign/zoom-plan-2',
        operation           => 'zoom_in',
        parent_config       => $parent_config,
        parent_dir          => $cfg->{mypath},
        model_root          => $cfg->{file},
        child_dir           => $a{child_dir},
        child_config        => $a{child_config},
        variables           => [ @$variables ],
        resolution_factor   => $factor_default,
        resolution_factors  => \%resolution_factors,
        local_levels        => ref($local_levels_arg) eq 'HASH'
            ? { %$local_levels_arg } : $local_levels_arg,
        local_strides       => ref($local_stride_arg) eq 'HASH'
            ? { %$local_stride_arg } : $local_stride_arg,
        parent_level_offsets => \%parent_level_offsets,
        per_variable_axes   => \%per_variable_axes,
        parent_counts       => { %{ $cfg->{varinumbers} } },
        parent_medium       => { %{ $cfg->{mediumiters} } },
        incumbent_parent    => $incumbent,
        refined_counts      => \%global_counts,
        refined_medium      => \%global_medium,
        incumbent_refined        => $global_inc_name,
        incumbent_refined_levels => { %global_inc },
        local_counts             => \%local_counts,
        local_medium        => \%local_medium,
        windows             => \%windows,
        operations          => \%ops,
    };
}

sub plan_enlarge_pan {
    my (%a) = @_;
    my $template_config = $a{template_config} || $a{parent_config}
        or die "plan_enlarge_pan: template_config required\n";
    my $source_dir = $a{source_dir}
        or die "plan_enlarge_pan: source_dir required\n";
    my $source_counts = $a{source_counts};
    die "plan_enlarge_pan: source_counts HASH required\n"
        unless ref($source_counts) eq 'HASH' && keys %$source_counts;
    my $source_incumbent = $a{source_incumbent} || $a{incumbent}
        or die "plan_enlarge_pan: source_incumbent required\n";
    my $variables = $a{variables} || [];
    die "plan_enlarge_pan: variables ARRAY required\n"
        unless ref($variables) eq 'ARRAY' && @$variables;

    my $default_factor = defined($a{scope_factor}) ? $a{scope_factor} : 2;
    my $factor_arg = ref($a{scope_factors}) eq 'HASH' ? $a{scope_factors} : {};
    my $cfg = inspect_config($template_config);
    my $inc = parse_instance($source_incumbent);
    my %wanted = map { 0 + $_ => 1 } @$variables;

    # The canonical source configuration and the lattice manifest must describe
    # the same state before any enlargement is planned.  This prevents a stale
    # template (for example the original parent config) from silently defining
    # the geometry of a later state.
    _same_numeric_hash($cfg->{varinumbers}, $source_counts,
        'plan_enlarge_pan source config @varinumbers');
    for my $v (keys %$source_counts) {
        my $lev = $inc->{$v};
        die "plan_enlarge_pan: source incumbent lacks variable $v\n"
            unless defined $lev;
        die "plan_enlarge_pan: source incumbent variable $v level $lev is outside 1..$source_counts->{$v}\n"
            if $lev < 1 || $lev > $source_counts->{$v};
    }

    my (%target_counts, %target_medium, %target_inc, %factors, %ops, %axes);
    for my $v (sort { $a <=> $b } keys %$source_counts) {
        my $n = 0 + $source_counts->{$v};
        die "plan_enlarge_pan: source variable $v must have at least 1 level\n" if $n < 1;
        die "plan_enlarge_pan: source incumbent lacks variable $v\n" unless exists $inc->{$v};
        $target_counts{$v} = $n;
        $target_medium{$v} = 0 + $inc->{$v};
        $target_inc{$v} = 0 + $inc->{$v};
    }

    for my $v (@$variables) {
        die "plan_enlarge_pan: source_counts lacks variable $v\n" unless exists $source_counts->{$v};
        die "plan_enlarge_pan: template config lacks variable $v\n" unless exists $cfg->{varinumbers}{$v};
        my $source_n = 0 + $source_counts->{$v};
        die "plan_enlarge_pan: variable $v needs at least 2 source levels to maintain resolution\n"
            if $source_n < 2;
        my $factor = exists($factor_arg->{$v}) ? $factor_arg->{$v}
                   : exists($factor_arg->{"$v"}) ? $factor_arg->{"$v"}
                   : $default_factor;
        die "plan_enlarge_pan: scope factor for variable $v must be a positive integer\n"
            unless defined($factor) && "$factor" =~ /^\d+$/ && $factor >= 1;
        $factor = 0 + $factor;
        $factors{$v} = $factor;

        my $target_n = 1 + $factor * ($source_n - 1);
        die "plan_enlarge_pan: target lattice for variable $v has no unique center ($target_n levels)\n"
            unless $target_n % 2 == 1;
        my $center = int(($target_n + 1) / 2);
        $target_counts{$v} = $target_n;
        $target_medium{$v} = $center;
        $target_inc{$v} = $center;

        my $op = _extract_operation($cfg->{text}, $v);
        my @step;
        for my $i (0 .. $#{ $op->{begin} }) {
            push @step, ($op->{end}[$i] - $op->{begin}[$i]) / ($source_n - 1);
        }
        my @child_begin = map { -($center - 1) * $_ } @step;
        my @child_end   = map {  ($target_n - $center) * $_ } @step;
        $ops{$v} = {
            %$op,
            child_begin => \@child_begin,
            child_end   => \@child_end,
        };
        $axes{$v} = {
            scope_change => 'enlarge',
            scope_factor => $factor,
            resolution_change => 'same',
            source_levels => $source_n,
            target_levels => $target_n,
            source_incumbent_level => 0 + $inc->{$v},
            target_incumbent_level => $center,
            physical_step_per_level => \@step,
            relative_begin => \@child_begin,
            relative_end => \@child_end,
        };
    }

    return {
        schema => 'Sim::OPT::StructureDesign/scope-pan-plan-1',
        operation => 'enlarge_scope+maintain_resolution+pan',
        primitives => [ 'enlarge_scope', 'maintain_resolution', 'pan' ],
        template_config => $template_config,
        source_dir => $source_dir,
        source_counts => { map { $_ => 0 + $source_counts->{$_} } keys %$source_counts },
        source_medium => { map { $_ => 0 + $cfg->{mediumiters}{$_} } keys %{ $cfg->{mediumiters} } },
        source_incumbent => $source_incumbent,
        source_incumbent_levels => { %$inc },
        variables => [ map { 0 + $_ } @$variables ],
        scope_factor => 0 + $default_factor,
        scope_factors => \%factors,
        target_counts => \%target_counts,
        target_medium => \%target_medium,
        target_incumbent => format_instance(\%target_inc),
        target_incumbent_levels => \%target_inc,
        per_variable_axes => \%axes,
        operations => \%ops,
        model_root => $a{model_root} || $cfg->{file},
        child_dir => $a{child_dir},
        child_config => $a{child_config},
        lattice_manifest => $a{lattice_manifest},
    };
}

sub _fmt_num {
    my ($x) = @_;
    return '0' if abs($x) < 1e-12;
    my $s = sprintf('%.10f', $x);
    $s =~ s/0+$//;
    $s =~ s/\.$//;
    return $s;
}

sub _fmt_vec {
    my ($v) = @_;
    return '[ ' . join(', ', map { '"' . _fmt_num($_) . '"' } @$v) . ' ]';
}

sub _replace_hash_assignment {
    my ($txt, $name, $h) = @_;
    my $body = join(', ', map { $_ . ' => ' . $h->{$_} } sort { $a <=> $b } keys %$h) . ',';
    my $new = "$name = \n( { \n$body\n} );";
    my $n = ($txt =~ s/^\s*\Q$name\E\s*=\s*\(\s*\{.*?\}\s*\)\s*;/$new/ms);
    die "Could not replace $name\n" unless $n == 1;
    return $txt;
}

sub _patch_operation {
    my ($txt, $v, $op) = @_;
    my $type = $op->{type};
    my $a = $op->{child_begin};
    my $b = $op->{child_end};

    if ($type eq 'rotate') {
        my $range = '[ ' . _fmt_num($a->[0]) . ', ' . _fmt_num($b->[0]) . ' ]';
        my $re = qr/(\$vals\{1\}\{\Q$v\E\}\{rotate\}\s*=\s*\[\s*\[\s*["'][^"']*["']\s*,\s*)(?:\[[^\]]+\]|["']?[+-]?(?:\d+(?:\.\d*)?|\.\d+)["']?)(\s*,)/ms;
        my $n = ($txt =~ s/$re/$1$range$2/);
        die "Could not patch rotate for variable $v\n" unless $n == 1;
        return $txt;
    }

    if ($type eq 'translate') {
        my $range = '[ ' . _fmt_vec($a) . ', ' . _fmt_vec($b) . ' ]';
        my $re = qr/(\$vals\{1\}\{\Q$v\E\}\{translate\}\s*=\s*\[\s*\[\s*["'][^"']*["']\s*,\s*)\[.*?\](\s*,\s*["'][^"']+["'])/ms;
        my $n = ($txt =~ s/$re/$1$range$2/);
        die "Could not patch translate for variable $v\n" unless $n == 1;
        return $txt;
    }

    if ($type eq 'obs_modify') {
        my $range = '[ ' . _fmt_vec($a) . ', ' . _fmt_vec($b) . ' ]';
        my $re = qr/(\$vals\{1\}\{\Q$v\E\}\{obs_modify\}\s*=\s*\[\s*\[\s*\[[^\]]+\]\s*,\s*["'][^"']+["']\s*,\s*)\[[^\n]*?\](\s*\]\s*,?\s*\]\s*;)/ms;
        my $n = ($txt =~ s/$re/$1$range$2/);
        die "Could not patch obs_modify for variable $v\n" unless $n == 1;
        return $txt;
    }

    die "Cannot patch unsupported operation $type for variable $v\n";
}

sub render_zoom_config {
    my ($plan) = @_;
    die "render_zoom_config: zoom plan required\n" unless ref($plan) eq 'HASH' && $plan->{operation} eq 'zoom_in';
    my $cfg = inspect_config($plan->{parent_config});
    my $txt = $cfg->{text};
    my $child_dir = $plan->{child_dir} or die "render_zoom_config: child_dir missing in plan\n";

    my $n = ($txt =~ s/^(?!\s*#)(\s*\$mypath\s*=\s*)["'][^"']+["']/$1"$child_dir"/m);
    die "Could not patch \$mypath\n" unless $n == 1;

    my $sweep = '@sweeps = ( [ [ ' . join(' , ', @{ $plan->{variables} }) . ' ] ] );';
    $n = ($txt =~ s/^(?!\s*#)\s*\@sweeps\s*=\s*[^;]+;/$sweep/m);
    die "Could not patch active \@sweeps\n" unless $n == 1;

    $txt = _replace_hash_assignment($txt, '@varinumbers', $plan->{local_counts});
    $txt = _replace_hash_assignment($txt, '@mediumiters', $plan->{local_medium});

    for my $v (@{ $plan->{variables} }) {
        $txt = _patch_operation($txt, $v, $plan->{operations}{$v});
    }

    my $stamp = "# Generated by Sim::OPT::StructureDesign $VERSION\n"
              . "# Parent incumbent: $plan->{incumbent_parent}\n"
              . "# Refined global incumbent: $plan->{incumbent_refined}\n";
    return $stamp . $txt;
}

sub render_enlarge_pan_config {
    my ($plan) = @_;
    die "render_enlarge_pan_config: scope-pan plan required\n"
        unless ref($plan) eq 'HASH'
            && ($plan->{operation} || '') eq 'enlarge_scope+maintain_resolution+pan';
    my $cfg = inspect_config($plan->{template_config});
    my $txt = $cfg->{text};
    my $child_dir = $plan->{child_dir}
        or die "render_enlarge_pan_config: child_dir missing in plan\n";

    my $n = ($txt =~ s/^(?!\s*#)(\s*\$mypath\s*=\s*)["'][^"']+["']/$1"$child_dir"/m);
    die "Could not patch \$mypath\n" unless $n == 1;

    my $sweep = '@sweeps = ( [ [ ' . join(' , ', @{ $plan->{variables} }) . ' ] ] );';
    $n = ($txt =~ s/^(?!\s*#)\s*\@sweeps\s*=\s*[^;]+;/$sweep/m);
    die "Could not patch active \@sweeps\n" unless $n == 1;

    $txt = _replace_hash_assignment($txt, '@varinumbers', $plan->{target_counts});
    $txt = _replace_hash_assignment($txt, '@mediumiters', $plan->{target_medium});
    for my $v (@{ $plan->{variables} }) {
        $txt = _patch_operation($txt, $v, $plan->{operations}{$v});
    }

    my $stamp = "# Generated by Sim::OPT::StructureDesign $VERSION\n"
              . "# Operation: enlarge_scope + maintain_resolution + pan\n"
              . "# Source incumbent: $plan->{source_incumbent}\n"
              . "# Target reference: $plan->{target_incumbent}\n";
    return $stamp . $txt;
}

sub validate_enlarge_pan_config_text {
    my ($txt, $plan, %a) = @_;
    die "validate_enlarge_pan_config_text: text required\n" unless defined $txt;
    die "validate_enlarge_pan_config_text: scope-pan plan required\n"
        unless ref($plan) eq 'HASH'
            && ($plan->{operation} || '') eq 'enlarge_scope+maintain_resolution+pan';

    my ($mypath) = $txt =~ /^(?!\s*#)\s*\$mypath\s*=\s*["']([^"']+)["']/m;
    my ($file)   = $txt =~ /^(?!\s*#)\s*\$file\s*=\s*["']([^"']+)["']/m;
    die "validate_enlarge_pan_config_text: cannot parse \$mypath\n" unless defined $mypath;
    die "validate_enlarge_pan_config_text: cannot parse \$file\n" unless defined $file;

    if (defined $a{target_dir}) {
        die "validate_enlarge_pan_config_text: \$mypath is '$mypath', expected '$a{target_dir}'\n"
            unless $mypath eq $a{target_dir};
    }
    my $root = $plan->{model_root};
    die "validate_enlarge_pan_config_text: model root is '$file', expected '$root'\n"
        if defined($root) && length($root) && $file ne $root;

    my $counts = _parse_hash_assignment($txt, '@varinumbers');
    my $medium = _parse_hash_assignment($txt, '@mediumiters');
    _same_numeric_hash($counts, $plan->{target_counts}, 'scope-pan @varinumbers');
    _same_numeric_hash($medium, $plan->{target_medium}, 'scope-pan @mediumiters');

    my $target_inc = parse_instance($plan->{target_incumbent});
    for my $v (@{ $plan->{variables} || [] }) {
        my $axis = $plan->{per_variable_axes}{$v}
            or die "validate_enlarge_pan_config_text: scope plan lacks axis for variable $v\n";
        my $want = $plan->{operations}{$v}
            or die "validate_enlarge_pan_config_text: scope plan lacks operation for variable $v\n";
        my $got = _extract_operation($txt, $v);
        die "validate_enlarge_pan_config_text: operation type differs for variable $v\n"
            unless ($got->{type} || '') eq ($want->{type} || '');
        if (exists $want->{mode}) {
            die "validate_enlarge_pan_config_text: operation mode differs for variable $v\n"
                unless defined($got->{mode}) && $got->{mode} eq $want->{mode};
        }
        _same_numeric_vector($got->{begin}, $want->{child_begin},
            "scope-pan variable $v physical begin");
        _same_numeric_vector($got->{end}, $want->{child_end},
            "scope-pan variable $v physical end");

        my $n = 0 + $plan->{target_counts}{$v};
        my $center = int(($n + 1) / 2);
        die "validate_enlarge_pan_config_text: variable $v target incumbent is not centered\n"
            unless 0 + $target_inc->{$v} == $center
                && 0 + $plan->{target_medium}{$v} == $center;

        my @step_from_target;
        for my $i (0 .. $#{ $got->{begin} }) {
            push @step_from_target,
                ($got->{end}[$i] - $got->{begin}[$i]) / ($n - 1);
        }
        _same_numeric_vector(\@step_from_target, $axis->{physical_step_per_level},
            "scope-pan variable $v maintained resolution");
    }
    return 1;
}

sub write_manifest {
    my ($plan, $path) = @_;
    die "write_manifest: plan HASH and path required\n" unless ref($plan) eq 'HASH' && defined $path;
    my $json = JSON::PP->new->canonical(1)->pretty(1)->encode($plan);
    _spit($path, $json);
    return $path;
}

sub _copy_tree {
    my ($src, $dst) = @_;
    die "Source directory does not exist: $src\n" unless -d $src;
    die "Destination already exists: $dst\n" if -e $dst;
    make_path($dst);
    my $src_len = length($src);
    find({
        no_chdir => 1,
        wanted => sub {
            my $p = $File::Find::name;
            return if $p eq $src;
            my $rel = substr($p, $src_len);
            $rel =~ s{^/}{};
            my $q = "$dst/$rel";
            # Test symlinks before -d/-f: Perl's file tests follow symlinks,
            # so a directory symlink otherwise becomes an empty real directory.
            # Memory roots are often morphed Sim::OPT instances and must retain
            # their link topology exactly.
            if (-l $p) {
                my $target = readlink($p);
                die "readlink $p failed: $!\n" unless defined $target;
                make_path(dirname($q)) unless -d dirname($q);
                symlink($target, $q) or die "symlink $q failed: $!\n";
            } elsif (-d $p) {
                make_path($q) unless -d $q;
                my $mode = (stat($p))[2];
                chmod($mode & 07777, $q) if defined $mode;
            } elsif (-f $p) {
                make_path(dirname($q)) unless -d dirname($q);
                copy($p, $q) or die "copy $p -> $q failed: $!\n";
                my $mode = (stat($p))[2];
                chmod($mode & 07777, $q) if defined $mode;
            }
        },
    }, $src);
}

sub _load_cryptolinks {
    my ($path) = @_;
    return undef unless defined($path) && -f $path;
    my $data = do $path;
    return $data if ref($data) eq 'HASH';

    # Conservative fallback for Data::Dump-like key/value pairs.
    my $txt = _slurp($path);
    my %h;
    while ($txt =~ /["']([^"']+)["']\s*=>\s*(?:["']([^"']*)["']|(\d+))/g) {
        $h{$1} = defined($2) ? $2 : $3;
    }
    return keys(%h) ? \%h : undef;
}

sub resolve_incumbent_model {
    my (%a) = @_;
    my $dir = $a{parent_dir} or die "resolve_incumbent_model: parent_dir required\n";
    my $root = $a{model_root} or die "resolve_incumbent_model: model_root required\n";
    my $inc = $a{incumbent} or die "resolve_incumbent_model: incumbent required\n";
    return $a{incumbent_model_dir} if $a{incumbent_model_dir};

    my $crypt = $a{cryptolinks} || "$dir/${root}_0_cryptolinks.pl";
    my $h = _load_cryptolinks($crypt)
        or die "Cannot parse cryptolinks file $crypt; pass incumbent_model_dir explicitly\n";

    # Older Sim::OPT files may map clear-id => numeric short-id directly.
    my $short = $h->{$inc};
    $short = undef unless defined($short) && "$short" =~ /^\d+$/;

    # Native files may instead contain absolute path pairs in both directions:
    #   .../bt_5 <=> .../bt_1-4_2-9_...
    unless (defined $short) {
        for my $k (keys %$h) {
            my $v = $h->{$k};
            next if ref($v) || !defined($v);
            my $kb = basename($k);
            my $vb = basename("$v");
            if ($kb =~ /^\Q$root\E_(\d+)$/
                && $vb eq $root . '_' . $inc) {
                $short = 0 + $1;
                last;
            }
            if ($vb =~ /^\Q$root\E_(\d+)$/
                && $kb eq $root . '_' . $inc) {
                $short = 0 + $1;
                last;
            }
        }
    }

    die "Incumbent '$inc' not found in $crypt\n" unless defined $short;
    my $model = "$dir/${root}_$short";
    die "Resolved incumbent directory does not exist: $model\n" unless -d $model;
    return $model;
}

sub create_zoom_workspace {
    my (%a) = @_;
    my $plan = $a{plan} || plan_zoom_in(%a);
    my $commit = $a{commit} ? 1 : 0;
    return $plan unless $commit;

    my $child_dir = $plan->{child_dir} or die "create_zoom_workspace: child_dir required\n";
    die "Refusing to overwrite existing child directory $child_dir\n" if -e $child_dir;
    my $child_cfg_name = $plan->{child_config} || basename($plan->{parent_config});
    my $src_model = resolve_incumbent_model(
        parent_dir          => $plan->{parent_dir},
        model_root          => $plan->{model_root},
        incumbent           => $plan->{incumbent_parent},
        cryptolinks         => $a{cryptolinks},
        incumbent_model_dir => $a{incumbent_model_dir},
    );

    make_path($child_dir);
    _copy_tree($src_model, "$child_dir/$plan->{model_root}");
    _spit("$child_dir/$child_cfg_name", render_zoom_config($plan));
    write_manifest($plan, "$child_dir/structuredesign-zoom.json");
    return $plan;
}


sub create_enlarge_pan_workspace {
    my (%a) = @_;
    my $plan = $a{plan} || plan_enlarge_pan(%a);
    my $commit = $a{commit} ? 1 : 0;
    return $plan unless $commit;

    my $child_dir = $plan->{child_dir}
        or die "create_enlarge_pan_workspace: child_dir required\n";
    die "Refusing to overwrite existing child directory $child_dir\n" if -e $child_dir;
    my $child_cfg_name = $plan->{child_config} || basename($plan->{template_config});
    my $src_model = resolve_incumbent_model(
        parent_dir => $plan->{source_dir},
        model_root => $plan->{model_root},
        incumbent => $plan->{source_incumbent},
        cryptolinks => $a{cryptolinks},
        incumbent_model_dir => $a{incumbent_model_dir},
    );

    my $rendered = render_enlarge_pan_config($plan);
    validate_enlarge_pan_config_text($rendered, $plan, target_dir => $child_dir);

    make_path($child_dir);
    _copy_tree($src_model, "$child_dir/$plan->{model_root}");
    _spit("$child_dir/$child_cfg_name", $rendered);
    write_manifest($plan, "$child_dir/structuredesign-scope.json");
    return $plan;
}

sub _same_numeric_hash {
    my ($got, $want, $label) = @_;
    die "$label: HASH references required\n"
        unless ref($got) eq 'HASH' && ref($want) eq 'HASH';
    my @gk = sort { $a <=> $b } keys %$got;
    my @wk = sort { $a <=> $b } keys %$want;
    die "$label: variable sets differ\n" unless "@gk" eq "@wk";
    for my $v (@wk) {
        die "$label: variable $v differs (got $got->{$v}, expected $want->{$v})\n"
            unless 0 + $got->{$v} == 0 + $want->{$v};
    }
    return 1;
}

sub _same_numeric_vector {
    my ($got, $want, $label) = @_;
    die "$label: ARRAY references required\n"
        unless ref($got) eq 'ARRAY' && ref($want) eq 'ARRAY';
    die "$label: vector lengths differ\n" unless @$got == @$want;
    for my $i (0 .. $#$want) {
        my $d = abs((0 + $got->[$i]) - (0 + $want->[$i]));
        die "$label: component $i differs (got $got->[$i], expected $want->[$i])\n"
            if $d > 1e-9;
    }
    return 1;
}

sub validate_refined_parent_config_text {
    my ($txt, $plan, %a) = @_;
    die "validate_refined_parent_config_text: text required\n" unless defined $txt;
    die "validate_refined_parent_config_text: zoom plan required\n"
        unless ref($plan) eq 'HASH' && ($plan->{operation} || '') eq 'zoom_in';

    my ($mypath) = $txt =~ /^(?!\s*#)\s*\$mypath\s*=\s*["']([^"']+)["']/m;
    my ($file)   = $txt =~ /^(?!\s*#)\s*\$file\s*=\s*["']([^"']+)["']/m;
    die "validate_refined_parent_config_text: cannot parse \$mypath\n" unless defined $mypath;
    die "validate_refined_parent_config_text: cannot parse \$file\n" unless defined $file;

    if (defined $a{target_dir}) {
        die "validate_refined_parent_config_text: \$mypath is '$mypath', expected '$a{target_dir}'\n"
            unless $mypath eq $a{target_dir};
    }
    my $root = $plan->{model_root};
    die "validate_refined_parent_config_text: model root is '$file', expected '$root'\n"
        if defined($root) && length($root) && $file ne $root;

    my $counts = _parse_hash_assignment($txt, '@varinumbers');
    my $medium = _parse_hash_assignment($txt, '@mediumiters');
    _same_numeric_hash($counts, $plan->{refined_counts}, 'refined @varinumbers');
    _same_numeric_hash($medium, $plan->{refined_medium}, 'refined @mediumiters');

    # The canonical refined-global configuration represents the union of the
    # rescaled parent scope and the centred local zoom.  At an old boundary the
    # union can extend beyond the parent scope while keeping the finer step.
    for my $v (@{ $plan->{variables} || [] }) {
        my $want = $plan->{operations}{$v}
            or die "validate_refined_parent_config_text: zoom plan lacks operation for variable $v\n";
        my $got = _extract_operation($txt, $v);
        die "validate_refined_parent_config_text: operation type differs for variable $v\n"
            unless ($got->{type} || '') eq ($want->{type} || '');
        if (($want->{type} || '') eq 'obs_modify') {
            die "validate_refined_parent_config_text: obs_modify mode differs for variable $v\n"
                unless ($got->{mode} || '') eq ($want->{mode} || '');
        }
        _same_numeric_vector($got->{begin}, $want->{global_begin}, "variable $v physical begin");
        _same_numeric_vector($got->{end},   $want->{global_end},   "variable $v physical end");
    }

    return 1;
}

sub render_refined_parent_config {
    my ($plan, %a) = @_;
    die "render_refined_parent_config: zoom plan required\n"
        unless ref($plan) eq 'HASH' && $plan->{operation} eq 'zoom_in';
    my $cfg = inspect_config($plan->{parent_config});
    my $txt = $cfg->{text};

    if (defined $a{target_dir}) {
        my $n = ($txt =~ s/^(?!\s*#)(\s*\$mypath\s*=\s*)["'][^"']+["']/$1"$a{target_dir}"/m);
        die "render_refined_parent_config: could not patch \$mypath\n" unless $n == 1;
    }

    $txt = _replace_hash_assignment($txt, '@varinumbers', $plan->{refined_counts});
    $txt = _replace_hash_assignment($txt, '@mediumiters', $plan->{refined_medium});
    for my $v (@{ $plan->{variables} || [] }) {
        my $op = $plan->{operations}{$v}
            or die "render_refined_parent_config: zoom plan lacks operation for variable $v\n";
        my %global_op = (%$op, child_begin => $op->{global_begin}, child_end => $op->{global_end});
        $txt = _patch_operation($txt, $v, \%global_op);
    }
    my $stamp = "# Refined global lattice generated by Sim::OPT::StructureDesign $VERSION\n"
              . "# Union of rescaled parent scope and centred zoom; fine-grid resolution preserved.\n";
    my $rendered = $stamp . $txt;
    validate_refined_parent_config_text($rendered, $plan, %a);
    return $rendered;
}

sub _render_cloned_state_config_unchecked {
    my ($source_config, %a) = @_;
    die "render_cloned_state_config: source_config required\n"
        unless defined($source_config) && -f $source_config;
    die "render_cloned_state_config: target_dir required\n"
        unless defined($a{target_dir}) && length($a{target_dir});

    my $cfg = inspect_config($source_config);
    my $txt = $cfg->{text};
    my $target_dir = $a{target_dir};
    my $n = ($txt =~ s/^(?!\s*#)(\s*\$mypath\s*=\s*)["'][^"']+["']/$1"$target_dir"/m);
    die "render_cloned_state_config: could not patch \$mypath in $source_config\n" unless $n == 1;
    return $txt;
}

sub validate_cloned_state_config_text {
    my ($txt, $source_config, %a) = @_;
    die "validate_cloned_state_config_text: text required\n" unless defined $txt;
    die "validate_cloned_state_config_text: source_config required\n"
        unless defined($source_config) && -f $source_config;
    die "validate_cloned_state_config_text: target_dir required\n"
        unless defined($a{target_dir}) && length($a{target_dir});

    my $expected = _render_cloned_state_config_unchecked(
        $source_config, target_dir => $a{target_dir},
    );
    die "validate_cloned_state_config_text: target differs from source by more than \$mypath\n"
        unless $txt eq $expected;

    my $source = inspect_config($source_config);
    my ($mypath) = $txt =~ /^(?!\s*#)\s*\$mypath\s*=\s*["']([^"']+)["']/m;
    my ($file)   = $txt =~ /^(?!\s*#)\s*\$file\s*=\s*["']([^"']+)["']/m;
    die "validate_cloned_state_config_text: cannot parse \$mypath\n" unless defined $mypath;
    die "validate_cloned_state_config_text: cannot parse \$file\n" unless defined $file;
    die "validate_cloned_state_config_text: \$mypath is '$mypath', expected '$a{target_dir}'\n"
        unless $mypath eq $a{target_dir};
    die "validate_cloned_state_config_text: model root differs (got '$file', expected '$source->{file}')\n"
        unless $file eq $source->{file};

    my $counts = _parse_hash_assignment($txt, '@varinumbers');
    my $medium = _parse_hash_assignment($txt, '@mediumiters');
    _same_numeric_hash($counts, $source->{varinumbers}, 'cloned @varinumbers');
    _same_numeric_hash($medium, $source->{mediumiters}, 'cloned @mediumiters');
    return 1;
}

sub render_cloned_state_config {
    my ($source_config, %a) = @_;
    my $txt = _render_cloned_state_config_unchecked($source_config, %a);
    validate_cloned_state_config_text($txt, $source_config, %a);
    return $txt;
}

sub scan_max_short_id {
    my ($dir, $root) = @_;
    die "scan_max_short_id: directory and model root required\n" unless defined($dir) && defined($root);
    opendir my $dh, $dir or die "Cannot open directory $dir: $!\n";
    my $max = 0;
    while (defined(my $e = readdir $dh)) {
        if ($e =~ /^\Q$root\E_(\d+)$/) {
            $max = $1 if $1 > $max;
        }
    }
    closedir $dh;
    return $max;
}

sub plan_zoom_out_merge {
    my (%a) = @_;
    my $zoom = $a{zoom_plan} or die "plan_zoom_out_merge: zoom_plan required\n";
    die "plan_zoom_out_merge: invalid zoom plan\n"
        unless ref($zoom) eq 'HASH' && $zoom->{operation} eq 'zoom_in';

    my $parent_dir = $a{parent_dir} || $zoom->{parent_dir};
    my $child_dir  = $a{child_dir}  || $zoom->{child_dir};
    my $root       = $zoom->{model_root};
    my $parent_max;
    if (defined($parent_dir) && -d $parent_dir) {
        $parent_max = scan_max_short_id($parent_dir, $root);
    }

    my $child_max;
    if (defined($child_dir) && -d $child_dir) {
        $child_max = scan_max_short_id($child_dir, $root);
    }

    my %ranges = map { $_ => [ @{ $zoom->{windows}{$_} } ] } @{ $zoom->{variables} };
    return {
        schema            => 'Sim::OPT::StructureDesign/zoom-out-plan-1',
        operation         => 'zoom_out',
        parent_dir        => $parent_dir,
        child_dir         => $child_dir,
        model_root        => $root,
        variables         => [ @{ $zoom->{variables} } ],
        resolution_factor => $zoom->{resolution_factor},
        parent_counts_old => { %{ $zoom->{parent_counts} } },
        global_counts_new => { %{ $zoom->{refined_counts} } },
        parent_medium_new => { %{ $zoom->{refined_medium} } },
        parent_level_rule => 'new_level = parent_level_offset + 1 + resolution_factor * (old_level - 1)',
        child_windows     => \%ranges,
        child_level_rule  => 'global_level = child_window_start + local_stride * (local_level - 1)',
        parent_short_max  => $parent_max,
        child_short_max   => $child_max,
        child_short_offset => $parent_max,
        safety => {
            clear_names => 'structural variable-level mapping',
            short_ids   => 'offset only in validated identifier fields and model-folder basenames',
            result_values => 'never blind numeric substitution',
        },
    };
}

# Map a child's local 1..L clear name onto the refined global lattice.
sub map_local_instance_to_global {
    my ($s, $plan) = @_;
    my $h = parse_instance($s);
    my %out = %$h;
    my %active = map { $_ => 1 } @{ $plan->{variables} || [] };

    # Validate the source clear name on the local zoom lattice before any
    # collapsed coordinates are restored to refined-global levels.
    if (ref($plan->{local_counts}) eq 'HASH' && keys %{ $plan->{local_counts} }) {
        my @got = sort { $a <=> $b } keys %out;
        my @want = sort { $a <=> $b } keys %{ $plan->{local_counts} };
        die "Local instance '$s' variable set differs from zoom local_counts\n"
            unless "@got" eq "@want";
        for my $v (@want) {
            my $max = 0 + $plan->{local_counts}{$v};
            my $lev = 0 + $out{$v};
            die "Local instance '$s': variable $v level $lev outside 1..$max\n"
                if $lev < 1 || $lev > $max;
        }
    }

    # zoom-plan-1 files written before incumbent_refined_levels was persisted
    # still contain the equivalent canonical clear name in incumbent_refined.
    # Recover the hash from that string so existing completed zoom states can
    # be reembedded without rerunning their simulations.
    my $inc_levels = $plan->{incumbent_refined_levels};
    if (ref($inc_levels) ne 'HASH' && defined($plan->{incumbent_refined})
        && length($plan->{incumbent_refined})) {
        $inc_levels = parse_instance($plan->{incumbent_refined});
    }
    $inc_levels = {} unless ref($inc_levels) eq 'HASH';

    for my $v (keys %out) {
        if ($active{$v}) {
            my $w = $plan->{windows}{$v} or die "No window for variable $v\n";
            my $stride = 1;
            if (ref($plan->{local_strides}) eq 'HASH' && exists $plan->{local_strides}{$v}) {
                $stride = 0 + $plan->{local_strides}{$v};
            } elsif (ref($plan->{per_variable_axes}) eq 'HASH'
                     && ref($plan->{per_variable_axes}{$v}) eq 'HASH'
                     && exists $plan->{per_variable_axes}{$v}{local_stride}) {
                $stride = 0 + $plan->{per_variable_axes}{$v}{local_stride};
            }
            my $g = $w->[0] + ($out{$v} - 1) * $stride;
            die "Local level $out{$v} for v$v maps outside [$w->[0],$w->[1]]\n"
                if $g < $w->[0] || $g > $w->[1];
            $out{$v} = $g;
        } elsif (($plan->{local_counts}{$v} || 0) == 1
                 && exists $inc_levels->{$v}) {
            # In a zoom workspace, inactive variables are collapsed to local
            # level 1. Re-embedding must restore their refined-global level.
            $out{$v} = $inc_levels->{$v};
        }
    }
    return format_instance(\%out);
}

# Rewrite only structurally recognizable clear names; numeric result values are untouched.
sub rewrite_clear_instances_in_text {
    my ($txt, $mapper) = @_;
    die "rewrite_clear_instances_in_text: mapper CODE required\n" unless ref($mapper) eq 'CODE';
    $txt =~ s{(?<![A-Za-z0-9])((?:\d+-\d+)(?:_\d+-\d+)+)(?![A-Za-z0-9])}{$mapper->($1)}ge;
    return $txt;
}

sub _quote_scalar {
    my ($x) = @_;
    my $q = defined($x) ? "$x" : '';
    $q =~ s/([\\"])/\\$1/g;
    return qq{"$q"};
}


# -------------------------------------------------------------------------
# Memory reconstruction: reactivate retained medoids jointly in one workspace.
# The medoids become explicit centres of one multi-star acquisition, one totres
# and one surrogate.  Active axes are nominally compressed to about half their
# source level count while preserving the source grid and every medoid exactly;
# if the medoids themselves span a wider interval, the shared recalled axis is
# widened only enough to contain them.  Three-level variables are incompressible.
# -------------------------------------------------------------------------

sub memory_level_count {
    my ($n) = @_;
    die "memory_level_count: level count must be an integer >= 1\n"
        unless defined($n) && "$n" =~ /^\d+$/ && $n >= 1;
    return 0 + $n if $n <= 3;

    # Keep an odd number so the remembered medoid is a unique central level.
    # Choose the odd integer nearest to n/2, with a minimum of 3.  This gives
    # 5->3, 9->5, 10->5, 17->9, 19->9, 29->15, ...
    my $half = $n / 2;
    my $lo = int($half);
    $lo-- if $lo % 2 == 0;
    $lo = 3 if $lo < 3;
    my $hi = $lo + 2;
    return (abs($half - $lo) <= abs($hi - $half)) ? $lo : $hi;
}

sub _memory_set_dowhat_string {
    my ($txt, $key, $value) = @_;
    my $q = defined($value) ? "$value" : '';
    $q =~ s/([\\"])/\\$1/g;
    $q = qq{"$q"};

    my $n = ($txt =~ s/^(\s*)\Q$key\E\s*=>\s*["'][^"']*["']\s*,[^\n]*$/$1$key => $q,/m);
    return $txt if $n == 1;
    die "memory config: multiple active '$key' entries\n" if $n > 1;

    $n = ($txt =~ s/^\s*#\s*\Q$key\E\s*=>[^\n]*$/$key => $q,/m);
    return $txt if $n == 1;
    die "memory config: multiple commented '$key' entries\n" if $n > 1;

    $n = ($txt =~ s/(%dowhat\s*=\s*\(.*?)(^\s*\);[^\n]*$)/$1$key => $q,\n$2/ms);
    die "memory config: could not insert '$key' into %dowhat\n" unless $n == 1;
    return $txt;
}


sub _memory_format_starpositions {
    my ($positions) = @_;
    die "memory config: starpositions ARRAY required\n"
        unless ref($positions) eq 'ARRAY' && @$positions;
    my @rows;
    for my $h (@$positions) {
        die "memory config: each starposition must be a HASH reference\n"
            unless ref($h) eq 'HASH';
        my @pairs;
        for my $v (sort { $a <=> $b } keys %$h) {
            my $lev = $h->{$v};
            die "memory config: invalid starposition $v => $lev\n"
                unless "$v" =~ /^\d+$/ && defined($lev) && "$lev" =~ /^\d+$/;
            push @pairs, "$v => $lev";
        }
        push @rows, '        { ' . join(', ', @pairs) . ' }';
    }
    return "[\n" . join(",\n", @rows) . "\n    ]";
}

sub _memory_set_dowhat_perl_value {
    my ($txt, $key, $value_text) = @_;
    die "memory config: invalid dowhat key '$key'\n"
        unless defined($key) && $key =~ /^\w+$/;
    die "memory config: perl value required for '$key'\n"
        unless defined($value_text) && length($value_text);

    # Replace the flat array-of-hashes form emitted by StructureDesign.
    my $n = ($txt =~ s{^(\s*)\Q$key\E\s*=>\s*\[(?:\s*\{[^{}]*\}\s*,?)*\s*\]\s*,[^\n]*$}{$1$key => $value_text,}ms);
    return $txt if $n == 1;
    die "memory config: multiple active '$key' entries\n" if $n > 1;

    # Replace a scalar active value such as starpositions => "".
    $n = ($txt =~ s/^(\s*)\Q$key\E\s*=>\s*[^,\n]+\s*,[^\n]*$/$1$key => $value_text,/m);
    return $txt if $n == 1;
    die "memory config: multiple active '$key' entries\n" if $n > 1;

    # Prefer activating the documented commented slot when present.
    $n = ($txt =~ s/^\s*#\s*\Q$key\E\s*=>[^\n]*$/$key => $value_text,/m);
    return $txt if $n == 1;
    die "memory config: multiple commented '$key' entries\n" if $n > 1;

    $n = ($txt =~ s/(%dowhat\s*=\s*\(.*?)(^\s*\);[^\n]*$)/$1$key => $value_text,\n$2/ms);
    die "memory config: could not insert '$key' into %dowhat\n" unless $n == 1;
    return $txt;
}

sub plan_memory_reconstruction {
    my (%a) = @_;
    my $source_config = $a{source_config} or die "plan_memory_reconstruction: source_config required\n";
    my $medoids = $a{medoids};
    die "plan_memory_reconstruction: medoids ARRAY required\n"
        unless ref($medoids) eq 'ARRAY' && @$medoids;
    my $variables = $a{variables};
    die "plan_memory_reconstruction: variables ARRAY required\n"
        unless ref($variables) eq 'ARRAY' && @$variables;
    my $child_dir = $a{child_dir} or die "plan_memory_reconstruction: child_dir required\n";
    my $child_config = $a{child_config} || 'memory.pl';
    my $memory_root = defined($a{memory_model_root}) && length($a{memory_model_root})
        ? $a{memory_model_root} : 'btmed';
    die "plan_memory_reconstruction: memory_model_root must be a simple model-directory name\n"
        unless $memory_root =~ /^[A-Za-z0-9_.-]+$/;

    my $cfg = inspect_config($source_config);
    my @vars = sort { $a <=> $b } map { 0 + $_ } @$variables;
    my %active = map { $_ => 1 } @vars;
    for my $v (@vars) {
        die "plan_memory_reconstruction: variable $v absent from source lattice\n"
            unless exists $cfg->{varinumbers}{$v};
    }

    # Parse and validate all retained medoids in the source lattice first.
    my (@clear_medoids, @source_positions);
    my %seen;
    for my $clear (@$medoids) {
        next if $seen{$clear}++;
        my $h = parse_instance($clear);
        my %pos;
        for my $v (sort { $a <=> $b } keys %{ $cfg->{varinumbers} }) {
            die "plan_memory_reconstruction: medoid '$clear' lacks variable $v\n"
                unless exists $h->{$v};
            my $lev = 0 + $h->{$v};
            my $max = 0 + $cfg->{varinumbers}{$v};
            die "plan_memory_reconstruction: medoid '$clear' has variable $v level $lev outside 1..$max\n"
                if $lev < 1 || $lev > $max;
            $pos{$v} = $lev;
        }
        push @clear_medoids, $clear;
        push @source_positions, \%pos;
    }
    die "plan_memory_reconstruction: no distinct medoids remain\n" unless @source_positions;

    # In a shared reconstruction all medoids must inhabit one common lattice.
    # Variables not reconstructed by the star block therefore have to be fixed
    # identically in every medoid.  Otherwise there is no single rectangular
    # landscape for one totres/ordmeta pair.
    for my $v (sort { $a <=> $b } keys %{ $cfg->{varinumbers} }) {
        next if $active{$v};
        my %levels = map { $_->{$v} => 1 } @source_positions;
        die "plan_memory_reconstruction: medoids differ on inactive variable $v; include variable $v in reconstruct_memory variables for a shared landscape\n"
            if keys(%levels) > 1;
    }

    # Shared compression rule.
    #
    # The earlier per-medoid implementation could centre an independent half-
    # scope lattice on every medoid.  In one shared workspace that is impossible
    # in general without moving medoids off their actual source coordinates.
    # Instead, retain the source resolution and choose, per active variable, the
    # smallest contiguous source-grid window that:
    #   (a) contains every retained medoid exactly, and
    #   (b) is at least the nominal compressed width memory_level_count(L).
    # Thus a compact medoid set receives the intended approximately half-sized
    # recalled scope, while a dispersed medoid set expands only as much as is
    # necessary to preserve all archetypes.  Three-level variables remain
    # incompressible.  As with centred zooming, a boundary medoid is not clipped:
    # the shared recalled window may extend beyond the previously experienced
    # source boundary while retaining the same source-grid step.
    my %counts = %{ $cfg->{varinumbers} };
    my %medium = %{ $cfg->{mediumiters} };
    my (%ops, %axes, %bounds);

    for my $v (@vars) {
        my $L = 0 + $cfg->{varinumbers}{$v};
        my $nominal = memory_level_count($L);
        my @ml = sort { $a <=> $b } map { 0 + $_->{$v} } @source_positions;
        my $min_m = $ml[0];
        my $max_m = $ml[-1];
        my $span = $max_m - $min_m + 1;
        my $width = $span > $nominal ? $span : $nominal;
        $width = $L if $width > $L;

        my $extra = $width - $span;
        my $left = int($extra / 2);
        my $right = $extra - $left;
        my $lo = $min_m - $left;
        my $hi = $max_m + $right;

        $counts{$v} = $width;
        $bounds{$v} = { source_low => $lo, source_high => $hi };

        my $op = _extract_operation($cfg->{text}, $v);
        my (@begin, @end);
        if ($L <= 1) {
            @begin = @{ $op->{begin} };
            @end = @{ $op->{end} };
        }
        else {
            @begin = @{ _interp_vec($op->{begin}, $op->{end}, $lo - 1, $L - 1) };
            @end   = @{ _interp_vec($op->{begin}, $op->{end}, $hi - 1, $L - 1) };
        }
        $ops{$v} = {
            %$op,
            child_begin => \@begin,
            child_end   => \@end,
        };
        $axes{$v} = {
            source_levels => $L,
            nominal_memory_levels => $nominal,
            medoid_source_min => $min_m,
            medoid_source_max => $max_m,
            medoid_source_span => $span,
            memory_source_low => $lo,
            memory_source_high => $hi,
            memory_levels => $width,
            compression_limited_by_medoid_span => ($span > $nominal ? JSON::PP::true : JSON::PP::false),
        };
    }

    # Map the actual medoid coordinates into the shared compressed window.
    # This is a pure integer shift on each active axis, so no medoid is rounded,
    # approximated or replaced by a synthetic point.
    my @positions;
    for my $src (@source_positions) {
        my %p = %$src;
        for my $v (@vars) {
            $p{$v} = $src->{$v} - $bounds{$v}{source_low} + 1;
        }
        push @positions, \%p;
    }

    # Start the generated Sim::OPT configuration at the first retained medoid.
    # Explicit starpositions then drive all star centres in the one search.
    for my $v (sort { $a <=> $b } keys %{ $cfg->{mediumiters} }) {
        $medium{$v} = 0 + $positions[0]{$v};
    }

    my $expected_lattice_rows = 1;
    $expected_lattice_rows *= 0 + $counts{$_} for @vars;

    # A multi-star samples, for every retained medoid, each complete coordinate
    # line through that medoid in the active variables.  Count the union exactly.
    my %sample_ids;
    for my $pos (@positions) {
        for my $v (@vars) {
            for my $lev (1 .. (0 + $counts{$v})) {
                my %q = %$pos;
                $q{$v} = $lev;
                $sample_ids{ format_instance(\%q) } = 1;
            }
        }
    }

    return {
        schema => 'Sim::OPT::StructureDesign/memory-reconstruction-plan-3',
        operation => 'reconstruct_memory',
        mode => 'shared_multistar_compressed',
        source_config => $source_config,
        source_dir => $cfg->{mypath},
        source_model_root => $cfg->{file},
        model_root => $memory_root,
        medoids => \@clear_medoids,
        source_starpositions => \@source_positions,
        starpositions => \@positions,
        variables => \@vars,
        child_dir => $child_dir,
        child_config => $child_config,
        lattice_counts => \%counts,
        lattice_medium => \%medium,
        operations => \%ops,
        per_variable_axes => \%axes,
        expected_sample_rows => scalar(keys %sample_ids),
        expected_lattice_rows => $expected_lattice_rows,
        metamodel => 'y',
        convergeintomodel => 'y',
    };
}

sub render_memory_config {
    my ($plan) = @_;
    die "render_memory_config: memory plan required\n"
        unless ref($plan) eq 'HASH'
            && ($plan->{operation} || '') eq 'reconstruct_memory'
            && ($plan->{mode} || '') eq 'shared_multistar_compressed';
    my $cfg = inspect_config($plan->{source_config});
    my $txt = $cfg->{text};
    my $child_dir = $plan->{child_dir};

    my $n = ($txt =~ s/^(?!\s*#)(\s*\$mypath\s*=\s*)["'][^"']+["']/$1"$child_dir"/m);
    die "memory config: could not patch \$mypath\n" unless $n == 1;
    $n = ($txt =~ s/^(?!\s*#)(\s*\$file\s*=\s*)["'][^"']+["']/$1"$plan->{model_root}"/m);
    die "memory config: could not patch \$file\n" unless $n == 1;

    my @vars = @{ $plan->{variables} };
    my $first = $vars[0];
    # With explicit starpositions, the numeric prefix is not used to generate
    # centres.  1> simply selects Sim::OPT's star-search path for this block.
    my $sweep = '@sweeps = ( [ [ ' . _quote_scalar('1>' . $first);
    if (@vars > 1) {
        $sweep .= ', ' . join(' , ', @vars[1 .. $#vars]);
    }
    $sweep .= ' ] ] );';
    $n = ($txt =~ s/^(?!\s*#)\s*\@sweeps\s*=\s*[^;]+;/$sweep/m);
    die "memory config: could not patch active \@sweeps\n" unless $n == 1;

    $txt = _replace_hash_assignment($txt, '@varinumbers', $plan->{lattice_counts});
    $txt = _replace_hash_assignment($txt, '@mediumiters', $plan->{lattice_medium});
    for my $v (@vars) {
        $txt = _patch_operation($txt, $v, $plan->{operations}{$v});
    }

    my $sp = _memory_format_starpositions($plan->{starpositions});
    $txt = _memory_set_dowhat_perl_value($txt, 'starpositions', $sp);
    $txt = _memory_set_dowhat_string($txt, 'names', 'short');
    $txt = _memory_set_dowhat_string($txt, 'metamodel', 'y');
    $txt = _memory_set_dowhat_string($txt, 'convergeintomodel', 'y');

    my $stamp = "# Generated shared compressed multi-star memory reconstruction by Sim::OPT::StructureDesign $VERSION\n"
              . "# Retained medoids become explicit starpositions in one Sim::OPT search.\n"
              . "# Active axes use a shared source-grid window: nominally compressed, enlarged only when needed to contain all medoids exactly.\n"
              . "# Medoids: " . scalar(@{ $plan->{medoids} }) . "\n"
              . "# Expected sampled union: $plan->{expected_sample_rows} rows\n"
              . "# Expected reconstructed lattice: $plan->{expected_lattice_rows} rows\n";
    return $stamp . $txt;
}

sub create_memory_workspace {
    my (%a) = @_;
    my $plan = $a{plan} || plan_memory_reconstruction(%a);
    my $commit = $a{commit} ? 1 : 0;
    return $plan unless $commit;
    my $child_dir = $plan->{child_dir};
    die "create_memory_workspace: refusing to overwrite $child_dir\n" if -e $child_dir;
    my $root_model = $a{root_model_dir} or die "create_memory_workspace: root_model_dir required\n";
    die "create_memory_workspace: root model not found: $root_model\n" unless -d $root_model;

    make_path($child_dir);
    _copy_tree($root_model, "$child_dir/$plan->{model_root}");
    _spit("$child_dir/$plan->{child_config}", render_memory_config($plan));
    write_manifest($plan, "$child_dir/structuredesign-memory-local.json");
    return $plan;
}


1;

__END__

=head1 NAME

Sim::OPT::StructureDesign - explicit transformations of Sim::OPT design lattices

=head1 DESIGN VOCABULARY

=over 4

=item search

Evaluate points on the current design lattice. This remains Sim::OPT's job; this
module records the lattice on which the search is performed.

=item zoom_in

Reduce scope around an incumbent while decreasing grid spacing (increasing
resolution). The local workspace is centred on the incumbent. If the incumbent
is on an old boundary, the refined-global union expands by the fine-grid levels
needed to preserve that centred zoom rather than clipping it to one side.

=item zoom_out

Embed results obtained on a finer local lattice back into a finer global lattice
covering the parent scope. Existing parent levels map by j' = o + 1 + r (j - 1), where o is the coordinate-origin offset introduced only when a centred boundary zoom expands the union.
The resulting global lattice may contain unsampled points (voids).

=item pan

Move the sampled window while preserving its scope and resolution. A pan can be
combined with zooming, but is represented separately in the manifest.

=back

=head1 SAFETY MODEL

Planning is pure and non-destructive. Workspace creation refuses to overwrite an
existing destination. Merge/renaming should be executed only from a validated
manifest; short numeric IDs must be treated as identifiers, never replaced by a
blind text substitution.

=cut
