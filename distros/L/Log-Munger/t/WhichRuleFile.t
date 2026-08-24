#!perl
use 5.006;
use strict;
use warnings;
use Test::More;

BEGIN {
	use_ok('Log::Munger::WhichRuleFile') || print "Bail out!\n";
}

my $tests = 3;

my $worked = 0;
eval {
	my $file_location = Log::Munger::WhichRuleFile->rule_file_location( 'file' => 'postfix' );
	if ( !defined($file_location) ) {
		die(
			'Log::Munger::WhichRuleFile->rule_file_location(file=>"postfix") returned undef instead of the path to share/postfix.yaml'
		);
	}

	if (ref($file_location) ne ''){
		die('$file_location is of ref type "'.ref($file_location).'" and not ""');
	}
	
	if ($file_location !~ /\.yaml$/){
		die('"'.$file_location.'" does not end in .yaml');
	}

	if (! -f $file_location){
		die('"'.$file_location.'" does not exist or is not a file');
	}

	$worked = 1;
};
ok( $worked eq '1', 'rule file locate' ) or diag( "rule file locate test failed ... " . $@ );

$worked = 0;
eval {
	my $file_location
		= Log::Munger::WhichRuleFile->rule_file_location( 'file' => 'definitely_does_not_exist303d01df34' );
	if ( defined($file_location) ) {
		die('Log::Munger::WhichRuleFile->rule_file_location(file=>"definitely_does_not_exist303d01df34") returned "'.$file_location.'" instead of undef');
	}
	$worked = 1;
};
ok( $worked eq '1', 'rule file locate2' ) or diag( "rule file locate2 test failed ... " . $@ );

done_testing($tests);
