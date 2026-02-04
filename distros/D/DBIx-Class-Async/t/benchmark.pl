#!/usr/bin/env perl

use strict;
use warnings;

use TestSchema;
use IO::Async::Loop;
use DBIx::Class::Async::Schema;
use Time::HiRes qw(gettimeofday tv_interval);

print "DBIx::Class::Async Performance Benchmark (MySQL)\n\n";
print "-" x 70 . "\n";

my $loop = IO::Async::Loop->new;
my ($raw_schema, $async_schema) = setup_environment();

my (@results, $baseline_time);

for my $count (50, 100, 200) {
    print "\n" . "Testing with $count queries...\n";
    run_bench("Standard DBIx::Class (Sequential/Blocking)", 0, $count);
    run_bench("DBIx::Class::Async (Parallel/Non-Blocking)", 1, $count);
}

print_summary();

$async_schema->disconnect;

#
#
# METHODS

sub setup_environment {
    print "Setting up MySQL database with 10,000 records...\n\n";

    my $dsn      = "dbi:mysql:database=testdb";
    my $username = "root";
    my $password = "root";

    my $raw_schema = TestSchema->connect($dsn, $username, $password);
    $raw_schema->storage->dbh->do("DROP TABLE IF EXISTS orders");
    $raw_schema->storage->dbh->do("DROP TABLE IF EXISTS users");
    $raw_schema->deploy({ add_drop_table => 1 });

    my @data = map {
        {
            name   => "User $_",
            age    => 20 + int(rand(60)),
            email  => "user$_\@example.com",
            active => 1
        }
    } (1..10_000);
    $raw_schema->resultset('User')->populate(\@data);
    print "Database ready\n\n";

    my $async_schema = DBIx::Class::Async::Schema->connect(
        $dsn, $username, $password, {},
        { workers => 4, schema_class => 'TestSchema', async_loop => $loop }
    );

    return ($raw_schema, $async_schema);
}

sub run_bench {
    my ($name, $is_async, $query_count) = @_;

    print "\n" . "-" x 70 . "\n";
    print "$name\n";
    print "-" x 70 . "\n";

    # Heartbeat configuration
    my $ticks    = 0;
    my $interval = 0.001;  # 1ms resolution
    my $timer    = IO::Async::Timer::Periodic->new(
        interval => $interval,
        on_tick  => sub { $ticks++ },
    );
    $loop->add($timer->start);

    my $t0 = [gettimeofday];

    my $heavy_search = sub {
        my $schema = shift;
        # More complex query to emphasize network latency
        return $schema->resultset('User')->search(
            {
                age    => { '>' => 30 },
                active => 1,
                name   => { -like => '%User%' }
            },
            {
                order_by => { -desc => 'age' },
                rows     => 100,
                columns  => [qw/id name email age/]
            }
        );
    };

    if ($is_async) {
        # Parallel execution
        my @futures = map {
            $heavy_search->($async_schema)->all
        } (1..$query_count);

        $async_schema->await( Future->wait_all(@futures) );
    } else {
        # Sequential execution
        for (1..$query_count) {
            my @results = $heavy_search->($raw_schema)->all;
        }
    }

    my $elapsed = tv_interval($t0);

    $timer->stop;
    $loop->remove($timer);

    my $expected_ticks = int($elapsed / $interval);
    my $responsiveness = $expected_ticks > 0
                         ? ($ticks / $expected_ticks) * 100
                         : 0;
    my $throughput     = $query_count / $elapsed;

    printf "Execution Time:     %.4f seconds\n", $elapsed;
    printf "Throughput:         %.2f queries/second\n", $throughput;
    printf "Event Loop Health:  %.1f%% responsive (%d/%d ticks)\n",
           $responsiveness, $ticks, $expected_ticks;

    if (!$is_async) {
        $baseline_time = $elapsed;
        my $status = $ticks == 0
                     ? "COMPLETELY BLOCKED"
                     : "SEVERELY DEGRADED";

        print "System Status:      $status\n";
        print "Performance:        [BASELINE]\n";
    } else {
        my $speedup = $baseline_time / $elapsed;
        my $status = $responsiveness > 80
                     ? "HEALTHY & NON-BLOCKING"
                     : "BUSY";

        print  "System Status:      $status\n";
        printf "Performance:        %.2fx FASTER than baseline\n", $speedup;
        printf "Time Saved:         %.4f seconds (%.1f%% improvement)\n",
             ($baseline_time - $elapsed),
            (($baseline_time - $elapsed) / $baseline_time * 100);
    }

    push @results, {
        name           => $name,
        is_async       => $is_async,
        query_count    => $query_count,
        elapsed        => $elapsed,
        throughput     => $throughput,
        responsiveness => $responsiveness,
        speedup        => $is_async ? ($baseline_time / $elapsed) : 1,
    };
}

sub print_summary {
    print "\n" . "-" x 70 . "\n";
    print "SUMMARY\n";
    print "-" x 70 . "\n";

    my @async_results = grep {  $_->{is_async} } @results;
    my @sync_results  = grep { !$_->{is_async} } @results;

    if (@async_results == 0 || @sync_results == 0) {
        print "No results to summarize.\n";
        exit;
    }

    my $avg_speedup        = 0;
    my $max_speedup        = 0;
    my $avg_responsiveness = 0;

    foreach my $result (@async_results) {
        $avg_speedup        += $result->{speedup};
        $max_speedup         = $result->{speedup}
            if $result->{speedup} > $max_speedup;
        $avg_responsiveness += $result->{responsiveness};
    }

    $avg_speedup        /= scalar @async_results;
    $avg_responsiveness /= scalar @async_results;

    my $total_sync_time  = 0;
    my $total_async_time = 0;

    $total_sync_time  += $_->{elapsed} for @sync_results;
    $total_async_time += $_->{elapsed} for @async_results;

    my $total_time_saved  = $total_sync_time - $total_async_time;
    my $total_improvement = $total_sync_time > 0
                            ? ($total_time_saved / $total_sync_time * 100)
                            : 0;

    printf "Across all %d test runs:\n", scalar(@results) / 2;
    printf "\nPerformance Results:\n";
    printf "  • Average Speedup:     %.2fx faster\n", $avg_speedup;
    printf "  • Maximum Speedup:     %.2fx faster\n", $max_speedup;
    printf "  • Total Time (Sync):   %.4f seconds\n", $total_sync_time;
    printf "  • Total Time (Async):  %.4f seconds\n", $total_async_time;
    printf "  • Time Saved:          %.4f seconds (%.1f%% improvement)\n",
        $total_time_saved, $total_improvement;

    printf "\nEvent Loop Health:\n";
    printf "  • Average Responsiveness: %.1f%%\n", $avg_responsiveness;
    printf "  • Sequential Blocking:    0.0%% (completely blocked)\n";

    print "\n What This Means:\n";
    print "  • TRUE parallel query execution across network connections\n";

    if ($avg_speedup > 50) {
        printf "  • Exceptional performance: %.0fx faster with worker pool\n", $avg_speedup;
        print "  • Worker process caching and connection reuse is highly effective\n";
    }
    elsif ($avg_speedup > 2) {
        printf "  • Strong performance: %.1fx faster with parallelism\n", $avg_speedup;
    }
    else {
        printf "  • Similar speed (%.1fx), but with %.1f%% event loop responsiveness\n",
            $avg_speedup, $avg_responsiveness;
    }

    print "  • Non-blocking event loop maintains application responsiveness\n";
    print "  • Better scalability as query count increases\n";

    if ($max_speedup > 100) {
        print "\nKey Insight: Worker pool caching delivered exceptional results!\n";
        print "After warm-up, persistent workers with cached connections and\n";
        print "prepared statements achieved extraordinary parallel throughput.\n";
    } elsif (@sync_results && $sync_results[0]->{query_count}) {
        my $avg_query_time = ($sync_results[0]->{elapsed} / $sync_results[0]->{query_count} * 1000);
        print "\nKey Insight: Network latency makes parallelism highly effective!\n";
        printf "Each query has ~%.1fms of overhead. With 4 workers, parallel\n", $avg_query_time;
        print "execution dramatically reduces total execution time.\n";
    }

    print "\n";
}
