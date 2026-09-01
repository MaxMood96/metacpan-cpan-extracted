package Weather::NHC::TropicalCyclone::Validation;

use strict;
use warnings;
use Scalar::Util qw/looks_like_number/;

our @REQUIRED_STORM_FIELDS = qw/id binNumber name classification/;

our %CLASSIFICATIONS = (
    TD  => q{Tropical Depression},
    STD => q{Subtropical Depression},
    TS  => q{Tropical Storm},
    HU  => q{Hurricane},
    STS => q{Subtropical Storm},
    PTC => q{Post-tropical Cyclone / Remnants},
    TY  => q{Typhoon},
    PC  => q{Potential Tropical Cyclone},
);

our %KNOWN_STORM_FIELDS = map { $_ => 1 } qw/
  id binNumber name classification intensity pressure latitude longitude
  latitudeNumeric longitudeNumeric movementDir movementSpeed lastUpdate
  publicAdvisory forecastAdvisory windSpeedProbabilities forecastDiscussion
  forecastGraphics forecastTrack windWatchesWarnings trackCone initialWindExtent
  forecastWindRadiiGIS bestTrackGIS earliestArrivalTimeTSWindsGIS
  mostLikelyTimeTSWindsGIS windSpeedProbabilitiesGIS stormSurgeWatchWarningGIS
  potentialStormSurgeFloodingGIS peakSurgeKML
/;

sub classifications { return { %CLASSIFICATIONS } }
sub known_storm_fields { return [ sort keys %KNOWN_STORM_FIELDS ] }

sub validate {
    my ( $class, $data ) = @_;
    my ( @errors, @warnings );

    if ( ref $data ne q{HASH} ) {
        push @errors, q{NHC JSON root must be an object};
        return { errors => \@errors, warnings => \@warnings };
    }

    if ( ref $data->{activeStorms} ne q{ARRAY} ) {
        push @errors, q{NHC JSON root must contain an activeStorms array};
        return { errors => \@errors, warnings => \@warnings };
    }

    for my $index ( 0 .. $#{ $data->{activeStorms} } ) {
        my $storm = $data->{activeStorms}->[$index];
        if ( ref $storm ne q{HASH} ) {
            push @errors, "activeStorms[$index] must be an object";
            next;
        }

        for my $field (@REQUIRED_STORM_FIELDS) {
            push @errors, "activeStorms[$index] is missing required field '$field'"
              if !exists $storm->{$field} || !defined $storm->{$field} || $storm->{$field} eq q{};
        }

        if ( defined $storm->{classification} && !exists $CLASSIFICATIONS{ $storm->{classification} } ) {
            push @errors, "activeStorms[$index] has unknown classification '$storm->{classification}'";
        }

        if ( defined $storm->{binNumber} && $storm->{binNumber} !~ /^(?:AT|EP|CP)[1-5]$/i ) {
            push @errors, "activeStorms[$index] has unexpected binNumber '$storm->{binNumber}'";
        }

        if ( defined $storm->{id} && $storm->{id} !~ /^(?:al|ep|cp)\d{2}\d{4}$/i ) {
            push @errors, "activeStorms[$index] has unexpected storm id '$storm->{id}'";
        }

        for my $field (qw/latitudeNumeric longitudeNumeric movementDir movementSpeed/) {
            next if !exists $storm->{$field} || !defined $storm->{$field};
            push @errors, "activeStorms[$index].$field must be numeric"
              if !looks_like_number( $storm->{$field} );
        }

        for my $field ( sort keys %$storm ) {
            next if $KNOWN_STORM_FIELDS{$field};
            push @warnings, "activeStorms[$index] contains unknown field '$field'; preserved without interpretation";
        }
    }

    return { errors => \@errors, warnings => \@warnings };
}

1;

__END__

=head1 NAME

Weather::NHC::TropicalCyclone::Validation - lightweight validation of NHC CurrentStorms.json data

=head1 DESCRIPTION

This module intentionally does not implement JSON Schema.  It checks the small
structural contract that Weather::NHC::TropicalCyclone depends on while allowing
NHC to add new fields without breaking callers.  Unknown fields are reported as
warnings and remain present in the decoded data.

The rules are based on NHC's published Tropical Cyclone Status JSON reference and
on observed C<CurrentStorms.json> data, including the StormSurgeLive storm archive.
Current observed data uses camelCase C<latitudeNumeric> and C<longitudeNumeric>,
includes Central Pacific C<CP1> through C<CP5> bin numbers, and may include the
C<peakSurgeKML> field.

=head1 METHODS

=head2 validate

    my $report = Weather::NHC::TropicalCyclone::Validation->validate($hashref);

Returns a hash reference containing C<errors> and C<warnings> array references.

=head2 classifications

Returns the supported NHC classification abbreviation map.

=head2 known_storm_fields

Returns the currently known top-level storm fields.

=cut
