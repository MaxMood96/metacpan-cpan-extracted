package Bencher::Scenario::shuffle;

use strict;
use warnings;

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2022-05-22'; # DATE
our $DIST = 'Bencher-Scenario-shuffle'; # DIST
our $VERSION = '0.001'; # VERSION

our $scenario = {
    summary => 'Benchmark various algorithms & implementation of shuffle',

    participants => [
        {fcall_template=>'List::Util::PP::shuffle(@{<ary>})', result_is_list=>1},
        {fcall_template=>'List::Util::shuffle(@{<ary>})', result_is_list=>1},
        {fcall_template=>'List::MoreUtils::PP::samples(<arysize>, @{<ary>})', result_is_list=>1},
        {fcall_template=>'List::MoreUtils::XS::samples(<arysize>, @{<ary>})', result_is_list=>1},
        {fcall_template=>'Algorithm::Numerical::Shuffle::shuffle(@{<ary>})', result_is_list=>1},
        {fcall_template=>'Array::Shuffle::shuffle(<ary>)', result_is_list=>1},
    ],

    datasets => [
        {name=>'ary0'   , args=>{arysize=>0,       ary=>[]}},
        {name=>'ary1'   , args=>{arysize=>1,       ary=>[1]}},
        {name=>'ary10'  , args=>{arysize=>10,      ary=>[1..10]}},
        {name=>'ary100' , args=>{arysize=>100,     ary=>[1..100]}},
        {name=>'ary1k'  , args=>{arysize=>1000,    ary=>[1..1000]}},
        {name=>'ary10k' , args=>{arysize=>10_000,  ary=>[1..10_000]}, include_by_default=>0},
        {name=>'ary100k', args=>{arysize=>100_000, ary=>[1..100_000]}, include_by_default=>0},
    ],
};

1;
# ABSTRACT: Benchmark various algorithms & implementation of shuffle

__END__

=pod

=encoding UTF-8

=head1 NAME

Bencher::Scenario::shuffle - Benchmark various algorithms & implementation of shuffle

=head1 VERSION

This document describes version 0.001 of Bencher::Scenario::shuffle (from Perl distribution Bencher-Scenario-shuffle), released on 2022-05-22.

=head1 SYNOPSIS

To run benchmark with default option:

 % bencher -m shuffle

To run module startup overhead benchmark:

 % bencher --module-startup -m shuffle

For more options (dump scenario, list/include/exclude/add participants, list/include/exclude/add datasets, etc), see L<bencher> or run C<bencher --help>.

=head1 DESCRIPTION

Packaging a benchmark script as a Bencher scenario makes it convenient to include/exclude/add participants/datasets (either via CLI or Perl code), send the result to a central repository, among others . See L<Bencher> and L<bencher> (CLI) for more details.

=head1 BENCHMARKED MODULES

Version numbers shown below are the versions used when running the sample benchmark.

L<List::Util::PP> 1.500006

L<List::Util> 1.59

L<List::MoreUtils::PP> 0.430

L<List::MoreUtils::XS> 0.430

L<Algorithm::Numerical::Shuffle> 2009110301

L<Array::Shuffle> 0.001

=head1 BENCHMARK PARTICIPANTS

=over

=item * List::Util::PP::shuffle (perl_code)

Function call template:

 List::Util::PP::shuffle(@{<ary>})



=item * List::Util::shuffle (perl_code)

Function call template:

 List::Util::shuffle(@{<ary>})



=item * List::MoreUtils::PP::samples (perl_code)

Function call template:

 List::MoreUtils::PP::samples(<arysize>, @{<ary>})



=item * List::MoreUtils::XS::samples (perl_code)

Function call template:

 List::MoreUtils::XS::samples(<arysize>, @{<ary>})



=item * Algorithm::Numerical::Shuffle::shuffle (perl_code)

Function call template:

 Algorithm::Numerical::Shuffle::shuffle(@{<ary>})



=item * Array::Shuffle::shuffle (perl_code)

Function call template:

 Array::Shuffle::shuffle(<ary>)



=back

=head1 BENCHMARK DATASETS

=over

=item * ary0

=item * ary1

=item * ary10

=item * ary100

=item * ary1k

=item * ary10k (not included by default)

=item * ary100k (not included by default)

=back

=head1 SAMPLE BENCHMARK RESULTS

Run on: perl: I<< v5.34.0 >>, CPU: I<< Intel(R) Core(TM) i5-7200U CPU @ 2.50GHz (2 cores) >>, OS: I<< GNU/Linux Ubuntu version 20.04 >>, OS kernel: I<< Linux version 5.4.0-91-generic >>.

Benchmark with default options (C<< bencher -m shuffle >>):

 #table1#
 +----------------------------------------+---------+-----------+------------+-----------------------+-----------------------+---------+---------+
 | participant                            | dataset | rate (/s) | time (μs)  | pct_faster_vs_slowest | pct_slower_vs_fastest |  errors | samples |
 +----------------------------------------+---------+-----------+------------+-----------------------+-----------------------+---------+---------+
 | Algorithm::Numerical::Shuffle::shuffle | ary1k   |    3160   | 317        |                 0.00% |            296454.40% | 1.6e-07 |      20 |
 | Array::Shuffle::shuffle                | ary1k   |    3410   | 294        |                 7.90% |            274735.26% | 2.1e-07 |      20 |
 | List::Util::PP::shuffle                | ary1k   |    3410   | 293        |                 7.95% |            274624.64% | 2.1e-07 |      20 |
 | Algorithm::Numerical::Shuffle::shuffle | ary100  |   29804.3 |  33.5522   |               844.04% |             31313.27% | 1.2e-11 |      32 |
 | Array::Shuffle::shuffle                | ary100  |   32000   |  31.2      |               914.02% |             29145.56% |   1e-08 |      34 |
 | List::Util::shuffle                    | ary1k   |   33300   |  30        |               955.45% |             27997.31% | 1.3e-08 |      22 |
 | List::MoreUtils::XS::samples           | ary1k   |   34500   |  29        |               991.32% |             27073.94% | 1.3e-08 |      22 |
 | List::Util::PP::shuffle                | ary100  |   36442.3 |  27.4407   |              1054.30% |             25591.36% | 1.1e-11 |      20 |
 | List::MoreUtils::PP::samples           | ary1k   |   48300   |  20.7      |              1429.75% |             19285.81% | 5.2e-09 |      33 |
 | Algorithm::Numerical::Shuffle::shuffle | ary10   |  272780   |   3.6659   |              8540.36% |              3332.20% | 1.1e-11 |      20 |
 | Array::Shuffle::shuffle                | ary10   |  280000   |   3.58     |              8754.38% |              3249.24% | 1.7e-09 |      20 |
 | List::Util::PP::shuffle                | ary10   |  295000   |   3.39     |              9243.25% |              3074.00% | 1.7e-09 |      20 |
 | List::Util::shuffle                    | ary100  |  300930   |   3.3231   |              9431.76% |              3011.22% | 1.1e-11 |      20 |
 | List::MoreUtils::XS::samples           | ary100  |  344700   |   2.901    |             10819.76% |              2615.76% | 1.5e-10 |      20 |
 | List::MoreUtils::PP::samples           | ary100  |  413750   |   2.4169   |             13005.43% |              2162.84% | 1.1e-11 |      20 |
 | List::Util::PP::shuffle                | ary1    | 1110000   |   0.9      |             35082.83% |               742.90% | 4.2e-10 |      20 |
 | Array::Shuffle::shuffle                | ary1    | 1518000   |   0.6589   |             47971.18% |               516.91% | 1.1e-11 |      20 |
 | List::Util::shuffle                    | ary10   | 1817000   |   0.5503   |             57456.38% |               415.24% | 1.1e-11 |      26 |
 | List::MoreUtils::PP::samples           | ary10   | 1820000   |   0.5495   |             57545.03% |               414.45% |   1e-11 |      20 |
 | Algorithm::Numerical::Shuffle::shuffle | ary1    | 1880000   |   0.532    |             59396.24% |               398.44% | 1.9e-10 |      23 |
 | List::Util::PP::shuffle                | ary0    | 2070000   |   0.484    |             65338.08% |               353.18% |   2e-10 |      22 |
 | List::MoreUtils::XS::samples           | ary10   | 2260000   |   0.442    |             71527.76% |               314.02% |   2e-10 |      22 |
 | List::MoreUtils::PP::samples           | ary1    | 2669000   |   0.3747   |             84440.49% |               250.78% | 1.1e-11 |      22 |
 | Array::Shuffle::shuffle                | ary0    | 3170000   |   0.315    |            100315.98% |               195.33% |   1e-10 |      20 |
 | List::MoreUtils::PP::samples           | ary0    | 3233000   |   0.3093   |            102317.52% |               189.55% | 1.1e-11 |      20 |
 | List::Util::shuffle                    | ary1    | 3670000   |   0.272    |            116143.82% |               155.11% | 3.5e-11 |      20 |
 | List::Util::shuffle                    | ary0    | 4400000   |   0.227    |            139213.85% |               112.87% | 8.4e-11 |      22 |
 | List::MoreUtils::XS::samples           | ary1    | 5858700   |   0.170686 |            185472.45% |                59.81% |   0     |      20 |
 | Algorithm::Numerical::Shuffle::shuffle | ary0    | 6149000   |   0.1626   |            194667.26% |                52.26% |   1e-11 |      20 |
 | List::MoreUtils::XS::samples           | ary0    | 9360000   |   0.107    |            296454.40% |                 0.00% | 5.3e-11 |      20 |
 +----------------------------------------+---------+-----------+------------+-----------------------+-----------------------+---------+---------+


Formatted as L<Benchmark.pm|Benchmark> result:

                     Rate  ANS:s ary1k  AS:s ary1k  LUP:s ary1k  ANS:s ary100  AS:s ary100  LU:s ary1k  LMX:s ary1k  LUP:s ary100  LMP:s ary1k  ANS:s ary10  AS:s ary10  LUP:s ary10  LU:s ary100  LMX:s ary100  LMP:s ary100  LUP:s ary1  AS:s ary1  LU:s ary10  LMP:s ary10  ANS:s ary1  LUP:s ary0  LMX:s ary10  LMP:s ary1  AS:s ary0  LMP:s ary0  LU:s ary1  LU:s ary0  LMX:s ary1  ANS:s ary0  LMX:s ary0 
  ANS:s ary1k      3160/s           --         -7%          -7%          -89%         -90%        -90%         -90%          -91%         -93%         -98%        -98%         -98%         -98%          -99%          -99%        -99%       -99%        -99%         -99%        -99%        -99%         -99%        -99%       -99%        -99%       -99%       -99%        -99%        -99%        -99% 
  AS:s ary1k       3410/s           7%          --           0%          -88%         -89%        -89%         -90%          -90%         -92%         -98%        -98%         -98%         -98%          -99%          -99%        -99%       -99%        -99%         -99%        -99%        -99%         -99%        -99%       -99%        -99%       -99%       -99%        -99%        -99%        -99% 
  LUP:s ary1k      3410/s           8%          0%           --          -88%         -89%        -89%         -90%          -90%         -92%         -98%        -98%         -98%         -98%          -99%          -99%        -99%       -99%        -99%         -99%        -99%        -99%         -99%        -99%       -99%        -99%       -99%       -99%        -99%        -99%        -99% 
  ANS:s ary100  29804.3/s         844%        776%         773%            --          -7%        -10%         -13%          -18%         -38%         -89%        -89%         -89%         -90%          -91%          -92%        -97%       -98%        -98%         -98%        -98%        -98%         -98%        -98%       -99%        -99%       -99%       -99%        -99%        -99%        -99% 
  AS:s ary100     32000/s         916%        842%         839%            7%           --         -3%          -7%          -12%         -33%         -88%        -88%         -89%         -89%          -90%          -92%        -97%       -97%        -98%         -98%        -98%        -98%         -98%        -98%       -98%        -99%       -99%       -99%        -99%        -99%        -99% 
  LU:s ary1k      33300/s         956%        880%         876%           11%           4%          --          -3%           -8%         -31%         -87%        -88%         -88%         -88%          -90%          -91%        -97%       -97%        -98%         -98%        -98%        -98%         -98%        -98%       -98%        -98%       -99%       -99%        -99%        -99%        -99% 
  LMX:s ary1k     34500/s         993%        913%         910%           15%           7%          3%           --           -5%         -28%         -87%        -87%         -88%         -88%          -89%          -91%        -96%       -97%        -98%         -98%        -98%        -98%         -98%        -98%       -98%        -98%       -99%       -99%        -99%        -99%        -99% 
  LUP:s ary100  36442.3/s        1055%        971%         967%           22%          13%          9%           5%            --         -24%         -86%        -86%         -87%         -87%          -89%          -91%        -96%       -97%        -97%         -97%        -98%        -98%         -98%        -98%       -98%        -98%       -99%       -99%        -99%        -99%        -99% 
  LMP:s ary1k     48300/s        1431%       1320%        1315%           62%          50%         44%          40%           32%           --         -82%        -82%         -83%         -83%          -85%          -88%        -95%       -96%        -97%         -97%        -97%        -97%         -97%        -98%       -98%        -98%       -98%       -98%        -99%        -99%        -99% 
  ANS:s ary10    272780/s        8547%       7919%        7892%          815%         751%        718%         691%          648%         464%           --         -2%          -7%          -9%          -20%          -34%        -75%       -82%        -84%         -85%        -85%        -86%         -87%        -89%       -91%        -91%       -92%       -93%        -95%        -95%        -97% 
  AS:s ary10     280000/s        8754%       8112%        8084%          837%         771%        737%         710%          666%         478%           2%          --          -5%          -7%          -18%          -32%        -74%       -81%        -84%         -84%        -85%        -86%         -87%        -89%       -91%        -91%       -92%       -93%        -95%        -95%        -97% 
  LUP:s ary10    295000/s        9251%       8572%        8543%          889%         820%        784%         755%          709%         510%           8%          5%           --          -1%          -14%          -28%        -73%       -80%        -83%         -83%        -84%        -85%         -86%        -88%       -90%        -90%       -91%       -93%        -94%        -95%        -96% 
  LU:s ary100    300930/s        9439%       8747%        8717%          909%         838%        802%         772%          725%         522%          10%          7%           2%           --          -12%          -27%        -72%       -80%        -83%         -83%        -83%        -85%         -86%        -88%       -90%        -90%       -91%       -93%        -94%        -95%        -96% 
  LMX:s ary100   344700/s       10827%      10034%        9999%         1056%         975%        934%         899%          845%         613%          26%         23%          16%          14%            --          -16%        -68%       -77%        -81%         -81%        -81%        -83%         -84%        -87%       -89%        -89%       -90%       -92%        -94%        -94%        -96% 
  LMP:s ary100   413750/s       13015%      12064%       12022%         1288%        1190%       1141%        1099%         1035%         756%          51%         48%          40%          37%           20%            --        -62%       -72%        -77%         -77%        -77%        -79%         -81%        -84%       -86%        -87%       -88%       -90%        -92%        -93%        -95% 
  LUP:s ary1    1110000/s       35122%      32566%       32455%         3628%        3366%       3233%        3122%         2948%        2200%         307%        297%         276%         269%          222%          168%          --       -26%        -38%         -38%        -40%        -46%         -50%        -58%       -65%        -65%       -69%       -74%        -81%        -81%        -88% 
  AS:s ary1     1518000/s       48010%      44519%       44368%         4992%        4635%       4453%        4301%         4064%        3041%         456%        443%         414%         404%          340%          266%         36%         --        -16%         -16%        -19%        -26%         -32%        -43%       -52%        -53%       -58%       -65%        -74%        -75%        -83% 
  LU:s ary10    1817000/s       57504%      53325%       53143%         5997%        5569%       5351%        5169%         4886%        3661%         566%        550%         516%         503%          427%          339%         63%        19%          --           0%         -3%        -12%         -19%        -31%       -42%        -43%       -50%       -58%        -68%        -70%        -80% 
  LMP:s ary10   1820000/s       57588%      53403%       53221%         6005%        5577%       5359%        5177%         4893%        3667%         567%        551%         516%         504%          427%          339%         63%        19%          0%           --         -3%        -11%         -19%        -31%       -42%        -43%       -50%       -58%        -68%        -70%        -80% 
  ANS:s ary1    1880000/s       59486%      55163%       54975%         6206%        5764%       5539%        5351%         5058%        3790%         589%        572%         537%         524%          445%          354%         69%        23%          3%           3%          --         -9%         -16%        -29%       -40%        -41%       -48%       -57%        -67%        -69%        -79% 
  LUP:s ary0    2070000/s       65395%      60643%       60437%         6832%        6346%       6098%        5891%         5569%        4176%         657%        639%         600%         586%          499%          399%         85%        36%         13%          13%          9%          --          -8%        -22%       -34%        -36%       -43%       -53%        -64%        -66%        -77% 
  LMX:s ary10   2260000/s       71619%      66415%       66189%         7490%        6958%       6687%        6461%         6108%        4583%         729%        709%         666%         651%          556%          446%        103%        49%         24%          24%         20%          9%           --        -15%       -28%        -30%       -38%       -48%        -61%        -63%        -75% 
  LMP:s ary1    2669000/s       84501%      78362%       78095%         8854%        8226%       7906%        7639%         7223%        5424%         878%        855%         804%         786%          674%          545%        140%        75%         46%          46%         41%         29%          17%          --       -15%        -17%       -27%       -39%        -54%        -56%        -71% 
  AS:s ary0     3170000/s      100534%      93233%       92915%        10551%        9804%       9423%        9106%         8611%        6471%        1063%       1036%         976%         954%          820%          667%        185%       109%         74%          74%         68%         53%          40%         18%         --         -1%       -13%       -27%        -45%        -48%        -66% 
  LMP:s ary0    3233000/s      102389%      94953%       94630%        10747%        9987%       9599%        9276%         8771%        6592%        1085%       1057%         996%         974%          837%          681%        190%       113%         77%          77%         72%         56%          42%         21%         1%          --       -12%       -26%        -44%        -47%        -65% 
  LU:s ary1     3670000/s      116444%     107988%      107620%        12235%       11370%      10929%       10561%         9988%        7510%        1247%       1216%        1146%        1121%          966%          788%        230%       142%        102%         102%         95%         77%          62%         37%        15%         13%         --       -16%        -37%        -40%        -60% 
  LU:s ary0     4400000/s      139547%     129415%      128974%        14680%       13644%      13115%       12675%        11988%        9018%        1514%       1477%        1393%        1363%         1177%          964%        296%       190%        142%         142%        134%        113%          94%         65%        38%         36%        19%         --        -24%        -28%        -52% 
  LMX:s ary1    5858700/s      185621%     172146%      171560%        19557%       18179%      17476%       16890%        15976%       12027%        2047%       1997%        1886%        1846%         1599%         1315%        427%       286%        222%         221%        211%        183%         158%        119%        84%         81%        59%        32%          --         -4%        -37% 
  ANS:s ary0    6149000/s      194856%     180711%      180096%        20534%       19088%      18350%       17735%        16776%       12630%        2154%       2101%        1984%        1943%         1684%         1386%        453%       305%        238%         237%        227%        197%         171%        130%        93%         90%        67%        39%          4%          --        -34% 
  LMX:s ary0    9360000/s      296161%     274666%      273731%        31257%       29058%      27937%       27002%        25545%       19245%        3326%       3245%        3068%        3005%         2611%         2158%        741%       515%        414%         413%        397%        352%         313%        250%       194%        189%       154%       112%         59%         51%          -- 
 
 Legends:
   ANS:s ary0: dataset=ary0 participant=Algorithm::Numerical::Shuffle::shuffle
   ANS:s ary1: dataset=ary1 participant=Algorithm::Numerical::Shuffle::shuffle
   ANS:s ary10: dataset=ary10 participant=Algorithm::Numerical::Shuffle::shuffle
   ANS:s ary100: dataset=ary100 participant=Algorithm::Numerical::Shuffle::shuffle
   ANS:s ary1k: dataset=ary1k participant=Algorithm::Numerical::Shuffle::shuffle
   AS:s ary0: dataset=ary0 participant=Array::Shuffle::shuffle
   AS:s ary1: dataset=ary1 participant=Array::Shuffle::shuffle
   AS:s ary10: dataset=ary10 participant=Array::Shuffle::shuffle
   AS:s ary100: dataset=ary100 participant=Array::Shuffle::shuffle
   AS:s ary1k: dataset=ary1k participant=Array::Shuffle::shuffle
   LMP:s ary0: dataset=ary0 participant=List::MoreUtils::PP::samples
   LMP:s ary1: dataset=ary1 participant=List::MoreUtils::PP::samples
   LMP:s ary10: dataset=ary10 participant=List::MoreUtils::PP::samples
   LMP:s ary100: dataset=ary100 participant=List::MoreUtils::PP::samples
   LMP:s ary1k: dataset=ary1k participant=List::MoreUtils::PP::samples
   LMX:s ary0: dataset=ary0 participant=List::MoreUtils::XS::samples
   LMX:s ary1: dataset=ary1 participant=List::MoreUtils::XS::samples
   LMX:s ary10: dataset=ary10 participant=List::MoreUtils::XS::samples
   LMX:s ary100: dataset=ary100 participant=List::MoreUtils::XS::samples
   LMX:s ary1k: dataset=ary1k participant=List::MoreUtils::XS::samples
   LU:s ary0: dataset=ary0 participant=List::Util::shuffle
   LU:s ary1: dataset=ary1 participant=List::Util::shuffle
   LU:s ary10: dataset=ary10 participant=List::Util::shuffle
   LU:s ary100: dataset=ary100 participant=List::Util::shuffle
   LU:s ary1k: dataset=ary1k participant=List::Util::shuffle
   LUP:s ary0: dataset=ary0 participant=List::Util::PP::shuffle
   LUP:s ary1: dataset=ary1 participant=List::Util::PP::shuffle
   LUP:s ary10: dataset=ary10 participant=List::Util::PP::shuffle
   LUP:s ary100: dataset=ary100 participant=List::Util::PP::shuffle
   LUP:s ary1k: dataset=ary1k participant=List::Util::PP::shuffle

Benchmark module startup overhead (C<< bencher -m shuffle --module-startup >>):

 #table2#
 +-------------------------------+-----------+-------------------+-----------------------+-----------------------+---------+---------+
 | participant                   | time (ms) | mod_overhead_time | pct_faster_vs_slowest | pct_slower_vs_fastest |  errors | samples |
 +-------------------------------+-----------+-------------------+-----------------------+-----------------------+---------+---------+
 | List::MoreUtils::PP           |     11.5  |              4.9  |                 0.00% |                73.32% | 6.5e-06 |      20 |
 | List::MoreUtils::XS           |     11.1  |              4.5  |                 3.53% |                67.40% | 6.7e-06 |      20 |
 | List::Util::PP                |     10.6  |              4    |                 8.66% |                59.50% |   7e-06 |      20 |
 | List::Util                    |      9.87 |              3.27 |                16.24% |                49.11% | 4.7e-06 |      20 |
 | Algorithm::Numerical::Shuffle |      9.35 |              2.75 |                22.60% |                41.36% | 7.4e-06 |      20 |
 | Array::Shuffle                |      9.27 |              2.67 |                23.75% |                40.05% | 6.9e-06 |      21 |
 | perl -e1 (baseline)           |      6.6  |              0    |                73.32% |                 0.00% | 2.3e-05 |      21 |
 +-------------------------------+-----------+-------------------+-----------------------+-----------------------+---------+---------+


Formatted as L<Benchmark.pm|Benchmark> result:

                          Rate  LM:P  LM:X  LU:P   L:U  AN:S   A:S  perl -e1 (baseline) 
  LM:P                  87.0/s    --   -3%   -7%  -14%  -18%  -19%                 -42% 
  LM:X                  90.1/s    3%    --   -4%  -11%  -15%  -16%                 -40% 
  LU:P                  94.3/s    8%    4%    --   -6%  -11%  -12%                 -37% 
  L:U                  101.3/s   16%   12%    7%    --   -5%   -6%                 -33% 
  AN:S                 107.0/s   22%   18%   13%    5%    --    0%                 -29% 
  A:S                  107.9/s   24%   19%   14%    6%    0%    --                 -28% 
  perl -e1 (baseline)  151.5/s   74%   68%   60%   49%   41%   40%                   -- 
 
 Legends:
   A:S: mod_overhead_time=2.67 participant=Array::Shuffle
   AN:S: mod_overhead_time=2.75 participant=Algorithm::Numerical::Shuffle
   L:U: mod_overhead_time=3.27 participant=List::Util
   LM:P: mod_overhead_time=4.9 participant=List::MoreUtils::PP
   LM:X: mod_overhead_time=4.5 participant=List::MoreUtils::XS
   LU:P: mod_overhead_time=4 participant=List::Util::PP
   perl -e1 (baseline): mod_overhead_time=0 participant=perl -e1 (baseline)

To display as an interactive HTML table on a browser, you can add option C<--format html+datatables>.

=head1 BENCHMARK NOTES

L<Algorithm::Numerical::Shuffle> is a bit faster than L<List::Util::PP> for
larger lists (thousands+) but of course in the real world one will use
L<List::Util> (XS implementation) anyway.

Why is L<List::MoreUtils::PP::samples> (v0.430 tested) returning the original
list?

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Bencher-Scenario-shuffle>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Bencher-Scenario-shuffle>.

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
L<Dist::Zilla::PluginBundle::Author::PERLANCAR>, and sometimes one or two other
Dist::Zilla plugin and/or Pod::Weaver::Plugin. Any additional steps required
beyond that are considered a bug and can be reported to me.

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2022 by perlancar <perlancar@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Bencher-Scenario-shuffle>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
