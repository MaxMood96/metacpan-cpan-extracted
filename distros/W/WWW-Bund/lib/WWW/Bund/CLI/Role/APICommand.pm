package WWW::Bund::CLI::Role::APICommand;
our $VERSION = '0.002';
# ABSTRACT: Shared role for API command dispatch

use Moo::Role;


requires 'api_id';


sub execute {
    my ($self, $args, $chain) = @_;
    my $main = $chain->[0];
    my $api = $self->api_id;

    if (!@$args) {
        $main->cmd_api_help($api);
        return;
    }

    my @call_args = @$args;
    my $action = shift @call_args;

    my $rc = $main->cmd_call($api, $action, @call_args);
    exit($rc) if $rc;
}


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WWW::Bund::CLI::Role::APICommand - Shared role for API command dispatch

=head1 VERSION

version 0.002

=head1 SYNOPSIS

    package WWW::Bund::CLI::Cmd::MyAPI;
    use Moo;
    use MooX::Cmd;
    use MooX::Options protect_argv => 0;

    with 'WWW::Bund::CLI::Role::APICommand';

    sub api_id { 'my_api' }

    1;

=head1 DESCRIPTION

Shared role for API-specific CLI command classes. Provides generic C<execute>
method that dispatches to the root CLI's C<cmd_call> or C<cmd_api_help>.

Consuming classes only need to implement C<api_id> method to return the API
identifier. This keeps API command classes minimal (typically 10 lines).

=head2 Execution Flow

=over

=item 1. If no args: show API help via C<cmd_api_help>

=item 2. Otherwise: extract action from first arg, call C<cmd_call>

=item 3. Exit with return code if call fails

=back

=head1 REQUIRED METHODS

=head2 api_id

    sub api_id { 'autobahn' }

Return the API identifier string used for endpoint lookup.

=head2 execute

Generic command execution. Handles both help display and API call dispatch.

=head1 SUPPORT

=head2 Issues

Please report bugs and feature requests on GitHub at
L<https://github.com/Getty/p5-www-bund/issues>.

=head1 CONTRIBUTING

Contributions are welcome! Please fork the repository and submit a pull request.

=head1 AUTHOR

Torsten Raudssus <torsten@raudssus.de>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2026 by Torsten Raudssus.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
