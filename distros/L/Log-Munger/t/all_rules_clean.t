#!perl
use 5.006;
use strict;
use warnings;
use Test::More;
use File::ShareDir ();
use FindBin        ();

BEGIN {
	use_ok('Log::Munger::RulesTest') || print "Bail out!\n";
}

# test the working tree's rule files rather than whatever copy happens to be
# installed; without this a stale installed share dir shadows the tree
$ENV{'LOG_MUNGER_RULES_DIR'} = $FindBin::Bin . '/../share' if ( -d $FindBin::Bin . '/../share' );

#
# Discover every shipped rule file and assert each one tests clean: no fatal,
# no errors, and full test coverage (no "lacks any tests" warnings). This is
# the only place the shipped files' own tests are run, so it is deliberately
# discovery-driven -- a newly added rule file cannot ship untested, and no
# other test file needs to repeat the check for a file it happens to use.
#
# base is included. It carries no rules: section, only the primitive vars every
# other file inherits, but those vars have vars_tests of their own and this is
# what runs them.
#
# A missing share dir bails rather than skipping. Skipping would take every
# rule file's coverage with it and still report a green run, and the dir is
# only missing when the distribution has not been built, which is a broken
# test environment rather than a condition to tolerate.
#
my $share = $ENV{'LOG_MUNGER_RULES_DIR'};
if ( !defined($share) || !-d $share ) {
	eval { $share = File::ShareDir::dist_dir('Log-Munger'); };
}
if ( !defined($share) || !-d $share ) {
	BAIL_OUT('neither the tree share dir nor the dist share dir was found');
}

my @files = sort glob("$share/*.yaml");
ok( scalar(@files) > 0, "found rule files in $share" );

foreach my $path (@files) {
	my ($name) = $path =~ m{([^/]+)\.yaml\z};

	my $res = Log::Munger::RulesTest->test( 'file' => $name );

	is( $res->{'fatal'}, undef, "$name: no fatal" )
		or diag( $res->{'fatal'} );
	is( scalar( @{ $res->{'errors'} } ), 0, "$name: no errors" )
		or diag( "errors:\n" . join( "\n", @{ $res->{'errors'} } ) );

	my @lacks = grep {/lacks any tests/} @{ $res->{'warnings'} };
	is( scalar(@lacks), 0, "$name: full test coverage (no untested vars/rules)" )
		or diag( "untested:\n" . join( "\n", @lacks ) );

	# every gate is named by at least one test. A gate is not a detail of the
	# patterns under it -- get it wrong and the daemon goes unmatched while every
	# pattern test still passes, so an unexercised one is treated the same as an
	# untested rule rather than left as a warning.
	my @ungated = grep {/gated but no test names a program/} @{ $res->{'warnings'} };
	is( scalar(@ungated), 0, "$name: every gate is exercised by a test" )
		or diag( "unexercised gates:\n" . join( "\n", @ungated ) );

	# and every numeric convert. A convert that stops running is the quietest
	# thing in a rule file to get wrong -- the field is still captured and the
	# value is still right, it just arrives as a string where a consumer
	# expected a number
	my @unconverted = grep {/no test lists as numeric/} @{ $res->{'warnings'} };
	is( scalar(@unconverted), 0, "$name: every numeric convert is exercised by a test" )
		or diag( "unexercised converts:\n" . join( "\n", @unconverted ) );

	# and every decompose is checked as the rule uses it, not just in the
	# isolation its own tests give it
	my @unwired = grep {/no test says it produces/} @{ $res->{'warnings'} };
	is( scalar(@unwired), 0, "$name: every decompose is checked where it is wired in" )
		or diag( "unchecked decomposes:\n" . join( "\n", @unwired ) );
}

done_testing();
