package WWW::Bund::API::NINA;
our $VERSION = '0.001';
# ABSTRACT: Adapter for NINA API (disaster warnings)

use Moo;
use namespace::clean;


has client => (is => 'ro', required => 1, weak_ref => 1);


sub dashboard {
    my ($self, $ars) = @_;
    $self->client->call('nina', 'nina_warnings', params => { ARS => $ars });
}


sub warning {
    my ($self, $identifier) = @_;
    $self->client->call('nina', 'nina_warning_json', params => { identifier => $identifier });
}


sub warning_geojson {
    my ($self, $identifier) = @_;
    $self->client->call('nina', 'nina_warning_geojson', params => { identifier => $identifier });
}


sub mapdata_katwarn  { shift->client->call('nina', 'nina_mapdata_katwarn') }


sub mapdata_biwapp   { shift->client->call('nina', 'nina_mapdata_biwapp') }


sub mapdata_mowas    { shift->client->call('nina', 'nina_mapdata_mowas') }


sub mapdata_dwd      { shift->client->call('nina', 'nina_mapdata_dwd') }


sub mapdata_lhp      { shift->client->call('nina', 'nina_mapdata_lhp') }


sub mapdata_police   { shift->client->call('nina', 'nina_mapdata_police') }


sub version          { shift->client->call('nina', 'nina_version') }


sub logos            { shift->client->call('nina', 'nina_logos') }


sub event_codes      { shift->client->call('nina', 'nina_event_codes') }


sub notfalltipps     { shift->client->call('nina', 'nina_notfalltipps') }


sub faqs             { shift->client->call('nina', 'nina_faqs') }


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WWW::Bund::API::NINA - Adapter for NINA API (disaster warnings)

=head1 VERSION

version 0.001

=head1 SYNOPSIS

    use WWW::Bund;

    my $bund = WWW::Bund->new;
    my $nina = $bund->nina;

    # Get warnings for region by ARS code
    my $warnings = $nina->dashboard('091620000000');  # Munich

    # Get specific warning details
    my $warning = $nina->warning($identifier);
    my $geojson = $nina->warning_geojson($identifier);

    # Get map data by provider
    my $katwarn = $nina->mapdata_katwarn;
    my $biwapp = $nina->mapdata_biwapp;
    my $mowas = $nina->mapdata_mowas;
    my $dwd = $nina->mapdata_dwd;

    # Metadata
    my $version = $nina->version;
    my $event_codes = $nina->event_codes;

=head1 DESCRIPTION

Type-safe adapter for the NINA (Notfall-Informations- und Nachrichten-App) API.
Provides access to disaster warnings, civil protection alerts, and emergency
information for Germany.

NINA aggregates warnings from multiple providers: KATWARN, BIWAPP, MOWAS (BBK),
DWD (weather warnings), LHP (flood warnings), and police.

=head2 client

L<WWW::Bund> client instance. Required. Weak reference.

=head2 dashboard

    my $warnings = $nina->dashboard($ars_code);

Get all active warnings for a region by ARS (Amtlicher Regionalschlüssel) code.
Returns ArrayRef of warning objects.

Example: C<091620000000> for Munich.

=head2 warning

    my $warning = $nina->warning($identifier);

Get detailed information for a specific warning by identifier. Returns HashRef
with warning details, affected areas, instructions, etc.

=head2 warning_geojson

    my $geojson = $nina->warning_geojson($identifier);

Get GeoJSON representation of warning area for mapping.

=head2 mapdata_katwarn

Get KATWARN map data for all active warnings.

=head2 mapdata_biwapp

Get BIWAPP map data for all active warnings.

=head2 mapdata_mowas

Get MOWAS (BBK/Federal Office of Civil Protection) map data.

=head2 mapdata_dwd

Get DWD (German Weather Service) warnings map data.

=head2 mapdata_lhp

Get LHP (flood warnings) map data.

=head2 mapdata_police

Get police warnings map data.

=head2 version

Get API version information.

=head2 logos

Get logos/icons for warning providers.

=head2 event_codes

Get list of event type codes and descriptions.

=head2 notfalltipps

Get emergency tips and guidelines (Notfalltipps).

=head2 faqs

Get frequently asked questions about NINA.

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
