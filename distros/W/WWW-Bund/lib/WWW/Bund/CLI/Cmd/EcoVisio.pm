package WWW::Bund::CLI::Cmd::EcoVisio;
our $VERSION = '0.001';
# ABSTRACT: Eco-Visio (Fahrrad-Zähler) API command

use Moo;
use MooX::Cmd;
use MooX::Options protect_argv => 0;


with 'WWW::Bund::CLI::Role::APICommand';

sub api_id { 'eco_visio' }

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WWW::Bund::CLI::Cmd::EcoVisio - Eco-Visio (Fahrrad-Zähler) API command

=head1 VERSION

version 0.001

=head1 SYNOPSIS

    bund eco-visio sites    # List bicycle counter sites
    bund eco-visio data     # Get counter data

=head1 DESCRIPTION

CLI commands for Eco-Visio API (bicycle traffic counter data). Uses L<WWW::Bund::CLI::Role::APICommand>.

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
