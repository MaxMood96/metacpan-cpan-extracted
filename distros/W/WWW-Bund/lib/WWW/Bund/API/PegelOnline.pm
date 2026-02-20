package WWW::Bund::API::PegelOnline;
our $VERSION = '0.002';
# ABSTRACT: Adapter for Pegel-Online API (water levels)

use Moo;
use namespace::clean;


has client => (is => 'ro', required => 1, weak_ref => 1);


sub stations {
    my ($self) = @_;
    $self->client->call('pegel_online', 'pegel_online_stations');
}


sub station {
    my ($self, $station) = @_;
    $self->client->call('pegel_online', 'pegel_online_station', params => { station => $station });
}


sub waters {
    my ($self) = @_;
    $self->client->call('pegel_online', 'pegel_online_waters');
}


sub timeseries {
    my ($self, $station, $timeseries) = @_;
    $self->client->call('pegel_online', 'pegel_online_timeseries',
        params => { station => $station, timeseries => $timeseries },
    );
}


sub measurements {
    my ($self, $station, $timeseries) = @_;
    $self->client->call('pegel_online', 'pegel_online_measurements',
        params => { station => $station, timeseries => $timeseries },
    );
}


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WWW::Bund::API::PegelOnline - Adapter for Pegel-Online API (water levels)

=head1 VERSION

version 0.002

=head1 SYNOPSIS

    use WWW::Bund;

    my $bund = WWW::Bund->new;
    my $pegel = $bund->pegel_online;

    # List all gauging stations
    my $stations = $pegel->stations;

    # Get specific station details
    my $station = $pegel->station($uuid);

    # List all waters (rivers, lakes)
    my $waters = $pegel->waters;

    # Get timeseries metadata
    my $ts = $pegel->timeseries($station_uuid, $timeseries_uuid);

    # Get actual measurements
    my $measurements = $pegel->measurements($station_uuid, $timeseries_uuid);

=head1 DESCRIPTION

Type-safe adapter for the Pegel-Online API, providing access to water level
gauges and measurements for German rivers and waterways.

=head2 client

L<WWW::Bund> client instance. Required. Weak reference.

=head2 stations

    my $stations = $pegel->stations;

List all gauging stations. Returns ArrayRef of station objects with UUID,
name, water, coordinates, etc.

=head2 station

    my $station = $pegel->station($uuid);

Get detailed information for a specific station by UUID.

=head2 waters

    my $waters = $pegel->waters;

List all waters (rivers, lakes). Returns ArrayRef of water objects.

=head2 timeseries

    my $ts = $pegel->timeseries($station_uuid, $timeseries_uuid);

Get metadata for a specific timeseries (measurement type) at a station.

=head2 measurements

    my $measurements = $pegel->measurements($station_uuid, $timeseries_uuid);

Get actual water level measurements for a timeseries. Returns ArrayRef of
measurement objects with timestamps and values.

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
