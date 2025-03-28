package Bencher::Scenario::Log::ger::NullOutput;

use 5.010001;
use strict;
use warnings;

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2023-10-29'; # DATE
our $DIST = 'Bencher-Scenarios-Log-ger'; # DIST
our $VERSION = '0.019'; # VERSION

our $scenario = {
    summary => 'Benchmark Log::ger logging speed with the default/null output',
    modules => {
        'Log::ger' => {version=>'0.023'},
        'Log::ger::Format::MultilevelLog' => {},
        'Log::ger::Plugin::OptAway' => {},
        'Log::Any' => {},
        'Log::Fast' => {},
        'Log::Log4perl' => {},
        'Log::Log4perl::Tiny' => {},
        'Log::Contextual' => {},
        'Log::Contextual::SimpleLogger' => {},
        'Log::Dispatch' => {},
        'Log::Dispatch::Null' => {},
        'Log::Dispatchouli' => {},
        'Mojo::Log' => {},
        'XLog' => {},
    },
    participants => [
        {
            name => 'Log::ger-100k_log_trace',
            perl_cmdline_template => ['-MLog::ger', '-e', 'for(1..100_000) { log_trace(q[]) }'],
        },
        {
            name => 'Log::ger-100k_log_is_trace',
            perl_cmdline_template => ['-MLog::ger', '-e', 'for(1..100_000) { log_is_trace() }'],
        },
        {
            name => 'Log::ger+LGP:OptAway-100k_log_trace',
            perl_cmdline_template => ['-MLog::ger::Plugin=OptAway', '-MLog::ger', '-e', 'for(1..100_000) { log_trace(q[]) }'],
        },
        {
            name => 'Log::ger+LGF:MutilevelLog-100k_log_trace',
            perl_cmdline_template => ['-MLog::ger::Format=MultilevelLog', '-MLog::ger', '-e', 'for(1..100_000) { log("trace", q[]) }'],
        },
        {
            name => 'Log::ger+LGP:MutilevelLog-100k_log_6',
            perl_cmdline_template => ['-MLog::ger::Format=MultilevelLog', '-MLog::ger', '-e', 'for(1..100_000) { log(6, q[]) }'],
        },

        {
            name => 'Log::Fast-100k_DEBUG',
            perl_cmdline_template => ['-MLog::Fast', '-e', '$LOG = Log::Fast->global; $LOG->level("INFO"); for(1..100_000) { $LOG->DEBUG(q()) }'],
        },
        {
            name => 'Log::Fast-100k_is_debug',
            perl_cmdline_template => ['-MLog::Fast', '-e', '$LOG = Log::Fast->global; for(1..100_000) { $LOG->level() eq "DEBUG" }'],
        },

        {
            name => 'Log::Any-no_adapter-100k_log_trace',
            perl_cmdline_template => ['-MLog::Any', '-e', 'my $log = Log::Any->get_logger; for(1..100_000) { $log->trace(q[]) }'],
        },
        {
            name => 'Log::Any-no_adapter-100k_is_trace' ,
            perl_cmdline_template => ['-MLog::Any', '-e', 'my $log = Log::Any->get_logger; for(1..100_000) { $log->is_trace }'],
        },
        {
            name => 'Log::Any-null_adapter-100k_log_trace',
            perl_cmdline_template => ['-MLog::Any', '-MLog::Any::Adapter', '-e', 'Log::Any::Adapter->set(q[Null]); my $log = Log::Any->get_logger; for(1..100_000) { $log->trace(q[]) }'],
        },
        {
            name => 'Log::Any-null_adapter-100k_is_trace' ,
            perl_cmdline_template => ['-MLog::Any', '-MLog::Any::Adapter', '-e', 'Log::Any::Adapter->set(q[Null]); my $log = Log::Any->get_logger; for(1..100_000) { $log->is_trace }'],
        },

        {
            name => 'Log::Dispatch::Null-100k_debug' ,
            perl_cmdline_template => ['-MLog::Dispatch', '-e', 'my $null = Log::Dispatch->new(outputs=>[["Null", min_level=>"debug"]]); for(1..100_000) { $null->debug("") }'],
        },

        {
            name => 'Log::Log4perl-easy-100k_trace' ,
            perl_cmdline_template => ['-MLog::Log4perl=:easy', '-e', 'Log::Log4perl->easy_init($ERROR); for(1..100_000) { TRACE "" }'],
        },

        {
            name => 'Log::Log4perl::Tiny-100k_trace' ,
            perl_cmdline_template => ['-MLog::Log4perl::Tiny=:easy', '-e', 'for(1..100_000) { TRACE "" }'],
        },

        {
            name => 'Log::Contextual+Log4perl-100k_trace' ,
            perl_cmdline_template => ['-e', 'use Log::Contextual ":log", "set_logger"; use Log::Log4perl ":easy"; Log::Log4perl->easy_init($DEBUG); my $logger = Log::Log4perl->get_logger; set_logger $logger; for(1..100_000) { log_trace {} }'],
        },
        {
            name => 'Log::Contextual+SimpleLogger-100k_trace' ,
            perl_cmdline_template => ['-MLog::Contextual::SimpleLogger', '-e', 'use Log::Contextual ":log", -logger=>Log::Contextual::SimpleLogger->new({levels=>["debug"]}); for(1..100_000) { log_trace {} }'],
        },

        {
            name => 'Log::Dispatchouli-100k_debug' ,
            perl_cmdline_template => ['-MLog::Dispatchouli', '-e', '$logger = Log::Dispatchouli->new({ident=>"ident", facility=>"facility", to_stdout=>1, debug=>0}); for(1..100_000) { $logger->log_debug("") }'],
        },

        {
            name => 'Mojo::Log-100k_debug' ,
            perl_cmdline_template => ['-MMojo::Log', '-e', '$log = Mojo::Log->new(level=>"warn"); for(1..100_000) { $log->debug("") }'],
        },

        {
            name => 'XLog-100k_debug' ,
            perl_cmdline_template => ['-MXLog', '-e', 'for(1..100_000) { XLog::debug("") }'],
        },
    ],
    precision => 6,
};

1;
# ABSTRACT: Benchmark Log::ger logging speed with the default/null output

__END__

=pod

=encoding UTF-8

=head1 NAME

Bencher::Scenario::Log::ger::NullOutput - Benchmark Log::ger logging speed with the default/null output

=head1 VERSION

This document describes version 0.019 of Bencher::Scenario::Log::ger::NullOutput (from Perl distribution Bencher-Scenarios-Log-ger), released on 2023-10-29.

=head1 SYNOPSIS

To run benchmark with default option:

 % bencher -m Log::ger::NullOutput

For more options (dump scenario, list/include/exclude/add participants, list/include/exclude/add datasets, etc), see L<bencher> or run C<bencher --help>.

=head1 DESCRIPTION

Packaging a benchmark script as a Bencher scenario makes it convenient to include/exclude/add participants/datasets (either via CLI or Perl code), send the result to a central repository, among others . See L<Bencher> and L<bencher> (CLI) for more details.

=head1 BENCHMARKED MODULES

Version numbers shown below are the versions used when running the sample benchmark.

L<Log::Any> 1.717

L<Log::Contextual> 0.008001

L<Log::Contextual::SimpleLogger> 0.008001

L<Log::Dispatch> 2.71

L<Log::Dispatch::Null> 2.71

L<Log::Dispatchouli> 3.007

L<Log::Fast> v2.0.1

L<Log::Log4perl> 1.57

L<Log::Log4perl::Tiny> 1.8.0

L<Log::ger> 0.040

L<Log::ger::Format::MultilevelLog> 0.040

L<Log::ger::Plugin::OptAway> 0.009

L<Mojo::Log>

L<XLog> 1.1.3

=head1 BENCHMARK PARTICIPANTS

=over

=item * Log::ger-100k_log_trace (command)

Command line:

 #TEMPLATE: #perl -MLog::ger -e for(1..100_000) { log_trace(q[]) }



=item * Log::ger-100k_log_is_trace (command)

Command line:

 #TEMPLATE: #perl -MLog::ger -e for(1..100_000) { log_is_trace() }



=item * Log::ger+LGP:OptAway-100k_log_trace (command)

Command line:

 #TEMPLATE: #perl -MLog::ger::Plugin=OptAway -MLog::ger -e for(1..100_000) { log_trace(q[]) }



=item * Log::ger+LGF:MutilevelLog-100k_log_trace (command)

Command line:

 #TEMPLATE: #perl -MLog::ger::Format=MultilevelLog -MLog::ger -e for(1..100_000) { log("trace", q[]) }



=item * Log::ger+LGP:MutilevelLog-100k_log_6 (command)

Command line:

 #TEMPLATE: #perl -MLog::ger::Format=MultilevelLog -MLog::ger -e for(1..100_000) { log(6, q[]) }



=item * Log::Fast-100k_DEBUG (command)

Command line:

 #TEMPLATE: #perl -MLog::Fast -e $LOG = Log::Fast->global; $LOG->level("INFO"); for(1..100_000) { $LOG->DEBUG(q()) }



=item * Log::Fast-100k_is_debug (command)

Command line:

 #TEMPLATE: #perl -MLog::Fast -e $LOG = Log::Fast->global; for(1..100_000) { $LOG->level() eq "DEBUG" }



=item * Log::Any-no_adapter-100k_log_trace (command)

Command line:

 #TEMPLATE: #perl -MLog::Any -e my $log = Log::Any->get_logger; for(1..100_000) { $log->trace(q[]) }



=item * Log::Any-no_adapter-100k_is_trace (command)

Command line:

 #TEMPLATE: #perl -MLog::Any -e my $log = Log::Any->get_logger; for(1..100_000) { $log->is_trace }



=item * Log::Any-null_adapter-100k_log_trace (command)

Command line:

 #TEMPLATE: #perl -MLog::Any -MLog::Any::Adapter -e Log::Any::Adapter->set(q[Null]); my $log = Log::Any->get_logger; for(1..100_000) { $log->trace(q[]) }



=item * Log::Any-null_adapter-100k_is_trace (command)

Command line:

 #TEMPLATE: #perl -MLog::Any -MLog::Any::Adapter -e Log::Any::Adapter->set(q[Null]); my $log = Log::Any->get_logger; for(1..100_000) { $log->is_trace }



=item * Log::Dispatch::Null-100k_debug (command)

Command line:

 #TEMPLATE: #perl -MLog::Dispatch -e my $null = Log::Dispatch->new(outputs=>[["Null", min_level=>"debug"]]); for(1..100_000) { $null->debug("") }



=item * Log::Log4perl-easy-100k_trace (command)

Command line:

 #TEMPLATE: #perl -MLog::Log4perl=:easy -e Log::Log4perl->easy_init($ERROR); for(1..100_000) { TRACE "" }



=item * Log::Log4perl::Tiny-100k_trace (command)

Command line:

 #TEMPLATE: #perl -MLog::Log4perl::Tiny=:easy -e for(1..100_000) { TRACE "" }



=item * Log::Contextual+Log4perl-100k_trace (command)

Command line:

 #TEMPLATE: #perl -e use Log::Contextual ":log", "set_logger"; use Log::Log4perl ":easy"; Log::Log4perl->easy_init($DEBUG); my $logger = Log::Log4perl->get_logger; set_logger $logger; for(1..100_000) { log_trace {} }



=item * Log::Contextual+SimpleLogger-100k_trace (command)

Command line:

 #TEMPLATE: #perl -MLog::Contextual::SimpleLogger -e use Log::Contextual ":log", -logger=>Log::Contextual::SimpleLogger->new({levels=>["debug"]}); for(1..100_000) { log_trace {} }



=item * Log::Dispatchouli-100k_debug (command)

Command line:

 #TEMPLATE: #perl -MLog::Dispatchouli -e $logger = Log::Dispatchouli->new({ident=>"ident", facility=>"facility", to_stdout=>1, debug=>0}); for(1..100_000) { $logger->log_debug("") }



=item * Mojo::Log-100k_debug (command)

Command line:

 #TEMPLATE: #perl -MMojo::Log -e $log = Mojo::Log->new(level=>"warn"); for(1..100_000) { $log->debug("") }



=item * XLog-100k_debug (command)

Command line:

 #TEMPLATE: #perl -MXLog -e for(1..100_000) { XLog::debug("") }



=back

=head1 BENCHMARK SAMPLE RESULTS

=head2 Sample benchmark #1

Run on: perl: I<< v5.38.0 >>, CPU: I<< Intel(R) Core(TM) i5-7200U CPU @ 2.50GHz (2 cores) >>, OS: I<< GNU/Linux Ubuntu version 20.04 >>, OS kernel: I<< Linux version 5.4.0-164-generic >>.

Benchmark command (default options):

 % bencher -m Log::ger::NullOutput

Result formatted as table:

 #table1#
 +------------------------------------------+-----------+-----------+-----------------------+-----------------------+-----------+---------+
 | participant                              | rate (/s) | time (ms) | pct_faster_vs_slowest | pct_slower_vs_fastest |  errors   | samples |
 +------------------------------------------+-----------+-----------+-----------------------+-----------------------+-----------+---------+
 | Log::Dispatch::Null-100k_debug           |      1.97 |     508   |                 0.00% |              3831.61% |   0.00032 |       8 |
 | Log::Contextual+Log4perl-100k_trace      |      2.2  |     460   |                11.26% |              3433.68% |   0.00063 |       6 |
 | Log::Contextual+SimpleLogger-100k_trace  |      2.3  |     440   |                14.82% |              3324.26% |   0.0011  |       6 |
 | Mojo::Log-100k_debug                     |      5.58 |     179   |               183.55% |              1286.57% |   0.0001  |       6 |
 | Log::Dispatchouli-100k_debug             |      6    |     167   |               204.77% |              1190.02% | 6.4e-05   |       6 |
 | Log::Log4perl::Tiny-100k_trace           |      9.72 |     103   |               393.82% |               696.16% | 3.9e-05   |       6 |
 | Log::Fast-100k_is_debug                  |     16    |      64   |               688.73% |               398.48% | 7.6e-05   |       7 |
 | Log::Any-null_adapter-100k_log_trace     |     15.9  |      63   |               706.34% |               387.59% | 2.3e-05   |       7 |
 | Log::Log4perl-easy-100k_trace            |     17.9  |      55.9 |               808.92% |               332.56% | 4.3e-05   |       6 |
 | Log::Any-no_adapter-100k_is_trace        |     23    |      43   |              1071.54% |               235.59% | 8.1e-05   |       7 |
 | Log::Any-null_adapter-100k_is_trace      |     23.1  |      43.3 |              1072.70% |               235.26% | 2.2e-05   |       6 |
 | Log::Fast-100k_DEBUG                     |     26    |      39   |              1206.11% |               201.02% | 6.7e-05   |       7 |
 | XLog-100k_debug                          |     35    |      28   |              1693.38% |               119.23% | 7.6e-05   |       6 |
 | Log::Any-no_adapter-100k_log_trace       |     40.9  |      24.5 |              1977.36% |                89.26% | 2.4e-05   |       7 |
 | Log::ger+LGP:OptAway-100k_log_trace      |     44.2  |      22.6 |              2146.33% |                75.02% |   6e-06   |       6 |
 | Log::ger+LGP:MutilevelLog-100k_log_6     |     50    |      20   |              2187.70% |                71.86% |   0.00028 |       6 |
 | Log::ger+LGF:MutilevelLog-100k_log_trace |     49    |      21   |              2375.40% |                58.83% | 3.1e-05   |       6 |
 | Log::ger-100k_log_trace                  |     75    |      13   |              3701.48% |                 3.42% | 2.3e-05   |       6 |
 | Log::ger-100k_log_is_trace               |     77    |      13   |              3831.61% |                 0.00% | 4.7e-05   |       7 |
 +------------------------------------------+-----------+-----------+-----------------------+-----------------------+-----------+---------+


The above result formatted in L<Benchmark.pm|Benchmark> style:

                                              Rate  Log::Dispatch::Null-100k_debug  Log::Contextual+Log4perl-100k_trace  Log::Contextual+SimpleLogger-100k_trace  Mojo::Log-100k_debug  Log::Dispatchouli-100k_debug  Log::Log4perl::Tiny-100k_trace  Log::Fast-100k_is_debug  Log::Any-null_adapter-100k_log_trace  Log::Log4perl-easy-100k_trace  Log::Any-null_adapter-100k_is_trace  Log::Any-no_adapter-100k_is_trace  Log::Fast-100k_DEBUG  XLog-100k_debug  Log::Any-no_adapter-100k_log_trace  Log::ger+LGP:OptAway-100k_log_trace  Log::ger+LGF:MutilevelLog-100k_log_trace  Log::ger+LGP:MutilevelLog-100k_log_6  Log::ger-100k_log_trace  Log::ger-100k_log_is_trace 
  Log::Dispatch::Null-100k_debug            1.97/s                              --                                  -9%                                     -13%                  -64%                          -67%                            -79%                     -87%                                  -87%                           -88%                                 -91%                               -91%                  -92%             -94%                                -95%                                 -95%                                      -95%                                  -96%                     -97%                        -97% 
  Log::Contextual+Log4perl-100k_trace        2.2/s                             10%                                   --                                      -4%                  -61%                          -63%                            -77%                     -86%                                  -86%                           -87%                                 -90%                               -90%                  -91%             -93%                                -94%                                 -95%                                      -95%                                  -95%                     -97%                        -97% 
  Log::Contextual+SimpleLogger-100k_trace    2.3/s                             15%                                   4%                                       --                  -59%                          -62%                            -76%                     -85%                                  -85%                           -87%                                 -90%                               -90%                  -91%             -93%                                -94%                                 -94%                                      -95%                                  -95%                     -97%                        -97% 
  Mojo::Log-100k_debug                      5.58/s                            183%                                 156%                                     145%                    --                           -6%                            -42%                     -64%                                  -64%                           -68%                                 -75%                               -75%                  -78%             -84%                                -86%                                 -87%                                      -88%                                  -88%                     -92%                        -92% 
  Log::Dispatchouli-100k_debug                 6/s                            204%                                 175%                                     163%                    7%                            --                            -38%                     -61%                                  -62%                           -66%                                 -74%                               -74%                  -76%             -83%                                -85%                                 -86%                                      -87%                                  -88%                     -92%                        -92% 
  Log::Log4perl::Tiny-100k_trace            9.72/s                            393%                                 346%                                     327%                   73%                           62%                              --                     -37%                                  -38%                           -45%                                 -57%                               -58%                  -62%             -72%                                -76%                                 -78%                                      -79%                                  -80%                     -87%                        -87% 
  Log::Fast-100k_is_debug                     16/s                            693%                                 618%                                     587%                  179%                          160%                             60%                       --                                   -1%                           -12%                                 -32%                               -32%                  -39%             -56%                                -61%                                 -64%                                      -67%                                  -68%                     -79%                        -79% 
  Log::Any-null_adapter-100k_log_trace      15.9/s                            706%                                 630%                                     598%                  184%                          165%                             63%                       1%                                    --                           -11%                                 -31%                               -31%                  -38%             -55%                                -61%                                 -64%                                      -66%                                  -68%                     -79%                        -79% 
  Log::Log4perl-easy-100k_trace             17.9/s                            808%                                 722%                                     687%                  220%                          198%                             84%                      14%                                   12%                             --                                 -22%                               -23%                  -30%             -49%                                -56%                                 -59%                                      -62%                                  -64%                     -76%                        -76% 
  Log::Any-null_adapter-100k_is_trace       23.1/s                           1073%                                 962%                                     916%                  313%                          285%                            137%                      47%                                   45%                            29%                                   --                                 0%                   -9%             -35%                                -43%                                 -47%                                      -51%                                  -53%                     -69%                        -69% 
  Log::Any-no_adapter-100k_is_trace           23/s                           1081%                                 969%                                     923%                  316%                          288%                            139%                      48%                                   46%                            30%                                   0%                                 --                   -9%             -34%                                -43%                                 -47%                                      -51%                                  -53%                     -69%                        -69% 
  Log::Fast-100k_DEBUG                        26/s                           1202%                                1079%                                    1028%                  358%                          328%                            164%                      64%                                   61%                            43%                                  11%                                10%                    --             -28%                                -37%                                 -42%                                      -46%                                  -48%                     -66%                        -66% 
  XLog-100k_debug                             35/s                           1714%                                1542%                                    1471%                  539%                          496%                            267%                     128%                                  125%                            99%                                  54%                                53%                   39%               --                                -12%                                 -19%                                      -25%                                  -28%                     -53%                        -53% 
  Log::Any-no_adapter-100k_log_trace        40.9/s                           1973%                                1777%                                    1695%                  630%                          581%                            320%                     161%                                  157%                           128%                                  76%                                75%                   59%              14%                                  --                                  -7%                                      -14%                                  -18%                     -46%                        -46% 
  Log::ger+LGP:OptAway-100k_log_trace       44.2/s                           2147%                                1935%                                    1846%                  692%                          638%                            355%                     183%                                  178%                           147%                                  91%                                90%                   72%              23%                                  8%                                   --                                       -7%                                  -11%                     -42%                        -42% 
  Log::ger+LGF:MutilevelLog-100k_log_trace    49/s                           2319%                                2090%                                    1995%                  752%                          695%                            390%                     204%                                  200%                           166%                                 106%                               104%                   85%              33%                                 16%                                   7%                                        --                                   -4%                     -38%                        -38% 
  Log::ger+LGP:MutilevelLog-100k_log_6        50/s                           2440%                                2200%                                    2100%                  794%                          735%                            415%                     220%                                  215%                           179%                                 116%                               114%                   95%              39%                                 22%                                  13%                                        5%                                    --                     -35%                        -35% 
  Log::ger-100k_log_trace                     75/s                           3807%                                3438%                                    3284%                 1276%                         1184%                            692%                     392%                                  384%                           330%                                 233%                               230%                  200%             115%                                 88%                                  73%                                       61%                                   53%                       --                          0% 
  Log::ger-100k_log_is_trace                  77/s                           3807%                                3438%                                    3284%                 1276%                         1184%                            692%                     392%                                  384%                           330%                                 233%                               230%                  200%             115%                                 88%                                  73%                                       61%                                   53%                       0%                          -- 
 
 Legends:
   Log::Any-no_adapter-100k_is_trace: participant=Log::Any-no_adapter-100k_is_trace
   Log::Any-no_adapter-100k_log_trace: participant=Log::Any-no_adapter-100k_log_trace
   Log::Any-null_adapter-100k_is_trace: participant=Log::Any-null_adapter-100k_is_trace
   Log::Any-null_adapter-100k_log_trace: participant=Log::Any-null_adapter-100k_log_trace
   Log::Contextual+Log4perl-100k_trace: participant=Log::Contextual+Log4perl-100k_trace
   Log::Contextual+SimpleLogger-100k_trace: participant=Log::Contextual+SimpleLogger-100k_trace
   Log::Dispatch::Null-100k_debug: participant=Log::Dispatch::Null-100k_debug
   Log::Dispatchouli-100k_debug: participant=Log::Dispatchouli-100k_debug
   Log::Fast-100k_DEBUG: participant=Log::Fast-100k_DEBUG
   Log::Fast-100k_is_debug: participant=Log::Fast-100k_is_debug
   Log::Log4perl-easy-100k_trace: participant=Log::Log4perl-easy-100k_trace
   Log::Log4perl::Tiny-100k_trace: participant=Log::Log4perl::Tiny-100k_trace
   Log::ger+LGF:MutilevelLog-100k_log_trace: participant=Log::ger+LGF:MutilevelLog-100k_log_trace
   Log::ger+LGP:MutilevelLog-100k_log_6: participant=Log::ger+LGP:MutilevelLog-100k_log_6
   Log::ger+LGP:OptAway-100k_log_trace: participant=Log::ger+LGP:OptAway-100k_log_trace
   Log::ger-100k_log_is_trace: participant=Log::ger-100k_log_is_trace
   Log::ger-100k_log_trace: participant=Log::ger-100k_log_trace
   Mojo::Log-100k_debug: participant=Mojo::Log-100k_debug
   XLog-100k_debug: participant=XLog-100k_debug

To display as an interactive HTML table on a browser, you can add option C<--format html+datatables>.

=head1 BENCHMARK NOTES

Not included here:

=over

=item * L<Log::Tiny>

Cannot do null output, must log to a file. (Technically you can use F</dev/null>, but.)

=back

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Bencher-Scenarios-Log-ger>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Bencher-Scenarios-Log-ger>.

=head1 AUTHOR

perlancar <perlancar@cpan.org>

=head1 CONTRIBUTING


To contribute, you can send patches by email/via RT, or send pull requests on
GitHub.

Most of the time, you don't need to build the distribution yourself. You can
simply modify the code, then test via:

 % prove -l

If you want to build the distribution (e.g. to try to install it locally on your
system), you can install L<Dist::Zilla>,
L<Dist::Zilla::PluginBundle::Author::PERLANCAR>,
L<Pod::Weaver::PluginBundle::Author::PERLANCAR>, and sometimes one or two other
Dist::Zilla- and/or Pod::Weaver plugins. Any additional steps required beyond
that are considered a bug and can be reported to me.

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2023, 2021, 2020, 2018, 2017 by perlancar <perlancar@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Bencher-Scenarios-Log-ger>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
