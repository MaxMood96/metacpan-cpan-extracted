#! perl -w
	# A poor-man indicator of a crash
	my $SELF;
	BEGIN { ($SELF = __FILE__) =~ s(.*[/\\])();
	   open CR, ">tst-run-$SELF" and close CR}	# touch a file
	END {unlink "tst-run-$SELF"}			# remove it - unless we crash
delete $ENV{DISPLAY} if $ENV{AUTOMATED_TESTING};
$file = __FILE__;
$file =~ m|^(.*)[\\/]([^\\/.]*)\.t$|s or die;
$dir = $1;
$name = $2;
$name =~ s/^55_//;
$long_bits = 8 * length pack( ($] < 5.006 ? 'L' : 'L!'), 0);
$long_bits = 64 if $^O =~ /^MSWin/i and 8 == length pack 'p', 'dfd';
$dir1 = "CHANGE_ME";
$dir1 = "$dir/../$dir1" unless $dir1 =~ m|^([a-z]:)?[\\/]|i;
@ARGV = "$dir1/src/test/$long_bits/$name";
@ARGV = "$dir1/src/test/32/$name" unless -r $ARGV[0];
do './test_eng/Testout.pm';
die if $@;
