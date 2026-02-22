use strict;
use warnings;
use Test::More;
use open qw(:std :encoding(utf-8));
use Benchmark qw(timethese :hireswallclock);
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
    diag "";
    diag "Benchmark: table formatting, ${n} iterations, 10x tables";

    my $result = timethese($n, {
	'nofork' => sub {
	    run("'-Mmd::config(table=1,rule=1)' $big_md");
	},
	'fork' => sub {
	    run("'-Mmd::config(table=1,rule=1,nofork=0)' $big_md");
	},
    });

    my $nofork_time = $result->{nofork}[0];
    my $fork_time   = $result->{fork}[0];
    my $ratio = $nofork_time > 0 ? $fork_time / $nofork_time : 0;
    diag sprintf "nofork/fork ratio: %.2fx", $ratio;

    unlink $big_md;
    cmp_ok($ratio, '>', 1.0, "nofork is faster than fork");
}

done_testing;

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
