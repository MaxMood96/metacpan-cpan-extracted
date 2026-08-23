#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;
use Time::HiRes qw(time);
use Getopt::Long qw(GetOptions);
use JSON::PP qw(encode_json);
use File::Path qw(make_path);
use FindBin qw($Bin);
use lib "$Bin/../../blib/lib", "$Bin/../../blib/arch", "$Bin/../../lib";

my $systems = 'phase29,phase31';
my $watchers = '1000,5000,10000,20000';
my $cycles = 5;
my $repeats = 1;
my $out = 'bench/results/watcher-reuse-phase31.html';
my $json_out = 'bench/results/watcher-reuse-phase31.json';
my $build = 0;

GetOptions(
    'systems=s'  => \$systems,
    'watchers=s' => \$watchers,
    'cycles=i'   => \$cycles,
    'repeats=i'  => \$repeats,
    'out=s'      => \$out,
    'json=s'     => \$json_out,
    'build!'     => \$build,
) or die usage();

die "cycles must be > 0\n" unless $cycles > 0;
die "repeats must be > 0\n" unless $repeats > 0;
my @systems = grep length, split /,/, $systems;
my @watchers = map { int($_) } grep length, split /,/, $watchers;
die "watcher counts must be > 0\n" unless @watchers && !grep { $_ <= 0 } @watchers;

if ($build) {
    warn "== building local Linux::Event::Loop module ==\n";
    system($^X, 'Makefile.PL') == 0 or die "Makefile.PL failed\n";
    system('make') == 0 or die "make failed\n";
}

my @results;
for my $system (@systems) {
    die "unknown system '$system'\n" unless $system =~ /\A(?:phase29|phase30|phase31)\z/;
    for my $count (@watchers) {
        for my $rep (1 .. $repeats) {
            warn "== $system watchers=$count cycles=$cycles repeat=$rep ==\n";
            push @results, run_case($system, $count, $cycles, $rep);
        }
    }
}

my @summary = summarize(\@results);
write_json($json_out, { results => \@results, summary => \@summary });
write_html($out, \@results, \@summary);
print "wrote $json_out\n";
print "wrote $out\n";

sub usage {
    return <<'USAGE';
Usage:
  perl bench/run-watcher-reuse-bench.pl --build --systems phase29,phase31 --watchers 1000,5000,10000,20000 --cycles 5 --out bench/results/watcher-reuse-phase31.html --json bench/results/watcher-reuse-phase31.json

This benchmark isolates watcher lifecycle churn.  Each cycle creates N pipe read
watchers, cancels them, and closes the pipes.  Reclaim-capable phases should
show watcher_reuse_calls after the first cycle.
USAGE
}

sub run_case ($system, $count, $cycles, $repeat) {
    require Linux::Event::Loop;
    my $loop = Linux::Event::Loop->new;
    $loop->enable_watcher_reclaim(1) if $system eq 'phase30' || $system eq 'phase31';

    my $created = 0;
    my $cancelled = 0;
    my $start = time;
    for my $cycle (1 .. $cycles) {
        my @items;
        for (1 .. $count) {
            pipe(my $r, my $w) or die "pipe failed: $!";
            $r->blocking(0);
            $w->blocking(0);
            my $watcher = $loop->watch_fd(fileno($r), fh => $r, no_args => 1, lean => 1, read => sub {});
            push @items, [$watcher, $r, $w];
            $created++;
        }
        for my $item (@items) {
            my ($watcher, $r, $w) = @$item;
            $watcher->cancel;
            close $r;
            close $w;
            $cancelled++;
        }
    }
    my $elapsed = time - $start;
    my $st = $loop->stats;
    my %r = (
        system => display_system($system),
        system_key => $system,
        watchers_per_cycle => $count,
        cycles => $cycles,
        repeat => $repeat,
        watcher_creates => $created,
        watcher_cancels => $cancelled,
        elapsed_seconds => 0 + sprintf('%.6f', $elapsed),
        watchers_per_second => $elapsed > 0 ? 0 + sprintf('%.3f', $created / $elapsed) : 0,
        ok => JSON::PP::true,
    );
    for my $key (qw(watcher_alloc_calls watcher_reuse_calls watcher_recycle_calls watcher_destroy_calls watcher_freelist_depth watcher_freelist_max_depth watcher_reclaim_enabled lean_watchers epoll_ctl_add_calls epoll_ctl_del_calls)) {
        $r{$key} = $st->{$key} if exists $st->{$key};
    }
    return \%r;
}

sub display_system ($s) {
    return $s eq 'phase31' ? 'Linux::Event Phase31 XSLoop Reuse'
         : $s eq 'phase30' ? 'Linux::Event Phase30 XSLoop Reclaim'
         : $s eq 'phase29' ? 'Linux::Event Phase29 XSLoop Baseline'
         : $s;
}

sub summarize ($results) {
    my %g;
    for my $r (@$results) {
        push @{ $g{join "\0", $r->{system_key}, $r->{watchers_per_cycle}, $r->{cycles}} }, $r;
    }
    my @out;
    for my $k (sort keys %g) {
        my @rs = @{ $g{$k} };
        my %s = %{ $rs[0] };
        $s{summary} = JSON::PP::true;
        $s{repeats} = scalar @rs;
        for my $field (qw(elapsed_seconds watchers_per_second watcher_alloc_calls watcher_reuse_calls watcher_recycle_calls watcher_freelist_depth watcher_freelist_max_depth)) {
            next unless exists $rs[0]{$field};
            my $sum = 0;
            my $best = $field eq 'elapsed_seconds' ? 9**9**9 : 0;
            for my $r (@rs) {
                $sum += $r->{$field} // 0;
                if ($field eq 'elapsed_seconds') { $best = $r->{$field} if $r->{$field} < $best; }
                else { $best = $r->{$field} if $r->{$field} > $best; }
            }
            $s{"avg_$field"} = 0 + sprintf('%.3f', $sum / @rs);
            $s{"best_$field"} = $best;
        }
        push @out, \%s;
    }
    return @out;
}

sub write_json ($path, $data) {
    if ($path =~ m{^(.+)/[^/]+$}) { make_path($1); }
    open my $fh, '>', $path or die "write $path: $!";
    print {$fh} JSON::PP->new->pretty->canonical->encode($data);
    close $fh;
}

sub write_html ($path, $results, $summary) {
    if ($path =~ m{^(.+)/[^/]+$}) { make_path($1); }
    open my $fh, '>', $path or die "write $path: $!";
    print {$fh} "<!doctype html><html><head><meta charset='utf-8'><title>Linux::Event watcher reuse benchmark</title>\n";
    print {$fh} "<style>body{font-family:system-ui,sans-serif;margin:2rem}table{border-collapse:collapse;width:100%;margin:1rem 0 2rem}th,td{border:1px solid #c9d1d9;padding:.4rem .55rem;text-align:right}th:first-child,td:first-child{text-align:left}th{background:#f0f3f6}.row-phase31{background:#d9fbe8}.row-phase30{background:#e9f7ef}.row-phase29{background:#fff3cd}.note{background:#f6f8fa;border:1px solid #d0d7de;border-radius:8px;padding:1rem}</style></head><body>\n";
    print {$fh} "<h1>Linux::Event watcher reuse benchmark</h1><div class='note'>Creates and cancels N watchers for several cycles. Phase31/Phase30 enable reclaim; Phase29 is the baseline. A useful reclaim path should show reuse calls after cycle 1.</div>\n";
    emit_table($fh, 'Summary', $summary);
    emit_table($fh, 'Raw results', $results);
    print {$fh} "</body></html>\n";
    close $fh;
}

sub emit_table ($fh, $title, $rows) {
    my @cols = qw(system watchers_per_cycle cycles repeats repeat watcher_creates watcher_cancels elapsed_seconds watchers_per_second watcher_alloc_calls watcher_reuse_calls watcher_recycle_calls watcher_freelist_depth watcher_freelist_max_depth watcher_reclaim_enabled epoll_ctl_add_calls epoll_ctl_del_calls ok);
    print {$fh} "<h2>$title</h2><table><thead><tr>" . join('', map { "<th>$_</th>" } @cols) . "</tr></thead><tbody>\n";
    for my $r (@$rows) {
        my $cls = 'row-' . ($r->{system_key} // 'unknown');
        print {$fh} "<tr class='$cls'>";
        for my $c (@cols) {
            my $v = exists $r->{$c} ? $r->{$c} : '';
            $v = $v ? 'true' : 'false' if ref($v) eq 'JSON::PP::Boolean';
            print {$fh} "<td>$v</td>";
        }
        print {$fh} "</tr>\n";
    }
    print {$fh} "</tbody></table>\n";
}
