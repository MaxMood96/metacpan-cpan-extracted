package WWW::Bund::CLI::Cmd::Pegel;
our $VERSION = '0.002';
# ABSTRACT: Pegel Online API commands

use Moo;
use MooX::Cmd;
use MooX::Options protect_argv => 0;


with 'WWW::Bund::CLI::Role::APICommand';

sub api_id { 'pegel_online' }

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WWW::Bund::CLI::Cmd::Pegel - Pegel Online API commands

=head1 VERSION

version 0.002

=head1 SYNOPSIS

    bund pegel                          # Show help
    bund pegel stations                 # List all gauging stations
    bund pegel station UUID             # Get station details
    bund pegel waters                   # List all waters
    bund pegel timeseries STATION TS    # Get timeseries metadata
    bund pegel measurements STATION TS  # Get measurements

=head1 DESCRIPTION

CLI commands for Pegel Online API (water level gauges and measurements for
German rivers and waterways). Uses L<WWW::Bund::CLI::Role::APICommand>.

Alias: C<pegel> maps to C<pegel_online>.

See L<WWW::Bund::API::PegelOnline> for library interface.

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
