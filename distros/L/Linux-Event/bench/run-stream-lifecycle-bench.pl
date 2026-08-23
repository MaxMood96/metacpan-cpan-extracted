#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use File::Basename qw(dirname);
use File::Path qw(make_path);
use Fcntl qw(F_GETFL F_SETFL O_NONBLOCK);
use FindBin qw($Bin);
use Getopt::Long qw(GetOptions);
use JSON::PP qw(decode_json encode_json);
use POSIX qw(_exit strftime uname);
use Socket qw(AF_UNIX SOCK_STREAM PF_UNSPEC);
use Time::HiRes qw(time clock_gettime CLOCK_PROCESS_CPUTIME_ID);

use Linux::Event::Loop;
use Linux::Event::Stream;

{
    package Linux::Event::Bench::RawNamed;
    use parent 'Linux::Event::Stream';
    sub on_data ($stream, $bytes) { return }
}

{
    package Linux::Event::Bench::FramedMinimal;
    use parent 'Linux::Event::Stream';
    use Linux::Event::Framer 'Delimiter', "\n";
    sub on_message ($stream, $message) { return }
}

{
    package Linux::Event::Bench::FramedFullNamed;
    use parent 'Linux::Event::Stream';
    use Linux::Event::Framer 'Delimiter', "\n";
    sub on_message ($stream, $message) { return }
    sub on_drain ($stream) { return }
    sub on_eof ($stream) { return }
    sub on_error ($stream, $error) { return }
    sub on_close ($stream) { return }
}

my @all_cases = qw(
    registration
    raw-named
    framed-minimal
    framed-full-named
);
my %known_case = map { $_ => 1 } @all_cases;
my @default_cases = @all_cases;

my $contract_version = 2;
my $api_style        = 'loop-add';
my $iterations     = 100_000;
my $pool_size      = 256;
my @live_counts    = (1_000, 10_000, 20_000);
my $warmup         = 1_000;
my $repeats        = 7;
my $memory_repeats = 3;
my @cases          = @default_cases;
my $run_memory     = 1;
my $json_path;
my $help;

GetOptions(
    'api-style=s'      => \$api_style,
    'iterations=i'     => \$iterations,
    'pool=i'           => \$pool_size,
    'live=s'           => sub { @live_counts = split /,/, $_[1] },
    'warmup=i'         => \$warmup,
    'repeats=i'        => \$repeats,
    'memory-repeats=i' => \$memory_repeats,
    'cases=s'          => sub { @cases = split /,/, $_[1] },
    'memory!'          => \$run_memory,
    'json=s'           => \$json_path,
    'help'             => \$help,
) or usage(2);

usage(0) if $help;
die "api-style '$api_style' is not implemented by this source revision\n"
    if $api_style ne 'loop-option' && $api_style ne 'loop-add';
die "iterations must be > 0\n" if $iterations <= 0;
die "pool must be > 0\n" if $pool_size <= 0;
die "warmup must be >= 0\n" if $warmup < 0;
die "repeats must be > 0\n" if $repeats <= 0;
die "memory-repeats must be > 0\n" if $memory_repeats <= 0;
die "at least one case is required\n" if !@cases;
die "unknown case: $_\n" for grep { !$known_case{$_} } @cases;
die "live counts must be > 0\n" for grep { $_ <= 0 } @live_counts;

my $watch_data = {};

my @memory_rows;
my @lifecycle_rows;

say "Linux::Event Stream lifecycle benchmark";
say "version=$Linux::Event::Stream::VERSION perl=$^V pid=$$";
say "contract=$contract_version api_style=$api_style";
say "cases=" . join(',', @cases);

# Run retained-memory cases before lifecycle churn changes the parent's Perl
# allocator high-water mark. Every sample still gets a fresh child process.
if ($run_memory) {
    say "\nLive retained-memory samples";
    for my $count (@live_counts) {
        for my $repeat (1 .. $memory_repeats) {
            for my $case (rotated_cases($repeat)) {
                my $row = run_memory_child($case, $count, $repeat);
                push @memory_rows, $row;
                printf "%s live=%d repeat=%d rss_delta=%.3f MiB approx=%.1f bytes/object\n",
                    $case, $count, $repeat,
                    $row->{rss_delta_kb} / 1024,
                    $row->{approx_bytes_per_object};
            }
        }
    }
}

say "\nLifecycle construction samples";
for my $repeat (1 .. $repeats) {
    for my $case (rotated_cases($repeat)) {
        my $row = run_lifecycle_case($case);
        $row->{repeat} = $repeat;
        push @lifecycle_rows, $row;
        printf "%s repeat=%d %.1f ops/s cpu=%.3f us/op\n",
            $case, $repeat, $row->{operations_per_second},
            $row->{cpu_us_per_operation};
    }
}

my @lifecycle_summary;
say "\nMedian lifecycle construction summary";
printf "%-24s %16s %16s\n", 'case', 'ops/s', 'cpu us/op';
for my $case (@cases) {
    my @set = grep { $_->{case} eq $case } @lifecycle_rows;
    my $summary = {
        benchmark_contract_version => $contract_version,
        api_style => $api_style,
        workload => $case,
        case => $case,
        operations_per_second => median(map { $_->{operations_per_second} } @set),
        cpu_us_per_operation => median(map { $_->{cpu_us_per_operation} } @set),
    };
    push @lifecycle_summary, $summary;
    printf "%-24s %16.1f %16.3f\n", $case,
        $summary->{operations_per_second}, $summary->{cpu_us_per_operation};
}

my @memory_summary;
if ($run_memory) {
    say "\nMedian live retained-memory summary";
    printf "%-24s %10s %16s %18s\n",
        'case', 'objects', 'rss delta MiB', 'approx bytes/object';
    for my $count (@live_counts) {
        for my $case (@cases) {
            my @set = grep {
                $_->{case} eq $case && $_->{objects} == $count
            } @memory_rows;
            my $summary = {
                benchmark_contract_version => $contract_version,
                api_style => $api_style,
                workload => $case,
                case => $case,
                objects => $count,
                rss_delta_kb => median(map { $_->{rss_delta_kb} } @set),
                approx_bytes_per_object => median(
                    map { $_->{approx_bytes_per_object} } @set
                ),
            };
            push @memory_summary, $summary;
            printf "%-24s %10d %16.3f %18.1f\n",
                $case, $count, $summary->{rss_delta_kb} / 1024,
                $summary->{approx_bytes_per_object};
        }
    }
}

if (defined $json_path) {
    my $report = {
        benchmark => 'linux-event-stream-lifecycle',
        benchmark_contract_version => $contract_version,
        api_style => $api_style,
        generated_at => strftime('%Y-%m-%dT%H:%M:%SZ', gmtime),
        environment => environment_info(),
        configuration => {
            iterations => $iterations,
            pool => $pool_size,
            live => \@live_counts,
            warmup => $warmup,
            repeats => $repeats,
            memory_repeats => $memory_repeats,
            cases => \@cases,
            memory_enabled => $run_memory ? JSON::PP::true : JSON::PP::false,
        },
        lifecycle_records => \@lifecycle_rows,
        lifecycle_summary => \@lifecycle_summary,
        memory_records => \@memory_rows,
        memory_summary => \@memory_summary,
        notes => [
            'Socketpairs are created outside timed regions.',
            'Stream subclass descriptors are built during warmup, outside timed regions.',
            'loop-add and loop-option exercise the two supported attachment forms.',
            'RSS deltas include retained Stream/registration state and the references that keep it live.',
            'Compare results only when benchmark_contract_version and workload match.',
        ],
    };

    my $dir = dirname($json_path);
    make_path($dir) if $dir ne '.' && !-d $dir;
    open my $out, '>', $json_path or die "open $json_path: $!\n";
    print {$out} JSON::PP->new->canonical->pretty->encode($report);
    close $out or die "close $json_path: $!\n";
    say "\nWrote $json_path";
}

say "\nUse framed-full-named for the main before/after constructor comparison.";
say "Compare only with contract=2 results for the same workload and settings.";

sub run_lifecycle_case ($case) {
    my $loop = Linux::Event::Loop->new;
    my ($server_fh, $client_fh) = socket_pool($pool_size);

    for my $i (0 .. $warmup - 1) {
        lifecycle_once($case, $loop, $server_fh->[$i % $pool_size], $i);
    }

    my $wall_start = time;
    my $cpu_start = clock_gettime(CLOCK_PROCESS_CPUTIME_ID);
    for my $i (0 .. $iterations - 1) {
        lifecycle_once($case, $loop, $server_fh->[$i % $pool_size], $i);
    }
    my $cpu_seconds = clock_gettime(CLOCK_PROCESS_CPUTIME_ID) - $cpu_start;
    my $elapsed_seconds = time - $wall_start;

    close $_ for @$server_fh;
    close $_ for @$client_fh;

    die "timer produced a non-positive lifecycle interval\n"
        if $elapsed_seconds <= 0;

    return {
        benchmark_contract_version => $contract_version,
        api_style => $api_style,
        workload => $case,
        case => $case,
        operations => $iterations,
        elapsed_seconds => $elapsed_seconds,
        cpu_seconds => $cpu_seconds,
        operations_per_second => $iterations / $elapsed_seconds,
        cpu_us_per_operation => ($cpu_seconds * 1_000_000) / $iterations,
    };
}

sub lifecycle_once ($case, $loop, $fh, $token) {
    my $object = create_object($case, $loop, $fh, $token);
    if ($case eq 'registration') {
        $object->cancel;
    } else {
        my $detached = $object->detach;
        die "detach returned the wrong filehandle\n"
            if fileno($detached) != fileno($fh);
    }
    return;
}

sub create_object ($case, $loop, $fh, $token) {
    if ($case eq 'registration') {
        my $registration = $loop->watch_fd(
            fileno($fh),
            fh => $fh,
            data => $watch_data,
            read => \&_watch_read,
            write => \&_watch_write,
            error => \&_watch_error,
            _callback_data_arg => 1,
        );
        $registration->disable_write;
        return $registration;
    }

    return create_loop_option($case, $loop, $fh)
        if $api_style eq 'loop-option';
    return create_loop_add($case, $loop, $fh)
        if $api_style eq 'loop-add';

    die "unimplemented api-style adapter: $api_style\n";
}

# API ADAPTER: the socket preparation, workload names, timing, teardown, RSS
# measurement, summaries, and JSON contract around this constructor section
# remain unchanged from the object-configured baseline.
sub create_loop_option ($case, $loop, $fh) {

    if ($case eq 'raw-named') {
        return Linux::Event::Bench::RawNamed->new(loop => $loop, fh => $fh);
    }

    if ($case eq 'framed-minimal') {
        return Linux::Event::Bench::FramedMinimal->new(loop => $loop, fh => $fh);
    }

    if ($case eq 'framed-full-named') {
        return Linux::Event::Bench::FramedFullNamed->new(loop => $loop, fh => $fh);
    }

    die "unimplemented case: $case\n";
}

sub create_loop_add ($case, $loop, $fh) {
    my $class = $case eq 'raw-named'
        ? 'Linux::Event::Bench::RawNamed'
        : $case eq 'framed-minimal'
            ? 'Linux::Event::Bench::FramedMinimal'
            : $case eq 'framed-full-named'
                ? 'Linux::Event::Bench::FramedFullNamed'
                : die "unimplemented case: $case\n";
    my $stream = $class->new(fh => $fh);
    return $loop->add($stream);
}

sub run_memory_child ($case, $count, $repeat) {
    pipe(my $reader, my $writer) or die "pipe: $!\n";
    my $pid = fork;
    die "fork: $!\n" if !defined $pid;

    if ($pid == 0) {
        close $reader;
        my $result;
        my $ok = eval {
            my $loop = Linux::Event::Loop->new;
            my ($server_fh, $client_fh) = socket_pool($count);

            # Allocate the retention vector before the baseline so its capacity
            # does not get charged to one implementation more than another.
            my @objects;
            $#objects = $count - 1;

            # Pay one-time XS/Perl allocator and registration initialization
            # before the baseline. The measured delta should describe retained
            # per-object state, not the first registration ever created in a process.
            lifecycle_once($case, $loop, $server_fh->[0], -1);
            my $rss_before_kb = vmrss_kb();
            for my $i (0 .. $count - 1) {
                $objects[$i] = create_object(
                    $case, $loop, $server_fh->[$i], $i
                );
            }
            my $rss_after_kb = vmrss_kb();
            my $delta_kb = $rss_after_kb - $rss_before_kb;
            $result = {
                benchmark_contract_version => $contract_version,
                api_style => $api_style,
                workload => $case,
                case => $case,
                objects => $count,
                repeat => $repeat,
                rss_before_kb => $rss_before_kb,
                rss_after_kb => $rss_after_kb,
                rss_delta_kb => $delta_kb,
                approx_bytes_per_object => ($delta_kb * 1024) / $count,
            };
            1;
        };
        if (!$ok) {
            my $error = $@ || 'unknown child error';
            chomp $error;
            $result = { error => $error };
        }
        print {$writer} encode_json($result), "\n";
        close $writer;
        _exit($ok ? 0 : 1);
    }

    close $writer;
    my $payload = do { local $/; <$reader> // '' };
    close $reader;
    waitpid($pid, 0);
    my $status = $?;
    die "memory child produced no result for $case live=$count\n"
        if $payload eq '';
    my $result = eval { decode_json($payload) };
    die "invalid memory child result for $case live=$count: $@\n" if !$result;
    if ($status != 0 || $result->{error}) {
        my $error = $result->{error} // "exit status $status";
        die "memory case $case live=$count failed: $error\n"
            . "Raise the open-file limit or lower --live if socketpair creation failed.\n";
    }
    return $result;
}

sub socket_pool ($count) {
    my (@server_fh, @client_fh);
    for my $i (0 .. $count - 1) {
        socketpair(my $server, my $client, AF_UNIX, SOCK_STREAM, PF_UNSPEC)
            or die "socketpair $i/$count: $!";
        set_nonblocking($server);
        set_nonblocking($client);
        push @server_fh, $server;
        push @client_fh, $client;
    }
    return (\@server_fh, \@client_fh);
}

sub set_nonblocking ($fh) {
    my $flags = fcntl($fh, F_GETFL, 0);
    die "fcntl(F_GETFL): $!\n" if !defined $flags;
    fcntl($fh, F_SETFL, $flags | O_NONBLOCK)
        or die "fcntl(F_SETFL): $!\n";
}

sub vmrss_kb () {
    open my $status, '<', '/proc/self/status'
        or die "open /proc/self/status: $!\n";
    while (my $line = <$status>) {
        return 0 + $1 if $line =~ /^VmRSS:\s+(\d+)\s+kB\s*$/;
    }
    die "VmRSS not found in /proc/self/status\n";
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
Usage: perl bench/run-stream-lifecycle-bench.pl [options]

  --api-style=NAME     loop-add (default) or loop-option
  --iterations=N       lifecycle operations per case/repeat (default 100000)
  --pool=N             pre-created socketpairs reused by lifecycle cases (256)
  --live=N,N           retained object counts (1000,10000,20000)
  --warmup=N           untimed lifecycle operations per case (1000)
  --repeats=N          lifecycle repeats (7)
  --memory-repeats=N   fresh-process RSS repeats (3)
  --cases=A,B          selected cases
  --[no-]memory        enable/disable retained-memory measurements
  --json=PATH          write raw records, summaries, and environment as JSON
  --help               show this help

Cases:
  registration           opaque native registration baseline
  raw-named              Stream raw-data mode with a named callback
  framed-minimal         delimiter subclass plus named on_message
  framed-full-named      delimiter subclass plus five named lifecycle callbacks
USAGE
    exit $status;
}

sub _watch_read ($data) { return }
sub _watch_write ($data) { return }
sub _watch_error ($data) { return }
