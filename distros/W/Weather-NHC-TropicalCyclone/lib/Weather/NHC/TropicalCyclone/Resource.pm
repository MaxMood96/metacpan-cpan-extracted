package Weather::NHC::TropicalCyclone::Resource;

use strict;
use warnings;
use Dispatch::Fu qw/dispatch on xdefault xshift_and_deref/;

our %TEXT_RESOURCES = map { $_ => 1 } qw/
  publicAdvisory forecastAdvisory forecastDiscussion windSpeedProbabilities
/;

our %FILE_TYPES = (
    zipFile          => [qw/forecastTrack windWatchesWarnings trackCone initialWindExtent forecastWindRadiiGIS bestTrackGIS potentialStormSurgeFloodingGIS/],
    kmzFile          => [qw/forecastTrack windWatchesWarnings trackCone initialWindExtent forecastWindRadiiGIS bestTrackGIS earliestArrivalTimeTSWindsGIS mostLikelyTimeTSWindsGIS/],
    zipFile5km       => [qw/windSpeedProbabilitiesGIS/],
    zipFile0p5deg    => [qw/windSpeedProbabilitiesGIS/],
    kmzFile34kt      => [qw/windSpeedProbabilitiesGIS/],
    kmzFile50kt      => [qw/windSpeedProbabilitiesGIS/],
    kmzFile64kt      => [qw/windSpeedProbabilitiesGIS/],
    kmlFile          => [qw/stormSurgeWatchWarningGIS peakSurgeKML/],
    zipFileTidalMask => [qw/potentialStormSurgeFloodingGIS/],
);

sub text_resources { return [ sort keys %TEXT_RESOURCES ] }
sub file_types     { return { map { $_ => [ @{ $FILE_TYPES{$_} } ] } keys %FILE_TYPES } }

sub is_valid_file_type {
    my ( $class, $resource, $type ) = @_;
    return 0 if !defined $type || !exists $FILE_TYPES{$type};
    return scalar grep { $_ eq $resource } @{ $FILE_TYPES{$type} };
}

sub kind {
    my ( $class, $resource, $type ) = @_;

    return dispatch {
        my ( $resource, $type ) = xshift_and_deref @_;
        my $candidate = $TEXT_RESOURCES{$resource}
          ? q{text}
          : defined $type && $class->is_valid_file_type( $resource, $type )
          ? q{file}
          : q{unknown};
        xdefault $candidate, q{unknown};
    } [ $resource, $type ],
      on text    => sub { return q{text} },
      on file    => sub { return q{file} },
      on unknown => sub { return q{unknown} };
}

sub extension_for_type {
    my ( $class, $type ) = @_;
    return q{zip} if defined $type && $type =~ /^zipFile/;
    return q{kmz} if defined $type && $type =~ /^kmzFile/;
    return q{kml} if defined $type && $type eq q{kmlFile};
    return undef;
}

1;

__END__

=head1 NAME

Weather::NHC::TropicalCyclone::Resource - resource/type catalog for NHC storm products

=head1 DESCRIPTION

This internal module centralizes the product/type relationships that were
previously spread across many nearly-identical fetch methods.  The public methods
remain available in L<Weather::NHC::TropicalCyclone::Storm>; they delegate to this
catalog.

The catalog is intentionally structured so a future bulk-download API can filter
resources by logical product, representation, or extension without redesigning
the existing download code.

=cut
