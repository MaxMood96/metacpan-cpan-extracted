package Log::Munger::App::Command::test_rule_file;

use strict;
use warnings;
use Log::Munger::App -command;
use Log::Munger::RulesTest;
use YAML::XS qw(Dump);

sub opt_spec {
	return ( [ 'f=s', 'Rule file to read.', { 'default' => 'base' } ], );
}

sub abstract { "Run the built-in tests for one rule file" }

sub description {
	"Runs Log::Munger::RulesTest over a single rule file and dumps the whole result as YAML: a
fatal load error if it would not load, then every error and warning found.

Use test_all instead for a pass/fail summary of every rule file.
";
}

sub validate { return 1 }

sub execute {
	my ( $self, $opts, $args ) = @_;

	my $rules = Log::Munger::RulesTest->test( 'file' => $opts->{'f'} );

	print Dump($rules);

}

1;
