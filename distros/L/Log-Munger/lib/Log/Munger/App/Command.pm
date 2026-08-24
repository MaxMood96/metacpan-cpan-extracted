package Log::Munger::App::Command;
use App::Cmd::Setup -command;

=head1 NAME

Log::Munger::App::Command - Base class for log_munger subcommands.

=cut

# The App::Cmd validation hook. Handles --help by dispatching to the help
# command for the current subcommand and exiting, then hands everything else to
# the subcommand's own validate method.
#
# Args:
#
#     - $opt :: The parsed options hash ref, as App::Cmd passes it.
#
#     - $args :: Array ref of the remaining command line args.
#
# Returns whatever the subcommand's validate returns, or exits for --help.
sub validate_args {
	my ( $self, $opt, $args ) = @_;
	if ( $opt->{help} ) {
		my ($command) = $self->command_names;
		$self->app->execute_command( $self->app->prepare_command( "help", $command ) );
		exit;
	}
	$self->validate( $opt, $args );
}

return 1;
