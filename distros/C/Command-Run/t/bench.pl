#!/usr/bin/env perl

=head1 NAME

bench.pl - Benchmark fork vs nofork vs raw performance in Command::Run

=head1 SYNOPSIS

    perl t/bench.pl              # default: 3 seconds per test
    perl t/bench.pl 1            # 1 second per test (quick)
    perl t/bench.pl 5            # 5 seconds per test (precise)

=head1 DESCRIPTION

Compares fork, nofork, and raw execution paths for code references
with varying data sizes.

Each variant runs in a B<separate child process> to avoid
cross-contamination.  Repeated use of C<:encoding(utf8)> causes
cumulative PerlIO performance degradation within a process, which
would unfairly penalize variants measured later.  Separate processes
ensure each measurement starts from a clean state.

Uses wall clock time to avoid issues with fork's high sys time
inflating CPU-based timers.

=cut

use strict;
use warnings;
use lib "lib";
use Benchmark qw(cmpthese timestr);
use Time::HiRes qw(time);
use POSIX qw(_exit);

$| = 1;

my $duration = shift // 3;  # wall clock seconds per test

# Run a benchmark in a child process, return Benchmark-compatible arrayref.
# Avoids PerlIO state contamination between variants.
sub bench_in_child {
    my ($seconds, $setup, $loop) = @_;
    pipe(my $rd, my $wr) or die "pipe: $!\n";
    my $pid = fork // die "fork: $!\n";
    if ($pid == 0) {
        close $rd;
        # Build environment in child
        my $ctx = $setup->();
        my $code = $loop->($ctx);
        # Warm up
        $code->();
        # Measure
        my $end = time() + $seconds;
        my $t0 = Benchmark->new;
        my $count = 0;
        while (time() < $end) {
            $code->();
            $count++;
        }
        my $t1 = Benchmark->new;
        # Send result: wall real usr sys cusr csys count
        my @t0 = @$t0;
        my @t1 = @$t1;
        printf $wr "%s\n", join("\t",
            $t1[0] - $t0[0],   # real
            $t1[1] - $t0[1],   # usr
            $t1[2] - $t0[2],   # sys
            $t1[3] - $t0[3],   # cusr
            $t1[4] - $t0[4],   # csys
            $count,
        );
        close $wr;
        _exit(0);
    }
    close $wr;
    my $line = <$rd>;
    close $rd;
    waitpid $pid, 0;
    chomp $line;
    my @vals = split /\t/, $line;
    # Return Benchmark-compatible arrayref: [real, usr, sys, cusr, csys, count]
    return bless \@vals, 'Benchmark';
}

my @tests;

# output only: 100B, 1KB, 10KB, 100KB
for my $size (100, 1000, 10000, 100000) {
    my $label = $size >= 1000 ? ($size/1000)."KB" : $size."B";
    my $setup = sub {
        require Command::Run;
        my $data = "x" x $size;
        my $r = Command::Run->new(command => sub { print $data });
        return { r => $r, data => $data };
    };
    push @tests, [ "out $label",
        fork   => [$setup, sub { my $c = shift; sub { $c->{r}->run } }],
        nofork => [$setup, sub { my $c = shift; sub { $c->{r}->run(nofork => 1) } }],
        raw    => [$setup, sub { my $c = shift; sub { $c->{r}->run(nofork => 1, raw => 1) } }],
    ];
}

# with stdin: 100B, 1KB, 10KB
for my $size (100, 1000, 10000) {
    my $label = $size >= 1000 ? ($size/1000)."KB" : $size."B";
    my $setup = sub {
        require Command::Run;
        my $input = "x" x $size;
        my $r = Command::Run->new(
            command => sub { my $in = do { local $/; <STDIN> }; print $in },
        );
        return { r => $r, input => $input };
    };
    push @tests, [ "in+out $label",
        fork   => [$setup, sub { my $c = shift; sub { $c->{r}->run(stdin => $c->{input}) } }],
        nofork => [$setup, sub { my $c = shift; sub { $c->{r}->run(nofork => 1, stdin => $c->{input}) } }],
        raw    => [$setup, sub { my $c = shift; sub { $c->{r}->run(nofork => 1, raw => 1, stdin => $c->{input}) } }],
    ];
}

# UTF-8 with stdin: 1KB, 10KB
for my $size (1000, 10000) {
    my $label = $size >= 1000 ? ($size/1000)."KB" : $size."B";
    my $setup = sub {
        require Command::Run;
        my $input = "\x{3042}" x int($size / 3);  # U+3042 "あ", 3 bytes
        my $r = Command::Run->new(
            command => sub { my $in = do { local $/; <STDIN> }; print $in },
        );
        return { r => $r, input => $input };
    };
    push @tests, [ "utf8 $label",
        fork   => [$setup, sub { my $c = shift; sub { $c->{r}->run(stdin => $c->{input}) } }],
        nofork => [$setup, sub { my $c = shift; sub { $c->{r}->run(nofork => 1, stdin => $c->{input}) } }],
        raw    => [$setup, sub { my $c = shift; sub { $c->{r}->run(nofork => 1, raw => 1, stdin => $c->{input}) } }],
    ];
}

my $total = scalar @tests;

for my $i (0 .. $#tests) {
    my ($label, %specs) = @{$tests[$i]};
    printf "[%d/%d] %s: ", $i + 1, $total, $label;
    my %result;
    for my $name (sort keys %specs) {
        print "$name..";
        my ($setup, $loop) = @{$specs{$name}};
        $result{$name} = bench_in_child($duration, $setup, $loop);
        print "done ";
    }
    print "\n";
    cmpthese(\%result);
    print "\n";
}
