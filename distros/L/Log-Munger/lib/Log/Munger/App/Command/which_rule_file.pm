package Log::Munger::App::Command::which_rule_file;

use strict;
use warnings;
use Log::Munger::App -command;
use Log::Munger::WhichRuleFile;

sub opt_spec {
	return ( [ 'f=s', 'Rule file to locate.' ], );
}

sub abstract { "Print the path a rule file name resolves to" }

sub description {
	"Prints the path a rule file name resolves to, searching the directory named by the
LOG_MUNGER_RULES_DIR environment variable (when set), then /etc/log_munger/rules, then
/usr/local/etc/log_munger/rules, then the dist share dir. A name beginning with /, ./, or ../ is
used as a path instead of being searched for.

Exit codes:
- 0 :: found
- 1 :: not found
- 255 :: error
";
} ## end sub description

sub validate { return 1 }

sub execute {
	my ( $self, $opts, $args ) = @_;

	if ( !defined( $opts->{'f'} ) ) {
		die('Nothing specified for -f');
	}

	my $file_location = Log::Munger::WhichRuleFile->rule_file_location( 'file' => $opts->{'f'} );

	if ( !defined($file_location) ) {
		exit 1;
	}

	print $file_location. "\n";

	exit 0;
} ## end sub execute

1;
