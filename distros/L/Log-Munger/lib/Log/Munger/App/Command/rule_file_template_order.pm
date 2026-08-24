package Log::Munger::App::Command::rule_file_template_order;

use strict;
use warnings;
use Log::Munger::App -command;
use Log::Munger::RulesTemplateOrder;
use YAML::XS qw(Dump);

sub opt_spec {
	return ( [ 'f=s', 'Rule file to read.', { 'default' => 'base' } ], [ 'd', 'Print depend info.' ], );
}

sub abstract { "Show the order a rule file's templated vars get resolved in" }

sub description {
	"A rule file's vars_templated entries reference each other, so they have to be resolved in
dependency order. This prints that order.

With -d it prints the dependency map that order was worked out from instead, which is what to
look at when a var is not resolving.
";
}

sub validate { return 1 }

sub execute {
	my ( $self, $opts, $args ) = @_;

	my $results;
	if ( !$opts->{'d'} ) {
		$results = Log::Munger::RulesTemplateOrder->order_for_rules_file( 'file' => $opts->{'f'} );
	} else {
		$results = Log::Munger::RulesTemplateOrder->depends_for_rules_file( 'file' => $opts->{'f'} );
	}

	print Dump($results);
} ## end sub execute

1;
