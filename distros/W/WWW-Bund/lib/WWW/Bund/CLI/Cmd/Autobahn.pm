package WWW::Bund::CLI::Cmd::Autobahn;
our $VERSION = '0.002';
# ABSTRACT: Autobahn App API commands

use Moo;
use MooX::Cmd;
use MooX::Options protect_argv => 0;


with 'WWW::Bund::CLI::Role::APICommand';

sub api_id { 'autobahn' }

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WWW::Bund::CLI::Cmd::Autobahn - Autobahn App API commands

=head1 VERSION

version 0.002

=head1 SYNOPSIS

    bund autobahn                     # Show help
    bund autobahn roads               # List all Autobahn roads
    bund autobahn roadworks A7        # Roadworks on A7
    bund autobahn webcams A7          # Webcams on A7
    bund autobahn warnings A7         # Warnings on A7
    bund autobahn closures A7         # Closures on A7
    bund autobahn charging-stations A7
    bund autobahn parking-lorries A7

=head1 DESCRIPTION

CLI commands for the Autobahn App API (traffic, roadworks, webcams, warnings,
charging stations). Uses L<WWW::Bund::CLI::Role::APICommand> for dispatch.

See L<WWW::Bund::API::Autobahn> for library interface.

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
