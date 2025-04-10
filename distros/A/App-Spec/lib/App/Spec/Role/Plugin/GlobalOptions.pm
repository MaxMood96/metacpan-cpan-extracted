# ABSTRACT: Plugins for adding options should use this role
use strict;
use warnings;
package App::Spec::Role::Plugin::GlobalOptions;

our $VERSION = 'v0.15.0'; # VERSION

use Moo::Role;

requires 'install_options';

with 'App::Spec::Role::Plugin';

1;

__END__

=pod

=head1 NAME

App::Spec::Role::Plugin::GlobalOptions - Plugins for adding options should use this role

=head1 DESCRIPTION

See L<App::Spec::Plugin::Help> for an example.

=head1 REQUIRED METHODS

=over 4

=item install_options

This should return an arrayref of options:

    [
        {
            name => "help",
            summary: "Show command help",
            ...,
        },
    ]



=back
