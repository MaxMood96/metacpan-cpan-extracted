package Log::Munger::App;

use 5.006;
use strict;
use warnings;
use App::Cmd::Setup -app;

=head1 NAME

Log::Munger::App - The App::Cmd application behind the log_munger command.

=cut

our $VERSION = '0.0.1';

# The options every subcommand accepts, as App::Cmd wants them.
#
# Takes the args App::Cmd hands a global_opt_spec.
#
# Returns a list of App::Cmd option tuples, currently help and version.
#
# version deliberately has no -v alias: a global -v would swallow the short
# form of subcommand options such as test_all's --verbose and dump_rule_file's
# --var. A leading -v still prints the version via prepare_command below.
sub global_opt_spec {
	return ( [ 'help|h' => "This usage screen." ], [ 'version' => "Print the version." ], );
}

# The App::Cmd hook that turns the raw command line into a command object.
#
# Overridden so a leading --version or -v dispatches to the built-in version
# command; App::Cmd parses the global option but nothing would otherwise act
# on it, leaving the flag to fall through to the usage screen.
#
# Args:
#
#     - @args :: The raw command line args, as App::Cmd passes them.
#
# Returns whatever App::Cmd's prepare_command returns.
sub prepare_command {
	my ( $self, @args ) = @_;
	if ( defined( $args[0] ) && ( $args[0] eq '--version' || $args[0] eq '-v' ) ) {
		return $self->SUPER::prepare_command('version');
	}
	return $self->SUPER::prepare_command(@args);
}

1;
