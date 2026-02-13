package WWW::Bund::CLI::Cmd::Nina;
our $VERSION = '0.001';
# ABSTRACT: NINA Warn-App API commands

use Moo;
use MooX::Cmd;
use MooX::Options protect_argv => 0;


with 'WWW::Bund::CLI::Role::APICommand';

sub api_id { 'nina' }

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WWW::Bund::CLI::Cmd::Nina - NINA Warn-App API commands

=head1 VERSION

version 0.001

=head1 SYNOPSIS

    bund nina                          # Show help
    bund nina dashboard ARS            # Warnings by region
    bund nina warning IDENTIFIER       # Specific warning
    bund nina mapdata-katwarn          # KATWARN map data
    bund nina mapdata-mowas            # MOWAS map data
    bund nina version                  # API version

=head1 DESCRIPTION

CLI commands for NINA (Notfall-Informations- und Nachrichten-App) disaster
warnings and civil protection alerts. Uses L<WWW::Bund::CLI::Role::APICommand>.

See L<WWW::Bund::API::NINA> for library interface.

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
