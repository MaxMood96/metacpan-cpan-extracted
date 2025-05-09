use v5.14;
use warnings;
use Test::More 0.98;
use utf8;
use open IO => ':utf8', ':std';
use Data::Dumper;

use lib './t';
use Command;

use Text::ParseWords qw(shellwords);
use Getopt::Long 'Configure';
Configure qw(bundling no_getopt_compat no_ignore_case);
GetOptions(\my %opt,
           'data-section',	# produce data section
           'example',		# show command execution example
           'show',		# show test
           'number|n=i',	# select test number
) or die;

use File::Spec;
$ENV{HOME} = File::Spec->rel2abs('t/home');

use Data::Section::Simple qw(get_data_section);
my $expected = get_data_section;

use File::Slurper 'read_lines';
my $sh = $0 =~ s/\.t/.sh/r;
my @command = read_lines $sh or die;

if ($opt{show}) {
    for (keys @command) {
	printf "%4d: %s\n", $_, $command[$_];
    }
    exit;
}

if (defined(my $n = $opt{number})) {
    die "$n: invalid number\n" if $n > $#command;
    @command = $command[$n];
}

for (@command) {
    my @command = shellwords $_;
    if (-e (my $script = "script/$command[0]")) {
	$command[0] = $script;
    } else {
	unshift @command, '-S';
    }
    my $result = Command->new(@command)->exec();
    if ($opt{example}) {
	printf "\$ %s\n", $_;
	print $result;
    }
    elsif ($opt{'data-section'}) {
	printf "\@\@ %s\n", $_;
	print $result;
    }
    else {
	is($result, $expected->{$_}, $_);
    }
}

exit if %opt;

done_testing;

__DATA__

@@ cat-v t/week.txt
[38;5;236;48;5;189m··········································································[m[K⏎
[38;5;236;48;5;189m··[m[K[38;5;236;48;5;147m·2025····1月····令和7·[m[K[38;5;236;48;5;189m··[m[K[38;5;231;48;5;61m·2025····2月····令和7·[m[K[38;5;236;48;5;189m··[m[K[38;5;236;48;5;147m·········3月··········[m[K[38;5;236;48;5;189m··[m[K⏎
[38;5;236;48;5;189m··[m[K[38;5;236;48;5;189m·日·月·火·水·木·金·土·[m[K[38;5;236;48;5;189m··[m[K[38;5;236;48;5;189m·日·月·火·水·木·金·土·[m[K[38;5;236;48;5;189m··[m[K[38;5;236;48;5;189m·日·月·火·水·木·金·土·[m[K[38;5;236;48;5;189m··[m[K⏎
[38;5;236;48;5;189m··[m[K[38;5;236;48;5;147m···········1··2··3··4·[m[K[38;5;236;48;5;189m··[m[K[38;5;231;48;5;61m····················1·[m[K[38;5;236;48;5;189m··[m[K[38;5;236;48;5;147m····················1·[m[K[38;5;236;48;5;189m··[m[K⏎
[38;5;236;48;5;189m··[m[K[38;5;236;48;5;147m··5··6··7··8··9·10·11·[m[K[38;5;236;48;5;189m··[m[K[38;5;231;48;5;61m··2··3··4··5··6··7··8·[m[K[38;5;236;48;5;189m··[m[K[38;5;236;48;5;147m··2··3··4··5··6··7··8·[m[K[38;5;236;48;5;189m··[m[K⏎
[38;5;236;48;5;189m··[m[K[38;5;236;48;5;147m·12·13·14·15·16·17·18·[m[K[38;5;236;48;5;189m··[m[K[38;5;231;48;5;61m··9·[38;5;210;48;5;61m10[m[K[38;5;231;48;5;61m·11·12·13·14·15·[m[K[38;5;236;48;5;189m··[m[K[38;5;236;48;5;147m··9·10·11·12·13·14·15·[m[K[38;5;236;48;5;189m··[m[K⏎
[38;5;236;48;5;189m··[m[K[38;5;236;48;5;147m·19·20·21·22·23·24·25·[m[K[38;5;236;48;5;189m··[m[K[38;5;231;48;5;61m·16·17·18·19·20·21·22·[m[K[38;5;236;48;5;189m··[m[K[38;5;236;48;5;147m·16·17·18·19·20·21·22·[m[K[38;5;236;48;5;189m··[m[K⏎
[38;5;236;48;5;189m··[m[K[38;5;236;48;5;147m·26·27·28·29·30·31····[m[K[38;5;236;48;5;189m··[m[K[38;5;231;48;5;61m·23·24·25·26·27·28····[m[K[38;5;236;48;5;189m··[m[K[38;5;236;48;5;147m·23·24·25·26·27·28·29·[m[K[38;5;236;48;5;189m··[m[K⏎
[38;5;236;48;5;189m··[m[K[38;5;236;48;5;147m······················[m[K[38;5;236;48;5;189m··[m[K[38;5;231;48;5;61m······················[m[K[38;5;236;48;5;189m··[m[K[38;5;236;48;5;147m·30·31················[m[K[38;5;236;48;5;189m··[m[K⏎
[38;5;236;48;5;189m··········································································[m[K⏎
@@ cat-v t/week.txt -n
[38;5;236;48;5;189m                                                                          [m[K
[38;5;236;48;5;189m  [m[K[38;5;236;48;5;147m 2025    1月    令和7 [m[K[38;5;236;48;5;189m  [m[K[38;5;231;48;5;61m 2025    2月    令和7 [m[K[38;5;236;48;5;189m  [m[K[38;5;236;48;5;147m         3月          [m[K[38;5;236;48;5;189m  [m[K
[38;5;236;48;5;189m  [m[K[38;5;236;48;5;189m 日 月 火 水 木 金 土 [m[K[38;5;236;48;5;189m  [m[K[38;5;236;48;5;189m 日 月 火 水 木 金 土 [m[K[38;5;236;48;5;189m  [m[K[38;5;236;48;5;189m 日 月 火 水 木 金 土 [m[K[38;5;236;48;5;189m  [m[K
[38;5;236;48;5;189m  [m[K[38;5;236;48;5;147m           1  2  3  4 [m[K[38;5;236;48;5;189m  [m[K[38;5;231;48;5;61m                    1 [m[K[38;5;236;48;5;189m  [m[K[38;5;236;48;5;147m                    1 [m[K[38;5;236;48;5;189m  [m[K
[38;5;236;48;5;189m  [m[K[38;5;236;48;5;147m  5  6  7  8  9 10 11 [m[K[38;5;236;48;5;189m  [m[K[38;5;231;48;5;61m  2  3  4  5  6  7  8 [m[K[38;5;236;48;5;189m  [m[K[38;5;236;48;5;147m  2  3  4  5  6  7  8 [m[K[38;5;236;48;5;189m  [m[K
[38;5;236;48;5;189m  [m[K[38;5;236;48;5;147m 12 13 14 15 16 17 18 [m[K[38;5;236;48;5;189m  [m[K[38;5;231;48;5;61m  9 [38;5;210;48;5;61m10[m[K[38;5;231;48;5;61m 11 12 13 14 15 [m[K[38;5;236;48;5;189m  [m[K[38;5;236;48;5;147m  9 10 11 12 13 14 15 [m[K[38;5;236;48;5;189m  [m[K
[38;5;236;48;5;189m  [m[K[38;5;236;48;5;147m 19 20 21 22 23 24 25 [m[K[38;5;236;48;5;189m  [m[K[38;5;231;48;5;61m 16 17 18 19 20 21 22 [m[K[38;5;236;48;5;189m  [m[K[38;5;236;48;5;147m 16 17 18 19 20 21 22 [m[K[38;5;236;48;5;189m  [m[K
[38;5;236;48;5;189m  [m[K[38;5;236;48;5;147m 26 27 28 29 30 31    [m[K[38;5;236;48;5;189m  [m[K[38;5;231;48;5;61m 23 24 25 26 27 28    [m[K[38;5;236;48;5;189m  [m[K[38;5;236;48;5;147m 23 24 25 26 27 28 29 [m[K[38;5;236;48;5;189m  [m[K
[38;5;236;48;5;189m  [m[K[38;5;236;48;5;147m                      [m[K[38;5;236;48;5;189m  [m[K[38;5;231;48;5;61m                      [m[K[38;5;236;48;5;189m  [m[K[38;5;236;48;5;147m 30 31                [m[K[38;5;236;48;5;189m  [m[K
[38;5;236;48;5;189m                                                                          [m[K
@@ cat-v t/week.txt -n --esc=1
␛[38;5;236;48;5;189m                                                                          ␛[m␛[K
␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;236;48;5;147m 2025    1月    令和7 ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;231;48;5;61m 2025    2月    令和7 ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;236;48;5;147m         3月          ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K
␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;236;48;5;189m 日 月 火 水 木 金 土 ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;236;48;5;189m 日 月 火 水 木 金 土 ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;236;48;5;189m 日 月 火 水 木 金 土 ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K
␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;236;48;5;147m           1  2  3  4 ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;231;48;5;61m                    1 ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;236;48;5;147m                    1 ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K
␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;236;48;5;147m  5  6  7  8  9 10 11 ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;231;48;5;61m  2  3  4  5  6  7  8 ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;236;48;5;147m  2  3  4  5  6  7  8 ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K
␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;236;48;5;147m 12 13 14 15 16 17 18 ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;231;48;5;61m  9 ␛[38;5;210;48;5;61m10␛[m␛[K␛[38;5;231;48;5;61m 11 12 13 14 15 ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;236;48;5;147m  9 10 11 12 13 14 15 ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K
␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;236;48;5;147m 19 20 21 22 23 24 25 ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;231;48;5;61m 16 17 18 19 20 21 22 ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;236;48;5;147m 16 17 18 19 20 21 22 ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K
␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;236;48;5;147m 26 27 28 29 30 31    ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;231;48;5;61m 23 24 25 26 27 28    ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;236;48;5;147m 23 24 25 26 27 28 29 ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K
␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;236;48;5;147m                      ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;231;48;5;61m                      ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;236;48;5;147m 30 31                ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K
␛[38;5;236;48;5;189m                                                                          ␛[m␛[K
@@ cat-v t/week.txt -n --esc=+1
␛[38;5;236;48;5;189m                                                                          ␛[m␛[K
␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;236;48;5;147m 2025    1月    令和7 ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;231;48;5;61m 2025    2月    令和7 ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;236;48;5;147m         3月          ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K
␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;236;48;5;189m 日 月 火 水 木 金 土 ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;236;48;5;189m 日 月 火 水 木 金 土 ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;236;48;5;189m 日 月 火 水 木 金 土 ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K
␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;236;48;5;147m           1  2  3  4 ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;231;48;5;61m                    1 ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;236;48;5;147m                    1 ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K
␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;236;48;5;147m  5  6  7  8  9 10 11 ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;231;48;5;61m  2  3  4  5  6  7  8 ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;236;48;5;147m  2  3  4  5  6  7  8 ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K
␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;236;48;5;147m 12 13 14 15 16 17 18 ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;231;48;5;61m  9 ␛[38;5;210;48;5;61m10␛[m␛[K␛[38;5;231;48;5;61m 11 12 13 14 15 ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;236;48;5;147m  9 10 11 12 13 14 15 ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K
␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;236;48;5;147m 19 20 21 22 23 24 25 ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;231;48;5;61m 16 17 18 19 20 21 22 ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;236;48;5;147m 16 17 18 19 20 21 22 ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K
␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;236;48;5;147m 26 27 28 29 30 31    ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;231;48;5;61m 23 24 25 26 27 28    ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;236;48;5;147m 23 24 25 26 27 28 29 ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K
␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;236;48;5;147m                      ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;231;48;5;61m                      ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K␛[38;5;236;48;5;147m 30 31                ␛[m␛[K␛[38;5;236;48;5;189m  ␛[m␛[K
␛[38;5;236;48;5;189m                                                                          ␛[m␛[K
@@ cat-v t/week.txt -n --esc=+m
↰[38;5;236;48;5;189m                                                                          ↰[m↰[K
↰[38;5;236;48;5;189m  ↰[m↰[K↰[38;5;236;48;5;147m 2025    1月    令和7 ↰[m↰[K↰[38;5;236;48;5;189m  ↰[m↰[K↰[38;5;231;48;5;61m 2025    2月    令和7 ↰[m↰[K↰[38;5;236;48;5;189m  ↰[m↰[K↰[38;5;236;48;5;147m         3月          ↰[m↰[K↰[38;5;236;48;5;189m  ↰[m↰[K
↰[38;5;236;48;5;189m  ↰[m↰[K↰[38;5;236;48;5;189m 日 月 火 水 木 金 土 ↰[m↰[K↰[38;5;236;48;5;189m  ↰[m↰[K↰[38;5;236;48;5;189m 日 月 火 水 木 金 土 ↰[m↰[K↰[38;5;236;48;5;189m  ↰[m↰[K↰[38;5;236;48;5;189m 日 月 火 水 木 金 土 ↰[m↰[K↰[38;5;236;48;5;189m  ↰[m↰[K
↰[38;5;236;48;5;189m  ↰[m↰[K↰[38;5;236;48;5;147m           1  2  3  4 ↰[m↰[K↰[38;5;236;48;5;189m  ↰[m↰[K↰[38;5;231;48;5;61m                    1 ↰[m↰[K↰[38;5;236;48;5;189m  ↰[m↰[K↰[38;5;236;48;5;147m                    1 ↰[m↰[K↰[38;5;236;48;5;189m  ↰[m↰[K
↰[38;5;236;48;5;189m  ↰[m↰[K↰[38;5;236;48;5;147m  5  6  7  8  9 10 11 ↰[m↰[K↰[38;5;236;48;5;189m  ↰[m↰[K↰[38;5;231;48;5;61m  2  3  4  5  6  7  8 ↰[m↰[K↰[38;5;236;48;5;189m  ↰[m↰[K↰[38;5;236;48;5;147m  2  3  4  5  6  7  8 ↰[m↰[K↰[38;5;236;48;5;189m  ↰[m↰[K
↰[38;5;236;48;5;189m  ↰[m↰[K↰[38;5;236;48;5;147m 12 13 14 15 16 17 18 ↰[m↰[K↰[38;5;236;48;5;189m  ↰[m↰[K↰[38;5;231;48;5;61m  9 ↰[38;5;210;48;5;61m10↰[m↰[K↰[38;5;231;48;5;61m 11 12 13 14 15 ↰[m↰[K↰[38;5;236;48;5;189m  ↰[m↰[K↰[38;5;236;48;5;147m  9 10 11 12 13 14 15 ↰[m↰[K↰[38;5;236;48;5;189m  ↰[m↰[K
↰[38;5;236;48;5;189m  ↰[m↰[K↰[38;5;236;48;5;147m 19 20 21 22 23 24 25 ↰[m↰[K↰[38;5;236;48;5;189m  ↰[m↰[K↰[38;5;231;48;5;61m 16 17 18 19 20 21 22 ↰[m↰[K↰[38;5;236;48;5;189m  ↰[m↰[K↰[38;5;236;48;5;147m 16 17 18 19 20 21 22 ↰[m↰[K↰[38;5;236;48;5;189m  ↰[m↰[K
↰[38;5;236;48;5;189m  ↰[m↰[K↰[38;5;236;48;5;147m 26 27 28 29 30 31    ↰[m↰[K↰[38;5;236;48;5;189m  ↰[m↰[K↰[38;5;231;48;5;61m 23 24 25 26 27 28    ↰[m↰[K↰[38;5;236;48;5;189m  ↰[m↰[K↰[38;5;236;48;5;147m 23 24 25 26 27 28 29 ↰[m↰[K↰[38;5;236;48;5;189m  ↰[m↰[K
↰[38;5;236;48;5;189m  ↰[m↰[K↰[38;5;236;48;5;147m                      ↰[m↰[K↰[38;5;236;48;5;189m  ↰[m↰[K↰[38;5;231;48;5;61m                      ↰[m↰[K↰[38;5;236;48;5;189m  ↰[m↰[K↰[38;5;236;48;5;147m 30 31                ↰[m↰[K↰[38;5;236;48;5;189m  ↰[m↰[K
↰[38;5;236;48;5;189m                                                                          ↰[m↰[K
@@ cat-v t/week.txt -n --esc=+c
^[[38;5;236;48;5;189m                                                                          ^[[m^[[K
^[[38;5;236;48;5;189m  ^[[m^[[K^[[38;5;236;48;5;147m 2025    1月    令和7 ^[[m^[[K^[[38;5;236;48;5;189m  ^[[m^[[K^[[38;5;231;48;5;61m 2025    2月    令和7 ^[[m^[[K^[[38;5;236;48;5;189m  ^[[m^[[K^[[38;5;236;48;5;147m         3月          ^[[m^[[K^[[38;5;236;48;5;189m  ^[[m^[[K
^[[38;5;236;48;5;189m  ^[[m^[[K^[[38;5;236;48;5;189m 日 月 火 水 木 金 土 ^[[m^[[K^[[38;5;236;48;5;189m  ^[[m^[[K^[[38;5;236;48;5;189m 日 月 火 水 木 金 土 ^[[m^[[K^[[38;5;236;48;5;189m  ^[[m^[[K^[[38;5;236;48;5;189m 日 月 火 水 木 金 土 ^[[m^[[K^[[38;5;236;48;5;189m  ^[[m^[[K
^[[38;5;236;48;5;189m  ^[[m^[[K^[[38;5;236;48;5;147m           1  2  3  4 ^[[m^[[K^[[38;5;236;48;5;189m  ^[[m^[[K^[[38;5;231;48;5;61m                    1 ^[[m^[[K^[[38;5;236;48;5;189m  ^[[m^[[K^[[38;5;236;48;5;147m                    1 ^[[m^[[K^[[38;5;236;48;5;189m  ^[[m^[[K
^[[38;5;236;48;5;189m  ^[[m^[[K^[[38;5;236;48;5;147m  5  6  7  8  9 10 11 ^[[m^[[K^[[38;5;236;48;5;189m  ^[[m^[[K^[[38;5;231;48;5;61m  2  3  4  5  6  7  8 ^[[m^[[K^[[38;5;236;48;5;189m  ^[[m^[[K^[[38;5;236;48;5;147m  2  3  4  5  6  7  8 ^[[m^[[K^[[38;5;236;48;5;189m  ^[[m^[[K
^[[38;5;236;48;5;189m  ^[[m^[[K^[[38;5;236;48;5;147m 12 13 14 15 16 17 18 ^[[m^[[K^[[38;5;236;48;5;189m  ^[[m^[[K^[[38;5;231;48;5;61m  9 ^[[38;5;210;48;5;61m10^[[m^[[K^[[38;5;231;48;5;61m 11 12 13 14 15 ^[[m^[[K^[[38;5;236;48;5;189m  ^[[m^[[K^[[38;5;236;48;5;147m  9 10 11 12 13 14 15 ^[[m^[[K^[[38;5;236;48;5;189m  ^[[m^[[K
^[[38;5;236;48;5;189m  ^[[m^[[K^[[38;5;236;48;5;147m 19 20 21 22 23 24 25 ^[[m^[[K^[[38;5;236;48;5;189m  ^[[m^[[K^[[38;5;231;48;5;61m 16 17 18 19 20 21 22 ^[[m^[[K^[[38;5;236;48;5;189m  ^[[m^[[K^[[38;5;236;48;5;147m 16 17 18 19 20 21 22 ^[[m^[[K^[[38;5;236;48;5;189m  ^[[m^[[K
^[[38;5;236;48;5;189m  ^[[m^[[K^[[38;5;236;48;5;147m 26 27 28 29 30 31    ^[[m^[[K^[[38;5;236;48;5;189m  ^[[m^[[K^[[38;5;231;48;5;61m 23 24 25 26 27 28    ^[[m^[[K^[[38;5;236;48;5;189m  ^[[m^[[K^[[38;5;236;48;5;147m 23 24 25 26 27 28 29 ^[[m^[[K^[[38;5;236;48;5;189m  ^[[m^[[K
^[[38;5;236;48;5;189m  ^[[m^[[K^[[38;5;236;48;5;147m                      ^[[m^[[K^[[38;5;236;48;5;189m  ^[[m^[[K^[[38;5;231;48;5;61m                      ^[[m^[[K^[[38;5;236;48;5;189m  ^[[m^[[K^[[38;5;236;48;5;147m 30 31                ^[[m^[[K^[[38;5;236;48;5;189m  ^[[m^[[K
^[[38;5;236;48;5;189m                                                                          ^[[m^[[K
@@ cat-v t/week-tab.txt
[38;5;236;48;5;189m╺───────╺───────╺───────╺───────╺───────╺───────╺───────╺───────╺───────··[m[K⏎
[38;5;236;48;5;189m··[m[K[38;5;236;48;5;147m·2025····1月╺─··令和7·[m[K[38;5;236;48;5;189m··[m[K[38;5;231;48;5;61m·2025····2月╺─··令和7·[m[K[38;5;236;48;5;189m··[m[K[38;5;236;48;5;147m╺─────···3月╺─╺───────[m[K[38;5;236;48;5;189m··[m[K⏎
[38;5;236;48;5;189m···日·月·火·水·木·金·土····日·月·火·水·木·金·土····日·月·火·水·木·金·土···[m[K⏎
[38;5;236;48;5;189m··[m[K[38;5;236;48;5;147m╺─────·····1╺─2··3··4·[m[K[38;5;236;48;5;189m··[m[K[38;5;231;48;5;61m╺─────╺───────······1·[m[K[38;5;236;48;5;189m··[m[K[38;5;236;48;5;147m╺─────╺───────······1·[m[K[38;5;236;48;5;189m··[m[K⏎
[38;5;236;48;5;189m··[m[K[38;5;236;48;5;147m··5··6··7··8╺─9·10·11·[m[K[38;5;236;48;5;189m··[m[K[38;5;231;48;5;61m··2··3··4··5╺─6··7··8·[m[K[38;5;236;48;5;189m··[m[K[38;5;236;48;5;147m··2··3··4··5╺─6··7··8·[m[K[38;5;236;48;5;189m··[m[K⏎
[38;5;236;48;5;189m··[m[K[38;5;236;48;5;147m·12·13·14·15·16·17·18·[m[K[38;5;236;48;5;189m··[m[K[38;5;231;48;5;61m··9·[38;5;210;48;5;61m10[m[K[38;5;231;48;5;61m·11·12·13·14·15·[m[K[38;5;236;48;5;189m··[m[K[38;5;236;48;5;147m··9·10·11·12·13·14·15·[m[K[38;5;236;48;5;189m··[m[K⏎
[38;5;236;48;5;189m··[m[K[38;5;236;48;5;147m·19·20·21·22·23·24·25·[m[K[38;5;236;48;5;189m··[m[K[38;5;231;48;5;61m·16·17·18·19·20·21·22·[m[K[38;5;236;48;5;189m··[m[K[38;5;236;48;5;147m·16·17·18·19·20·21·22·[m[K[38;5;236;48;5;189m··[m[K⏎
[38;5;236;48;5;189m··[m[K[38;5;236;48;5;147m·26·27·28·29·30·31╺───[m[K[38;5;236;48;5;189m··[m[K[38;5;231;48;5;61m·23·24·25·26·27·28╺───[m[K[38;5;236;48;5;189m··[m[K[38;5;236;48;5;147m·23·24·25·26·27·28·29·[m[K[38;5;236;48;5;189m··[m[K⏎
[38;5;236;48;5;189m··[m[K[38;5;236;48;5;147m╺─────╺───────╺───────[m[K[38;5;236;48;5;189m··[m[K[38;5;231;48;5;61m╺─────╺───────╺───────[m[K[38;5;236;48;5;189m··[m[K[38;5;236;48;5;147m·30·31╺───────╺───────[m[K[38;5;236;48;5;189m··[m[K⏎
[38;5;236;48;5;189m╺───────╺───────╺───────╺───────╺───────╺───────╺───────╺───────╺───────··[m[K⏎
