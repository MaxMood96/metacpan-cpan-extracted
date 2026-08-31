package Sim::OPT::ClusterMedoid;

# Sim::OPT::ClusterMedoid clusters discrete simulation/design instances and
# identifies one observed medoid instance for each cluster.
#
# Copyright (C) 2008-2025 by Gian Luca Brunetti, gianluca.brunetti@gmail.com. This software is distributed under a dual licence, open-source (GPL v3) and proprietary. The present copy is GPL. By consequence, this is free software.  You can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3.
# gianluca.brunetti@gmail.com.
# This software is distributed under a dual licence, open-source (GPL v3)
# and proprietary. The present copy is GPL. By consequence, this is free
# software. You can redistribute it and/or modify it under the terms of the
# GNU General Public License as published by the Free Software Foundation,
# version 3.

use strict;
use warnings;
use feature 'say';
use Exporter 'import';
use File::Basename qw(dirname);
use File::Path qw(make_path);
use File::Spec;
use List::Util qw(min max);
use Text::CSV;

our @EXPORT = qw(cluster_medoid);
our @EXPORT_OK = qw(cluster_medoid run_cli);
our $VERSION = '0.005';
our $ABSTRACT = 'Cluster discrete Sim::OPT problem landscapes with a hybrid arithmetic-geometric similarity and identify representative medoid instances.';

sub cluster_medoid {
    my (%args) = @_;

    my $config_file = $args{search_config} // $args{config_file};
    my $results_file = $args{results_file};
    my $output_prefix = $args{output_prefix};

    die "cluster_medoid requires search_config => FILE\n"
        unless defined($config_file) && length($config_file);
    die "cluster_medoid requires results_file => FILE\n"
        unless defined($results_file) && length($results_file);

    my $self = bless {
        verbose => $args{verbose} ? 1 : 0,
    }, __PACKAGE__;

    return $self->_run($config_file, $results_file, $output_prefix);
}

sub run_cli {
    my (@argv) = @_ ? @_ : @ARGV;
    my ($config_file, $results_file, $output_prefix) = @argv;

    die "Usage: simopt-clustermedoid SEARCH_CONFIG.pl RESULTS.csv [OUTPUT_PREFIX]\n"
        unless defined($config_file) && defined($results_file);

    my $res = cluster_medoid(
        search_config => $config_file,
        results_file  => $results_file,
        output_prefix => $output_prefix,
        verbose       => 1,
    );

    say "rows: $res->{rows}";
    say "instance prefix: $res->{instance_prefix}";
    say "performance column: $res->{performance_column}";
    say "fixed variables: " . (@{$res->{fixed_variables}} ? join(',', @{$res->{fixed_variables}}) : '(none)');
    say "context variables: " . (@{$res->{context_variables}} ? join(',', @{$res->{context_variables}}) : '(none)');
    say "problem variables: " . join(',', @{$res->{problem_variables}});
    say "lambda: $res->{lambda}";
    say "clusters: $res->{clusters}";
    say "silhouette: " . sprintf('%.6f', $res->{silhouette});
    say "clustered: $res->{files}{clustered}";
    say "medoids: $res->{files}{medoids}";
    say "silhouette scores: $res->{files}{silhouette}";
    say "info: $res->{files}{info}";

    return $res;
}

sub _run {
    my ($self, $config_file, $results_file, $output_prefix) = @_;

    $config_file  = File::Spec->rel2abs($config_file);
    $results_file = File::Spec->rel2abs($results_file);

    my $loaded = $self->_load_search_config($config_file);
    my $cfg = $loaded->{landscapecluster};

    my $mypath = $loaded->{mypath};
    my $root_file = $loaded->{file};
    die "Search config must define \$mypath\n" unless defined($mypath) && length($mypath);
    die "Search config must define \$file\n" unless defined($root_file) && length($root_file);

    my $instance_prefix = File::Spec->catfile($mypath, $root_file);
    $instance_prefix =~ s{/+}{/}g;
    $self->{instance_prefix} = $instance_prefix;

    my $sweep_index = exists($cfg->{sweep_index}) ? int($cfg->{sweep_index}) : 0;
    die "sweep_index must be >= 0\n" if $sweep_index < 0;
    die "No \@varinumbers entry $sweep_index exists in search config\n"
        unless defined $loaded->{varinumbers}[$sweep_index];

    my $levels_cfg = $loaded->{varinumbers}[$sweep_index];
    die "\@varinumbers[$sweep_index] must be a hash reference\n"
        unless ref($levels_cfg) eq 'HASH' && keys %$levels_cfg;

    my %levels;
    for my $k (keys %$levels_cfg) {
        die "Variable id '$k' is not an integer\n" unless $k =~ /^\d+$/;
        my $L = 0 + $levels_cfg->{$k};
        die "Variable $k must have at least 1 level\n" if $L < 1;
        $levels{0 + $k} = $L;
    }
    my @variable_ids = sort { $a <=> $b } keys %levels;
    my %known = map { $_ => 1 } @variable_ids;

    # Variables may be fixed at a non-1 coordinate after StructureDesign
    # re-embedding.  Preserve the historical one-level rule, and allow an
    # explicit fixed_levels map for fixed coordinates on a larger lattice.
    my %fixed_level = map { $_ => 1 } grep { $levels{$_} == 1 } @variable_ids;
    if (exists $cfg->{fixed_levels}) {
        die "fixed_levels must be a hash\n" unless ref($cfg->{fixed_levels}) eq 'HASH';
        for my $k (keys %{$cfg->{fixed_levels}}) {
            die "Fixed variable id '$k' is not an integer\n" unless $k =~ /^\d+$/;
            my $v = 0 + $k;
            die "Fixed variable $v is not present in \@varinumbers[$sweep_index]\n" unless $known{$v};
            my $lev = $cfg->{fixed_levels}{$k};
            die "Fixed level for variable $v must be an integer\n" unless defined($lev) && "$lev" =~ /^\d+$/;
            $lev = 0 + $lev;
            die "Fixed level for variable $v is outside 1..$levels{$v}\n"
                if $lev < 1 || $lev > $levels{$v};
            if ($levels{$v} == 1 && $lev != 1) {
                die "One-level variable $v can only be fixed at level 1\n";
            }
            $fixed_level{$v} = $lev;
        }
    }
    my @fixed = grep { exists $fixed_level{$_} } @variable_ids;
    my @metric_variable_ids = grep { !exists $fixed_level{$_} } @variable_ids;

    my @context_requested = (ref($cfg->{context_variables}) eq 'ARRAY')
        ? map { 0 + $_ } @{$cfg->{context_variables}}
        : ();
    my %seen_context;
    for my $v (@context_requested) {
        die "Context variable $v is not present in \@varinumbers[$sweep_index]\n" unless $known{$v};
        die "Context variable $v is listed more than once\n" if $seen_context{$v}++;
    }
    my %is_context_requested = map { $_ => 1 } @context_requested;
    # One-level variables are valid Sim::OPT coordinates but carry no distance
    # information.  Keep them for row validation/output and omit them only
    # from the similarity metric.
    my @context = grep { !exists $fixed_level{$_} } @context_requested;
    my %is_context = map { $_ => 1 } @context;
    my @problem = grep { !exists $fixed_level{$_} && !$is_context_requested{$_} } @variable_ids;

    my $lambda = exists($cfg->{lambda}) ? 0 + $cfg->{lambda} : 0.5;
    die "lambda must be between 0 and 1\n" if $lambda < 0 || $lambda > 1;

    my %variable_weight = map { $_ => 1.0 } @metric_variable_ids;
    if (exists $cfg->{variable_weights}) {
        die "variable_weights must be a hash\n" unless ref($cfg->{variable_weights}) eq 'HASH';
        for my $v (@metric_variable_ids) {
            my $w = exists($cfg->{variable_weights}{$v}) ? 0 + $cfg->{variable_weights}{$v}
                  : exists($cfg->{variable_weights}{"$v"}) ? 0 + $cfg->{variable_weights}{"$v"}
                  : 1.0;
            die "Weight for variable $v must be > 0\n" if $w <= 0;
            $variable_weight{$v} = $w;
        }
    }

    my %component_weight = (context => 1.0, problem => 1.0, performance => 1.0);
    if (exists $cfg->{component_weights}) {
        die "component_weights must be a hash\n" unless ref($cfg->{component_weights}) eq 'HASH';
        for my $name (qw(context problem performance)) {
            next unless exists $cfg->{component_weights}{$name};
            my $w = 0 + $cfg->{component_weights}{$name};
            die "component_weights.$name must be > 0\n" if $w <= 0;
            $component_weight{$name} = $w;
        }
    }

    my $combination_col_spec = exists($cfg->{combination_column}) ? $cfg->{combination_column} : 0;
    my $performance_col_spec = exists($cfg->{performance_column}) ? $cfg->{performance_column} : -4;

    my $pcfg = (ref($cfg->{performance}) eq 'HASH') ? $cfg->{performance} : {};
    my $divisions = exists($pcfg->{divisions}) ? int($pcfg->{divisions}) : 100;
    die "performance.divisions must be >= 1\n" if $divisions < 1;

    my $ccfg = (ref($cfg->{clustering}) eq 'HASH') ? $cfg->{clustering} : {};
    my $max_iterations = exists($ccfg->{max_iterations}) ? int($ccfg->{max_iterations}) : 50;
    die "clustering.max_iterations must be >= 1\n" if $max_iterations < 1;

    my $csv = Text::CSV->new({ binary => 1, auto_diag => 1 });
    open my $fh, '<', $results_file or die "Cannot open $results_file: $!\n";
    my @raw;
    while (my $r = $csv->getline($fh)) {
        push @raw, [@$r];
    }
    close $fh;
    die "Dataset is empty\n" unless @raw;

    my $header_mode = exists($cfg->{header}) ? $cfg->{header} : 'auto';
    my $has_header;
    if (!ref($header_mode) && $header_mode eq 'auto') {
        my $r = $raw[0];
        my $pidx = _resolve_column_index($performance_col_spec, scalar(@$r), 'performance_column', 1);
        $has_header = _is_number($r->[$pidx]) ? 0 : 1;
    } else {
        $has_header = $header_mode ? 1 : 0;
    }
    my $header = $has_header ? shift @raw : undef;
    die "No data rows after header\n" unless @raw;

    my @rows;
    for my $i (0 .. $#raw) {
        my $fields = $raw[$i];
        my $csv_row = $i + 1 + ($has_header ? 1 : 0);
        my $nf = scalar @$fields;
        my $combination_col = _resolve_column_index($combination_col_spec, $nf, 'combination_column', $csv_row);
        my $performance_col = _resolve_column_index($performance_col_spec, $nf, 'performance_column', $csv_row);

        die "Non-numeric performance at CSV row $csv_row, column $performance_col_spec: '$fields->[$performance_col]'\n"
            unless _is_number($fields->[$performance_col]);

        my $combo = $self->_parse_combo($fields->[$combination_col], $csv_row);
        my %present = map { $_ => 1 } keys %$combo;
        my @missing = grep { !$present{$_} } @variable_ids;
        my @extra = grep { !$known{$_} } keys %$combo;
        die "CSV row $csv_row variable mismatch; missing=[@missing], extra=[@extra]\n"
            if @missing || @extra;

        for my $v (@variable_ids) {
            my $lev = $combo->{$v};
            die "CSV row $csv_row: variable $v has level $lev outside 1..$levels{$v}\n"
                if $lev < 1 || $lev > $levels{$v};
            if (exists $fixed_level{$v} && $lev != $fixed_level{$v}) {
                die "CSV row $csv_row: fixed variable $v has level $lev; expected $fixed_level{$v}\n";
            }
        }

        push @rows, {
            fields      => $fields,
            combo_text  => $fields->[$combination_col],
            combo       => $combo,
            performance => 0 + $fields->[$performance_col],
            csv_row     => $csv_row,
        };
    }

    my $n = scalar @rows;
    my @performances = map { $_->{performance} } @rows;
    my $pbest = exists($pcfg->{best}) ? 0 + $pcfg->{best} : min(@performances);
    my $pworst = exists($pcfg->{worst}) ? 0 + $pcfg->{worst} : max(@performances);
    my $pspan = abs($pworst - $pbest);
    my $pstep = $pspan > 0 ? $pspan / $divisions : 0;

    my %var_sim;
    for my $v (@metric_variable_ids) {
        my $L = $levels{$v};
        my @s;
        for my $delta (0 .. $L - 1) {
            my $d = log(1 + $delta) / log($L);
            $d = _clamp01($d);
            push @s, _clamp01(1 - $d);
        }
        $var_sim{$v} = \@s;
    }

    my %perf_similarity_cache;
    my $hybrid = sub {
        my ($values, $weights) = @_;
        return _hybrid_from_values($values, $weights, $lambda);
    };

    my $group_similarity = sub {
        my ($a, $b, $vars) = @_;
        my (@s, @w);
        for my $v (@$vars) {
            my $delta = abs($a->{combo}{$v} - $b->{combo}{$v});
            push @s, $var_sim{$v}[$delta];
            push @w, $variable_weight{$v};
        }
        return $hybrid->(\@s, \@w);
    };

    my $performance_similarity = sub {
        my ($a, $b) = @_;
        return 1 if $pspan == 0;
        my $diff = abs($a->{performance} - $b->{performance});
        return 1 if $diff == 0;
        my $key = sprintf('%.12g', $diff);
        return $perf_similarity_cache{$key} if exists $perf_similarity_cache{$key};
        my $steps = $pstep > 0 ? $diff / $pstep : 0;
        $steps = $divisions if $steps > $divisions;
        my $d = log(1 + $steps) / log(1 + $divisions);
        my $s = _clamp01(1 - $d);
        $perf_similarity_cache{$key} = $s;
        return $s;
    };

    my $overall_similarity = sub {
        my ($a, $b) = @_;
        my (@s, @w);
        if (@context) {
            push @s, $group_similarity->($a, $b, \@context);
            push @w, $component_weight{context};
        }
        if (@problem) {
            push @s, $group_similarity->($a, $b, \@problem);
            push @w, $component_weight{problem};
        }
        push @s, $performance_similarity->($a, $b);
        push @w, $component_weight{performance};
        return $hybrid->(\@s, \@w);
    };

    my $DIST_SCALE = 1_000_000_000;
    my $D = "\0" x (4 * $n * $n);
    my @row_sum_q = (0) x $n;
    my $get_q = sub { return vec($D, $_[0] * $n + $_[1], 32); };

    $self->_progress("Building distance matrix for $n rows...");
    for my $i (0 .. $n - 1) {
        for my $j ($i + 1 .. $n - 1) {
            my $d = _clamp01(1 - $overall_similarity->($rows[$i], $rows[$j]));
            my $q = int($d * $DIST_SCALE + 0.5);
            vec($D, $i * $n + $j, 32) = $q;
            vec($D, $j * $n + $i, 32) = $q;
            $row_sum_q[$i] += $q;
            $row_sum_q[$j] += $q;
        }
    }

    my $init_medoids = sub {
        my ($k) = @_;
        my $first = 0;
        for my $i (1 .. $n - 1) {
            $first = $i if $row_sum_q[$i] < $row_sum_q[$first];
        }
        my @medoids = ($first);
        my %is_medoid = ($first => 1);
        while (@medoids < $k) {
            my ($best_i, $best_nearest) = (-1, -1);
            for my $i (0 .. $n - 1) {
                next if $is_medoid{$i};
                my $nearest = $get_q->($i, $medoids[0]);
                for my $m (@medoids[1 .. $#medoids]) {
                    my $q = $get_q->($i, $m);
                    $nearest = $q if $q < $nearest;
                }
                if ($nearest > $best_nearest) {
                    ($best_i, $best_nearest) = ($i, $nearest);
                }
            }
            push @medoids, $best_i;
            $is_medoid{$best_i} = 1;
        }
        return @medoids;
    };

    my $assign_to_medoids = sub {
        my ($medoids) = @_;
        my @assign;
        for my $i (0 .. $n - 1) {
            my ($best_c, $best_q) = (0, $get_q->($i, $medoids->[0]));
            for my $c (1 .. $#$medoids) {
                my $q = $get_q->($i, $medoids->[$c]);
                if ($q < $best_q || ($q == $best_q && $medoids->[$c] < $medoids->[$best_c])) {
                    ($best_c, $best_q) = ($c, $q);
                }
            }
            $assign[$i] = $best_c;
        }
        return \@assign;
    };

    my $recompute_medoids = sub {
        my ($k, $assign, $old_medoids) = @_;
        my @members;
        push @{$members[$assign->[$_]]}, $_ for 0 .. $n - 1;
        my @new = @$old_medoids;
        for my $c (0 .. $k - 1) {
            next unless defined($members[$c]) && @{$members[$c]};
            my @m = @{$members[$c]};
            my @cost = (0) x @m;
            for my $a (0 .. $#m) {
                for my $b ($a + 1 .. $#m) {
                    my $q = $get_q->($m[$a], $m[$b]);
                    $cost[$a] += $q;
                    $cost[$b] += $q;
                }
            }
            my $best = 0;
            for my $a (1 .. $#m) {
                $best = $a if $cost[$a] < $cost[$best]
                    || ($cost[$a] == $cost[$best] && $m[$a] < $m[$best]);
            }
            $new[$c] = $m[$best];
        }
        return \@new;
    };

    my $fit_kmedoids = sub {
        my ($k) = @_;
        my @medoids = $init_medoids->($k);
        my $assign;
        for my $iter (1 .. $max_iterations) {
            $assign = $assign_to_medoids->(\@medoids);
            my $new = $recompute_medoids->($k, $assign, \@medoids);
            my $changed = 0;
            for my $c (0 .. $k - 1) {
                if ($new->[$c] != $medoids[$c]) { $changed = 1; last; }
            }
            @medoids = @$new;
            last unless $changed;
        }
        $assign = $assign_to_medoids->(\@medoids);
        return (\@medoids, $assign);
    };

    my $sample_indices = sub {
        my ($wanted) = @_;
        return [0 .. $n - 1] if !$wanted || $wanted >= $n;
        return [0] if $wanted == 1;
        my (@idx, %seen);
        for my $t (0 .. $wanted - 1) {
            my $i = int(($t * ($n - 1)) / ($wanted - 1) + 0.5);
            push @idx, $i unless $seen{$i}++;
        }
        return \@idx;
    };

    my $silhouette_score = sub {
        my ($k, $assign, $sample) = @_;
        return 0 if $k <= 1 || $n <= 2;
        my @cluster_size = (0) x $k;
        $cluster_size[$assign->[$_]]++ for 0 .. $n - 1;
        my $indices = $sample_indices->($sample);
        my $total = 0;
        my $counted = 0;
        for my $i (@$indices) {
            my $ci = $assign->[$i];
            next if $cluster_size[$ci] <= 1;
            my @sum_q = (0) x $k;
            for my $j (0 .. $n - 1) {
                next if $j == $i;
                $sum_q[$assign->[$j]] += $get_q->($i, $j);
            }
            my $a = $sum_q[$ci] / ($cluster_size[$ci] - 1);
            my $b;
            for my $c (0 .. $k - 1) {
                next if $c == $ci || $cluster_size[$c] == 0;
                my $avg = $sum_q[$c] / $cluster_size[$c];
                $b = $avg if !defined($b) || $avg < $b;
            }
            next unless defined $b;
            my $den = max($a, $b);
            $total += $den > 0 ? ($b - $a) / $den : 0;
            $counted++;
        }
        return $counted ? $total / $counted : 0;
    };

    my $requested = exists($ccfg->{clusters}) ? $ccfg->{clusters} : 'auto';
    my ($chosen_k, $chosen_medoids, $chosen_assign, $chosen_silhouette);
    my @score_table;

    if (defined($requested) && $requested ne 'auto') {
        my $k = int($requested);
        die "clustering.clusters must be between 1 and $n\n" if $k < 1 || $k > $n;
        $self->_progress("Clustering with k=$k...");
        my ($m, $a) = $fit_kmedoids->($k);
        my $sample = exists($ccfg->{silhouette_sample}) ? int($ccfg->{silhouette_sample}) : 0;
        my $s = $silhouette_score->($k, $a, $sample);
        ($chosen_k, $chosen_medoids, $chosen_assign, $chosen_silhouette) = ($k, $m, $a, $s);
        push @score_table, [$k, $s];
    } else {
        if ($n < 3) {
            my ($m, $a) = $fit_kmedoids->(1);
            ($chosen_k, $chosen_medoids, $chosen_assign, $chosen_silhouette) = (1, $m, $a, 0);
            push @score_table, [1, 0];
        } else {
            my $k_min = exists($ccfg->{k_min}) ? int($ccfg->{k_min}) : 2;
            my $k_max = exists($ccfg->{k_max}) ? int($ccfg->{k_max}) : 12;
            $k_min = 2 if $k_min < 2;
            $k_max = $n - 1 if $k_max >= $n;
            die "clustering.k_min must not exceed clustering.k_max\n" if $k_min > $k_max;
            my $sample = exists($ccfg->{silhouette_sample}) ? int($ccfg->{silhouette_sample}) : min(600, $n);
            my $best_s;
            for my $k ($k_min .. $k_max) {
                $self->_progress("Testing k=$k...");
                my ($m, $a) = $fit_kmedoids->($k);
                my $s = $silhouette_score->($k, $a, $sample);
                push @score_table, [$k, $s];
                if (!defined($best_s) || $s > $best_s + 1e-12) {
                    ($best_s, $chosen_k, $chosen_medoids, $chosen_assign) = ($s, $k, $m, $a);
                }
            }
            $chosen_silhouette = $ccfg->{exact_final_silhouette}
                ? $silhouette_score->($chosen_k, $chosen_assign, 0)
                : $best_s;
        }
    }

    $chosen_medoids = $recompute_medoids->($chosen_k, $chosen_assign, $chosen_medoids);
    my @old_clusters = sort { $chosen_medoids->[$a] <=> $chosen_medoids->[$b] } 0 .. $chosen_k - 1;
    my %new_number;
    $new_number{$old_clusters[$_]} = $_ + 1 for 0 .. $#old_clusters;
    my @labels = map { $new_number{$chosen_assign->[$_]} } 0 .. $n - 1;
    my %medoid_for_cluster = map { $new_number{$_} => $chosen_medoids->[$_] } 0 .. $chosen_k - 1;

    if (!defined $output_prefix || !length $output_prefix) {
        ($output_prefix = $results_file) =~ s/\.[^.]+$//;
        $output_prefix .= @context ? '.context_hybrid' : '.problem_hybrid';
    } else {
        $output_prefix = File::Spec->rel2abs($output_prefix);
    }

    my $out_dir = dirname($output_prefix);
    make_path($out_dir) if defined($out_dir) && length($out_dir) && $out_dir ne '.' && !-d $out_dir;

    my $clustered_path = "$output_prefix.clustered.csv";
    my $medoids_path = "$output_prefix.medoids.csv";
    my $scores_path = "$output_prefix.silhouette.csv";
    my $info_path = "$output_prefix.info.txt";

    my $outcsv = Text::CSV->new({ binary => 1, eol => "\n" });
    open my $cfh, '>', $clustered_path or die "Cannot write $clustered_path: $!\n";
    if ($header) {
        $outcsv->print($cfh, [@$header, 'cluster', 'is_medoid']);
    } else {
        my $nf = scalar @{$rows[0]{fields}};
        $outcsv->print($cfh, [map({"col$_"} 0 .. $nf - 1), 'cluster', 'is_medoid']);
    }
    my %is_medoid_row = map { $_ => 1 } values %medoid_for_cluster;
    for my $i (0 .. $n - 1) {
        $outcsv->print($cfh, [@{$rows[$i]{fields}}, $labels[$i], ($is_medoid_row{$i} ? 1 : 0)]);
    }
    close $cfh;

    open my $mfh, '>', $medoids_path or die "Cannot write $medoids_path: $!\n";
    my %is_fixed = map { $_ => 1 } @fixed;
    my @role_header = map { 'var_' . $_ . '_' . ($is_fixed{$_} ? 'fixed' : ($is_context{$_} ? 'context' : 'problem')) } @variable_ids;
    $outcsv->print($mfh, ['cluster', 'csv_row', 'instance', 'performance', @role_header]);
    my @medoid_records;
    for my $c (sort { $a <=> $b } keys %medoid_for_cluster) {
        my $i = $medoid_for_cluster{$c};
        my $r = $rows[$i];
        $outcsv->print($mfh, [$c, $r->{csv_row}, $r->{combo_text}, $r->{performance}, map {$r->{combo}{$_}} @variable_ids]);
        push @medoid_records, {
            cluster     => $c,
            csv_row     => $r->{csv_row},
            instance    => $r->{combo_text},
            performance => $r->{performance},
            variables   => { %{$r->{combo}} },
        };
    }
    close $mfh;

    open my $sfh, '>', $scores_path or die "Cannot write $scores_path: $!\n";
    $outcsv->print($sfh, ['k', 'silhouette_used_for_selection']);
    for my $x (@score_table) {
        $outcsv->print($sfh, [$x->[0], sprintf('%.10f', $x->[1])]);
    }
    close $sfh;

    my @cluster_size = (0) x ($chosen_k + 1);
    $cluster_size[$_]++ for @labels;
    open my $ifh, '>', $info_path or die "Cannot write $info_path: $!\n";
    say $ifh "search_config=$config_file";
    say $ifh "instance_prefix=$instance_prefix";
    say $ifh "combination_column=$combination_col_spec";
    say $ifh "performance_column=$performance_col_spec";
    say $ifh "rows=$n";
    say $ifh "variables=" . join(',', @variable_ids);
    say $ifh "fixed_variables=" . join(',', @fixed);
    say $ifh "fixed_levels=" . join(',', map { $_ . ':' . $fixed_level{$_} } @fixed);
    say $ifh "context_variables=" . join(',', @context);
    say $ifh "problem_variables=" . join(',', @problem);
    say $ifh "lambda=$lambda";
    say $ifh "performance_best=$pbest";
    say $ifh "performance_worst=$pworst";
    say $ifh "performance_divisions=$divisions";
    say $ifh "variable_distance=log(1+level_difference)/log(number_of_levels)";
    say $ifh "variable_similarity=1-variable_distance";
    say $ifh "group_similarity=(1-lambda)*weighted_arithmetic_mean+lambda*weighted_geometric_mean";
    say $ifh "performance_similarity=1-log(1+performance_difference/step)/log(1+divisions), clipped";
    say $ifh "overall_similarity=hybrid_mean(context_if_any,problem,performance)";
    say $ifh "distance=1-overall_similarity";
    say $ifh "clustering=k_medoids";
    say $ifh "clusters=$chosen_k";
    say $ifh "silhouette=" . sprintf('%.10f', $chosen_silhouette);
    for my $c (1 .. $chosen_k) {
        say $ifh "cluster_${c}_size=$cluster_size[$c]";
        say $ifh "cluster_${c}_medoid_csv_row=$rows[$medoid_for_cluster{$c}]{csv_row}";
    }
    close $ifh;

    return {
        rows               => $n,
        clusters           => $chosen_k,
        silhouette         => 0 + $chosen_silhouette,
        lambda             => $lambda,
        instance_prefix    => $instance_prefix,
        performance_column => $performance_col_spec,
        variables          => [@variable_ids],
        fixed_variables    => [@fixed],
        fixed_levels       => { %fixed_level },
        context_variables  => [@context],
        problem_variables  => [@problem],
        medoids            => \@medoid_records,
        silhouette_scores  => [map { [$_->[0], 0 + $_->[1]] } @score_table],
        files              => {
            clustered => $clustered_path,
            medoids    => $medoids_path,
            silhouette => $scores_path,
            info       => $info_path,
        },
    };
}

sub _load_search_config {
    my ($self, $config_file) = @_;

    {
        no strict 'refs';
        undef ${'Sim::OPT::ClusterMedoid::_SearchConfig::mypath'};
        undef ${'Sim::OPT::ClusterMedoid::_SearchConfig::file'};
        @{'Sim::OPT::ClusterMedoid::_SearchConfig::varinumbers'} = ();
        %{'Sim::OPT::ClusterMedoid::_SearchConfig::landscapecluster'} = ();
    }

    my $rv;
    {
        package Sim::OPT::ClusterMedoid::_SearchConfig;
        no strict;
        no warnings;
        $rv = do $config_file;
    }
    die "Could not read config $config_file: $@ $!\n" if !defined($rv) && ($@ || $!);

    my ($mypath, $file, @varinumbers, %landscapecluster);
    {
        no strict 'refs';
        $mypath = ${'Sim::OPT::ClusterMedoid::_SearchConfig::mypath'};
        $file = ${'Sim::OPT::ClusterMedoid::_SearchConfig::file'};
        @varinumbers = @{'Sim::OPT::ClusterMedoid::_SearchConfig::varinumbers'};
        %landscapecluster = %{'Sim::OPT::ClusterMedoid::_SearchConfig::landscapecluster'};
    }

    return {
        mypath           => $mypath,
        file             => $file,
        varinumbers      => \@varinumbers,
        landscapecluster => \%landscapecluster,
    };
}

sub _parse_combo {
    my ($self, $text, $row_no) = @_;
    die "Undefined instance name at CSV row $row_no\n" unless defined $text;

    my $instance_prefix = $self->{instance_prefix};
    my $suffix;
    my $pos = index($text, $instance_prefix);
    if ($pos >= 0) {
        $suffix = substr($text, $pos + length($instance_prefix));
        $suffix =~ s/^[^0-9]+//;
    } elsif ($text =~ /^\s*((?:\d+-[+-]?\d+)(?:_\d+-[+-]?\d+)+)\s*$/) {
        # Sim::OPT totres files commonly store the clear instance id without
        # the absolute model prefix.  Accept that native representation too.
        $suffix = $1;
    } else {
        die "CSV row $row_no instance '$text' contains neither expected prefix '$instance_prefix' nor a bare clear instance id\n";
    }

    my %out;
    while ($suffix =~ /(?:^|_)(\d+)-([+-]?\d+)(?=_|$)/g) {
        my ($vid, $level) = (0 + $1, 0 + $2);
        die "Variable $vid occurs more than once at CSV row $row_no\n"
            if exists $out{$vid};
        $out{$vid} = $level;
    }

    die "Cannot parse variable combination after '$instance_prefix' at CSV row $row_no: '$text'\n"
        unless %out;
    return \%out;
}

sub _is_number {
    my ($x) = @_;
    return defined($x) && $x =~ /^\s*[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?\s*$/;
}

sub _clamp01 {
    my ($x) = @_;
    return 0 if $x < 0;
    return 1 if $x > 1;
    return $x;
}

sub _resolve_column_index {
    my ($spec, $count, $what, $row_no) = @_;
    die "$what is not defined\n" unless defined $spec;
    die "$what must be an integer; got '$spec'\n" unless "$spec" =~ /^-?\d+$/;
    my $idx = int($spec);
    $idx = $count + $idx if $idx < 0;
    my $where = defined($row_no) ? " at CSV row $row_no" : "";
    die "$what=$spec is outside a row containing $count fields$where\n"
        if $idx < 0 || $idx >= $count;
    return $idx;
}

sub _hybrid_from_values {
    my ($values, $weights, $lambda) = @_;
    die "Internal error: hybrid requires at least one value\n" unless @$values;

    my ($wsum, $asum, $logsum, $zero) = (0, 0, 0, 0);
    for my $i (0 .. $#$values) {
        my $s = _clamp01($values->[$i]);
        my $w = $weights->[$i];
        $wsum += $w;
        $asum += $w * $s;
        if ($s <= 0) {
            $zero = 1;
        } else {
            $logsum += $w * log($s);
        }
    }

    my $A = $asum / $wsum;
    my $G = $zero ? 0 : exp($logsum / $wsum);
    return _clamp01((1 - $lambda) * $A + $lambda * $G);
}

sub _progress {
    my ($self, $message) = @_;
    say STDERR $message if $self->{verbose};
}

1;

__END__

=head1 NAME

Sim::OPT::ClusterMedoid - Hybrid similarity clustering and medoid selection for discrete Sim::OPT problem landscapes.

=head1 SYNOPSIS

  use Sim::OPT::ClusterMedoid;

  my $result = cluster_medoid(
      search_config => 'search2x.pl',
      results_file  => 'search2-report-0-0.csv',
      output_prefix => 'search2-landscape',
  );

  print "clusters: $result->{clusters}\n";
  print "first medoid: $result->{medoids}[0]{instance}\n";

From the shell, after installation:

  simopt-clustermedoid search2x.pl search2-report-0-0.csv search2-landscape

=head1 DESCRIPTION

Sim::OPT::ClusterMedoid partitions a discrete set of simulated or otherwise evaluated instances into clusters and selects one medoid for each cluster. A medoid is an actual observed instance whose total dissimilarity from the other members of its cluster is minimal. It is therefore suitable as a representative instance when an artificial average configuration would not correspond to a valid model.

The module reads the same Perl configuration file used by Sim::OPT. It uses C<$mypath> and C<$file> to recognize the instance names, and it obtains the variable identifiers and their numbers of levels directly from C<@varinumbers>. Clustering-specific options are supplied in C<%landscapecluster>.

Variables may be divided into context variables and problem variables. If C<context_variables> is absent or empty, all non-fixed variables are treated as problem variables. Variables declared with exactly one level are accepted as fixed coordinates.  Re-embedded landscapes may additionally declare C<fixed_levels =E<gt> { variable =E<gt> level, ... }> so that a coordinate fixed at a non-1 global lattice level is validated but omitted from the distance metric. Performance is read from the selected CSV column. Negative column numbers use Perl array semantics, so C<-4> means the fourth column from the end of a row.

=head1 RATIONALE AND DISTANCE CALCULATION

The calculation is designed to avoid two opposite failure modes. A purely arithmetic aggregation is compensatory: a very good match in some components can offset a poor match in another. A pure product is conjunctive but may be too severe: one zero or near-zero component can collapse the whole similarity. Sim::OPT::ClusterMedoid therefore mixes arithmetic and geometric aggregation.

For an ordered discrete variable v having L_v levels, two instances i and j have normalized variable dissimilarity

  d_v(i,j) = log(1 + |l_iv - l_jv|) / log(L_v)

and similarity

  s_v(i,j) = 1 - d_v(i,j).

Thus s_v lies in [0,1]. Equal levels give similarity 1, while the maximum possible level separation gives similarity 0.

Within a semantic group, such as the problem variables or the context variables, the weighted arithmetic similarity is

  A = sum(w_v s_v) / sum(w_v)

and the weighted geometric similarity is

  G = exp( sum(w_v log(s_v)) / sum(w_v) ).

If any positively weighted similarity is zero, G is zero. The group similarity is

  H = (1 - lambda) A + lambda G,

with C<lambda = 0.5> by default. C<lambda = 0> gives a purely arithmetic aggregation; C<lambda = 1> gives a geometric aggregation. Intermediate values trade compensability against conjunctiveness.

Performance is converted to a normalized logarithmic similarity on an analogous virtual level scale. If the performance span is divided into N divisions, one virtual step is

  step = |worst - best| / N.

For performance values y_i and y_j,

  d_y = log(1 + |y_i-y_j|/step) / log(1 + N)
  s_y = 1 - d_y,

with the step difference clipped to N. If best and worst are not specified, the observed minimum and maximum performances are used.

The same arithmetic-geometric hybrid operator is then applied to the available high-level components: context similarity, problem similarity, and performance similarity. The final clustering dissimilarity is

  D(i,j) = 1 - H_overall(i,j).

This module was motivated by the distance-based treatment of discrete design spaces in Sim::OPT::Interlinear, but the present formula is not a literal reimplementation of Interlinear. In the supplied Sim::OPT 0.921 source, Interlinear normalizes level increments by 1/(L-1), combines them with a Pythagorean distance, and then normalizes by the maximum distance. Interlinear's logarithmic option concerns the relaxation/weighting of neighbours. ClusterMedoid retains the logarithmic level mapping developed specifically for this clustering method.

=head1 CLUSTERING

The pairwise dissimilarity matrix is clustered by a pure-Perl k-medoids procedure. Initial medoids are chosen deterministically: first the globally most central observation, then observations that are farthest from the medoids already selected. Instances are assigned to their nearest medoid, and each medoid is repeatedly replaced by the member minimizing the total within-cluster dissimilarity until convergence or C<max_iterations> is reached.

If C<clustering =E<gt> { clusters =E<gt> 'auto' }> is used, candidate values of k are evaluated by the mean silhouette coefficient and the best candidate is retained. Alternatively, a fixed number of clusters may be specified.

=head1 CONFIGURATION

Add a clearly delimited block such as the following to the normal Sim::OPT configuration file:

  ##############################################################################
  ############ SIM::OPT::CLUSTERMEDOID SETTINGS - BEGIN ########################

  %landscapecluster = (
      sweep_index         => 0,
      combination_column  => 0,
      performance_column  => -4,

      # [] means that every variable in @varinumbers is a problem variable.
      # [ 1, 2 ] makes variables 1 and 2 context variables and all remaining
      # variables problem variables.
      context_variables   => [ 1, 2 ],

      # 0 = arithmetic, 1 = geometric, 0.5 = equal hybrid.
      lambda              => 0.5,

      performance => {
          divisions => 100,
          # best  => 60,   # optional; observed minimum is used if omitted
          # worst => 80,   # optional; observed maximum is used if omitted
      },

      clustering => {
          clusters          => 'auto',
          k_min             => 2,
          k_max             => 12,
          max_iterations    => 50,
          silhouette_sample => 600,
      },
  );

  ############ SIM::OPT::CLUSTERMEDOID SETTINGS - END ##########################
  ##############################################################################

C<variable_weights> and C<component_weights> may optionally be added. For example:

  variable_weights => { 1 => 2, 2 => 2, 9 => 0.5 },

  component_weights => {
      context     => 1,
      problem     => 1,
      performance => 1,
  },

All weights must be positive.

=head1 OUTPUT FILES

Four files are written using the requested output prefix:

=over 4

=item * C<.clustered.csv>

The original dataset with appended C<cluster> and C<is_medoid> columns.

=item * C<.medoids.csv>

One row for each cluster, containing the source CSV row, instance name, performance, and variable levels of the medoid.

=item * C<.silhouette.csv>

The candidate k values and the silhouette score used for selection.

=item * C<.info.txt>

A concise record of the metric, configuration, selected number of clusters, silhouette, cluster sizes, and medoid source rows.

=back

=head1 FUNCTION

=head2 cluster_medoid

  my $result = cluster_medoid(
      search_config => $configuration_file,
      results_file  => $csv_file,
      output_prefix => $prefix,       # optional
      verbose       => 1,             # optional
  );

Returns a hash reference containing the selected cluster count, silhouette, medoid records, variable classification, and paths of the files written.

=head2 run_cli

C<run_cli> is exported only on request and implements the installed C<simopt-clustermedoid> command.

=head1 MEMORY AND COMPUTATIONAL COST

The implementation stores the complete pairwise distance matrix. Its memory requirement is therefore O(n^2), and exact medoid updates can also be expensive for large datasets. The method is intended primarily for discrete experimental or simulation landscapes of moderate size, where retaining the actual medoid observations is valuable.

=head1 SEE ALSO

L<Sim::OPT>, L<Sim::OPT::Interlinear>, L<Sim::OPT::Morph>, L<Sim::OPT::Descend>.

=head1 AUTHOR

Gian Luca Brunetti, E<lt>gianluca.brunetti@polimi.itE<gt>

=head1 ACKNOWLEDGEMENTS

The initial design and implementation of ClusterMedoid were
developed by Gian Luca Brunetti with assistance from AI.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008-2025 by Gian Luca Brunetti, gianluca.brunetti@gmail.com. This software is distributed under a dual licence, open-source (GPL v3) and proprietary. The present copy is GPL. By consequence, this is free software.  You can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3.

=cut


# Add this section to a normal Sim::OPT search configuration.
# $mypath, $file and @varinumbers remain defined in their usual places.

################################################################################
############ SIM::OPT::CLUSTERMEDOID SETTINGS - BEGIN ##########################
# EXAMPLE OF ROWS TO BE ADDED INTO A Sim:OPT configuration file
#%landscapecluster = (
#    sweep_index        => 0,
#    combination_column => 0,
#    performance_column => -4,
#
#    # Use [] when there are no context variables.
#    # In this example variables 1 and 2 are context variables; every other
#    # variable in @varinumbers is automatically treated as a problem variable.
#    context_variables  => [ 1, 2 ],
#
#    lambda => 0.5,
#
#    performance => {
#        divisions => 100,
#    },
#
#    clustering => {
#        clusters          => 'auto',
#        k_min             => 2,
#        k_max             => 12,
#        max_iterations    => 50,
#        silhouette_sample => 600,
#    },
#);
#
############ SIM::OPT::CLUSTERMEDOID SETTINGS - END ############################
################################################################################

