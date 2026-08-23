#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use File::Basename qw(dirname);
use File::Path qw(make_path);
use FindBin qw($Bin);
use Getopt::Long qw(GetOptions);
use JSON::PP ();
use POSIX qw(strftime uname);
use Socket qw(AF_UNIX SOCK_STREAM PF_UNSPEC);
use Time::HiRes qw(time clock_gettime CLOCK_PROCESS_CPUTIME_ID);

use Linux::Event::Loop;
use Linux::Event::Stream;

{
    package Linux::Event::Bench::Transition::RawA;
    use parent 'Linux::Event::Stream';
    sub on_data ($stream, $bytes) { return }
}

{
    package Linux::Event::Bench::Transition::RawB;
    use parent 'Linux::Event::Stream';
    sub on_data ($stream, $bytes) { return }
}

{
    package Linux::Event::Bench::Transition::Delimiter;
    use parent 'Linux::Event::Stream';
    use Linux::Event::Framer 'Delimiter', "\n";
    sub on_message ($stream, $message) { return }
}

{
    package Linux::Event::Bench::Transition::Fixed;
    use parent 'Linux::Event::Stream';
    use Linux::Event::Framer 'Fixed', size => 64;
    sub on_message ($stream, $message) { return }
}

my %case_classes = (
    'raw-raw'       => [
        'Linux::Event::Bench::Transition::RawA',
        'Linux::Event::Bench::Transition::RawB',
    ],
    'framed-framed' => [
        'Linux::Event::Bench::Transition::Delimiter',
        'Linux::Event::Bench::Transition::Fixed',
    ],
    'raw-framed'    => [
        'Linux::Event::Bench::Transition::RawA',
        'Linux::Event::Bench::Transition::Delimiter',
    ],
);

my $contract_version = 1;
my $iterations = 1_000_000;
my $pool_size = 256;
my $warmup = 10_000;
my $repeats = 7;
my @cases = qw(raw-raw framed-framed raw-framed);
my $json_path;
my $help;

GetOptions(
    'iterations=i' => \$iterations,
    'pool=i'       => \$pool_size,
    'warmup=i'     => \$warmup,
    'repeats=i'    => \$repeats,
    'cases=s'      => sub { @cases = split /,/, $_[1] },
    'json=s'       => \$json_path,
    'help'         => \$help,
) or usage(2);

usage(0) if $help;
die "iterations must be > 0\n" if $iterations <= 0;
die "pool must be > 0\n" if $pool_size <= 0;
die "warmup must be >= 0\n" if $warmup < 0;
die "repeats must be > 0\n" if $repeats <= 0;
die "at least one case is required\n" if !@cases;
die "unknown case: $_\n" for grep { !exists $case_classes{$_} } @cases;

say 'Linux::Event Stream protocol-transition benchmark';
say "version=$Linux::Event::Stream::VERSION perl=$^V pid=$$";
say "contract=$contract_version cases=" . join(',', @cases);

my @records;
for my $repeat (1 .. $repeats) {
    for my $case (rotated_cases($repeat)) {
        my $row = run_case($case);
        $row->{repeat} = $repeat;
        push @records, $row;
        printf "%s repeat=%d %.1f transitions/s cpu=%.3f us/transition\n",
            $case, $repeat, $row->{transitions_per_second},
            $row->{cpu_us_per_transition};
    }
}

my @summary;
say "\nMedian protocol-transition summary";
printf "%-18s %20s %20s\n",
    'case', 'transitions/s', 'cpu us/transition';
for my $case (@cases) {
    my @set = grep { $_->{case} eq $case } @records;
    my $row = {
        benchmark_contract_version => $contract_version,
        case => $case,
        transitions_per_second => median(map { $_->{transitions_per_second} } @set),
        cpu_us_per_transition => median(map { $_->{cpu_us_per_transition} } @set),
    };
    push @summary, $row;
    printf "%-18s %20.1f %20.3f\n", $case,
        $row->{transitions_per_second}, $row->{cpu_us_per_transition};
}

if (defined $json_path) {
    my $report = {
        benchmark => 'linux-event-stream-transition',
        benchmark_contract_version => $contract_version,
        generated_at => strftime('%Y-%m-%dT%H:%M:%SZ', gmtime),
        environment => environment_info(),
        configuration => {
            iterations => $iterations,
            pool => $pool_size,
            warmup => $warmup,
            repeats => $repeats,
            cases => \@cases,
        },
        records => \@records,
        summary => \@summary,
        notes => [
            'Every timed operation changes one live Stream to the other class.',
            'The fd, watcher, XSState, output queue, lifecycle, and data are retained.',
            'No input is supplied, so results isolate descriptor and read-buffer changes.',
            'raw-raw replaces raw scratch storage; framed-framed needs no raw scratch storage.',
            'raw-framed alternates raw scratch allocation and release.',
        ],
    };

    my $dir = dirname($json_path);
    make_path($dir) if $dir ne '.' && !-d $dir;
    open my $out, '>', $json_path or die "open $json_path: $!\n";
    print {$out} JSON::PP->new->canonical->pretty->encode($report);
    close $out or die "close $json_path: $!\n";
    say "\nWrote $json_path";
}

sub run_case ($case) {
    my ($class_a, $class_b) = @{ $case_classes{$case} };
    my $loop = Linux::Event::Loop->new;
    my (@streams, @peers);

    for my $i (0 .. $pool_size - 1) {
        socketpair(my $stream_fh, my $peer_fh,
            AF_UNIX, SOCK_STREAM, PF_UNSPEC) or die "socketpair $i: $!";
        push @streams, $class_a->new(loop => $loop, fh => $stream_fh);
        push @peers, $peer_fh;
    }

    transition_many(\@streams, $class_a, $class_b, $warmup);

    my $wall_start = time;
    my $cpu_start = clock_gettime(CLOCK_PROCESS_CPUTIME_ID);
    transition_many(\@streams, $class_a, $class_b, $iterations);
    my $cpu_seconds = clock_gettime(CLOCK_PROCESS_CPUTIME_ID) - $cpu_start;
    my $elapsed_seconds = time - $wall_start;

    for my $stream (@streams) {
        my $fh = $stream->detach;
        close $fh;
    }
    close $_ for @peers;

    die "timer produced a non-positive transition interval\n"
        if $elapsed_seconds <= 0;
    return {
        benchmark_contract_version => $contract_version,
        case => $case,
        transitions => $iterations,
        elapsed_seconds => $elapsed_seconds,
        cpu_seconds => $cpu_seconds,
        transitions_per_second => $iterations / $elapsed_seconds,
        cpu_us_per_transition => ($cpu_seconds * 1_000_000) / $iterations,
    };
}

sub transition_many ($streams, $class_a, $class_b, $count) {
    for my $i (0 .. $count - 1) {
        my $stream = $streams->[$i % @$streams];
        my $target = ref($stream) eq $class_a ? $class_b : $class_a;
        $stream->transition_to($target);
    }
}

sub rotated_cases ($repeat) {
    my $shift = ($repeat - 1) % @cases;
    return (@cases[$shift .. $#cases], @cases[0 .. $shift - 1]);
}

sub median (@values) {
    die "median requires at least one value\n" if !@values;
    @values = sort { $a <=> $b } @values;
    my $middle = int(@values / 2);
    return $values[$middle] if @values % 2;
    return ($values[$middle - 1] + $values[$middle]) / 2;
}

sub environment_info () {
    my ($sysname, $nodename, $release, $version, $machine) = uname();
    return {
        linux_event_version => $Linux::Event::Stream::VERSION,
        perl_version => "$^V",
        perl_executable => $^X,
        os => $^O,
        uname => {
            sysname => $sysname,
            release => $release,
            version => $version,
            machine => $machine,
        },
        git_commit => git_commit(),
    };
}

sub git_commit () {
    return undef if !-e "$Bin/../.git";
    open my $git, '-|', 'git', '-C', "$Bin/..", 'rev-parse', 'HEAD'
        or return undef;
    my $commit = <$git>;
    my $ok = close $git;
    return undef if !$ok || !defined $commit;
    chomp $commit;
    return $commit;
}

sub usage ($status) {
    my $fh = $status ? *STDERR : *STDOUT;
    print {$fh} <<'USAGE';
Usage: perl bench/run-stream-transition-bench.pl [options]

  --iterations=N       transitions per case/repeat (default 1000000)
  --pool=N             live Streams cycled by the benchmark (default 256)
  --warmup=N           untimed transitions per case (default 10000)
  --repeats=N          repeats per case (default 7)
  --cases=A,B          raw-raw,framed-framed,raw-framed
  --json=PATH          write raw records, summaries, and environment as JSON
  --help               show this help
USAGE
    exit $status;
}
