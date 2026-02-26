use strict;
use warnings;
use Test::More;
use open qw(:std :encoding(utf-8));
use Benchmark qw(timethese timediff :hireswallclock);
use Getopt::Long qw(GetOptions);

GetOptions(\my %opt, 'count|n=i') or die;
$opt{count} //= 100;

use lib '.';
use t::Util;

my $test_md = 't/test.md';

SKIP: {
    skip "$test_md not found", 1 unless -f $test_md;

    my $n = $opt{count};
    my $big_md = _make_big_md($test_md, 10);

    # Estimate time with a single run of each mode
    my $t_nofork = _wallclock(sub { run("'-Mmd::config(table=1,rule=1)' $big_md") });
    my $t_fork   = _wallclock(sub { run("'-Mmd::config(table=1,rule=1,nofork=0)' $big_md") });
    my $est = ($t_nofork + $t_fork) * $n;
    diag "";
    diag sprintf "Benchmark: %d iterations, 10x tables (est. %.0f sec)", $n, $est;

    my $done = 0;
    my $total = $n * 2;
    my $started = time;

    my $progress = sub {
	$done++;
	my $elapsed = time - $started;
	my $remain = $done > 0 ? $elapsed / $done * ($total - $done) : 0;
	printf STDERR "\r  [%d/%d] %.0f sec remaining ...  ", $done, $total, $remain;
    };

    my $result = timethese($n, {
	'nofork' => sub {
	    run("'-Mmd::config(table=1,rule=1)' $big_md");
	    $progress->();
	},
	'fork' => sub {
	    run("'-Mmd::config(table=1,rule=1,nofork=0)' $big_md");
	    $progress->();
	},
    });
    print STDERR "\r" . (" " x 60) . "\r";

    my $nofork_wall = $result->{nofork}[0];
    my $fork_wall   = $result->{fork}[0];
    my $nofork_rate = $nofork_wall > 0 ? $n / $nofork_wall : 0;
    my $fork_rate   = $fork_wall   > 0 ? $n / $fork_wall   : 0;
    my $ratio = $nofork_wall > 0 ? $fork_wall / $nofork_wall : 0;

    diag "";
    diag sprintf "  nofork: %6.3f sec (%5.1f/s)", $nofork_wall, $nofork_rate;
    diag sprintf "  fork:   %6.3f sec (%5.1f/s)", $fork_wall, $fork_rate;
    diag sprintf "  ratio:  %.2fx faster", $ratio;

    unlink $big_md;
    cmp_ok($ratio, '>', 1.0, "nofork is faster than fork");
}

done_testing;

sub _wallclock {
    my $code = shift;
    my $t = Benchmark->new;
    $code->();
    my $elapsed = Benchmark->new;
    timediff($elapsed, $t)->[0];
}

sub _make_big_md {
    my ($src, $repeat) = @_;
    open my $in, '<:utf8', $src or die "$src: $!\n";
    my $content = do { local $/; <$in> };
    close $in;

    my $tmp = "${src}.bench.tmp";
    open my $out, '>:utf8', $tmp or die "$tmp: $!\n";
    print $out $content x $repeat;
    close $out;
    $tmp;
}
