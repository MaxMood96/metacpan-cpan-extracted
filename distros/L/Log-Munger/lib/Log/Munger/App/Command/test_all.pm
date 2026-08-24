package Log::Munger::App::Command::test_all;

use strict;
use warnings;
use Log::Munger::App -command;
use Log::Munger::RulesTest     ();
use Log::Munger::WhichRuleFile ();

sub opt_spec {
	return ( [ 'verbose|v', 'Print each error and warning, not just counts.' ], );
}

sub abstract { "Run the built-in tests for every discoverable rule file" }

sub description {
	"Runs Log::Munger::RulesTest over every rule file found across the search path and prints a
pass/fail summary. Add -v to print each error and warning rather than just the counts.

Exits non-zero if any file has errors or fails to load, which makes this the thing to run in
CI.
";
}

sub validate { return 1 }

sub execute {
	my ( $self, $opts, $args ) = @_;

	# only the names are wanted, since each one is handed to
	# Log::Munger::RulesTest, which resolves names itself
	my @names = sort( keys( %{ Log::Munger::WhichRuleFile->available_rule_files } ) );
	if ( !@names ) {
		print "no rule files found\n";
		return;
	}

	my $failed = 0;
	foreach my $name (@names) {
		my $res = Log::Munger::RulesTest->test( 'file' => $name );

		if ( defined( $res->{'fatal'} ) ) {
			$failed++;
			printf( "FAIL  %-24s fatal: %s\n", $name, $res->{'fatal'} );
			next;
		}

		my $errors   = scalar( @{ $res->{'errors'} } );
		my $warnings = scalar( @{ $res->{'warnings'} } );
		$failed++ if ($errors);
		printf( "%-5s %-24s %d error(s), %d warning(s)\n", ( $errors ? 'FAIL' : 'ok' ), $name, $errors, $warnings );

		if ( $opts->{'verbose'} ) {
			print "        ERROR: $_\n" for ( @{ $res->{'errors'} } );
			print "        warn:  $_\n" for ( @{ $res->{'warnings'} } );
		}
	} ## end foreach my $name (@names)

	printf( "\n%d file(s), %d failed\n", scalar(@names), $failed );
	exit(1) if ($failed);

	return;
} ## end sub execute

1;
