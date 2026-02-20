package WWW::Bund::API::DWD;
our $VERSION = '0.002';
# ABSTRACT: Adapter for DWD API (weather data)

use Moo;
use namespace::clean;


has client => (is => 'ro', required => 1, weak_ref => 1);


sub station_overview {
    my ($self, %params) = @_;
    $self->client->call('dwd', 'dwd_station_overview',
        %params ? (params => \%params) : (),
    );
}


sub warnings_nowcast {
    my ($self) = @_;
    $self->client->call('dwd', 'dwd_warnings_nowcast');
}


sub municipality_warnings {
    my ($self) = @_;
    $self->client->call('dwd', 'dwd_municipality_warnings');
}


sub coast_warnings {
    my ($self) = @_;
    $self->client->call('dwd', 'dwd_coast_warnings');
}


sub crowd_reports {
    my ($self) = @_;
    $self->client->call('dwd', 'dwd_crowd_reports');
}


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WWW::Bund::API::DWD - Adapter for DWD API (weather data)

=head1 VERSION

version 0.002

=head1 SYNOPSIS

    use WWW::Bund;

    my $bund = WWW::Bund->new;
    my $dwd = $bund->dwd;

    # Weather stations
    my $stations = $dwd->station_overview;
    my $stations = $dwd->station_overview(stationIds => '10865');

    # Weather warnings
    my $nowcast = $dwd->warnings_nowcast;
    my $municipality = $dwd->municipality_warnings;
    my $coast = $dwd->coast_warnings;

    # Crowd-sourced reports
    my $reports = $dwd->crowd_reports;

=head1 DESCRIPTION

Type-safe adapter for the DWD (Deutscher Wetterdienst / German Weather Service)
API. Provides access to weather warnings, station data, and crowd-sourced
weather reports.

=head2 client

L<WWW::Bund> client instance. Required. Weak reference.

=head2 station_overview

    my $stations = $dwd->station_overview;
    my $station = $dwd->station_overview(stationIds => '10865');

Get overview of weather stations. Can filter by station IDs.

=head2 warnings_nowcast

Get current weather warnings (nowcast).

=head2 municipality_warnings

Get weather warnings by municipality (Gemeinde).

=head2 coast_warnings

Get coastal weather warnings (Küstenwarnungen).

=head2 crowd_reports

Get crowd-sourced weather reports.

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
