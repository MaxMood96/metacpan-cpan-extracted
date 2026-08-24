package Log::Munger::App::Command::list;

use strict;
use warnings;
use Log::Munger::App -command;
use Log::Munger::WhichRuleFile ();

sub opt_spec {
	return ( [ 'paths|p', 'Also show the resolved path of each rule file.' ], );
}

sub abstract { "List the rule files discoverable across the search path" }

sub description {
	"Lists the rule files found across the directory named by the LOG_MUNGER_RULES_DIR environment
variable (when set), /etc/log_munger/rules, /usr/local/etc/log_munger/rules, and
the dist share dir, in that precedence order. A name found in an earlier directory shadows the
same name in a later one, and only the one that would actually be used is listed.

Add -p to see what each name resolves to.
";
}

sub validate { return 1 }

sub execute {
	my ( $self, $opts, $args ) = @_;

	my $available = Log::Munger::WhichRuleFile->available_rule_files;

	foreach my $name ( sort( keys( %{$available} ) ) ) {
		if ( $opts->{'paths'} ) {
			printf( "%-24s %s\n", $name, $available->{$name} );
		} else {
			print "$name\n";
		}
	}

	return;
} ## end sub execute

1;
