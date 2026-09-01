package Weather::NHC::TropicalCyclone::Storm;

use strict;
use warnings;
use Scalar::Util qw/reftype/;
use Util::H2O::More qw/baptise/;
use Weather::NHC::TropicalCyclone::HTTP ();
use Weather::NHC::TropicalCyclone::Resource ();
use Weather::NHC::TropicalCyclone::Validation ();

our $DEFAULT_GRAPHICS_ROOT = q{https://www.nhc.noaa.gov/storm_graphics};
our $DEFAULT_BTK_ROOT      = q{https://ftp.nhc.noaa.gov/atcf/btk};
our $CLASSIFICATIONS       = Weather::NHC::TropicalCyclone::Validation->classifications;

our @COMPAT_FIELDS = qw/
  latitudelongitude latitude_numberic kmzFile34kt kmzFile50kt kmzFile64kt
/;

our @FIELDS = qw/
  id binNumber name classification intensity pressure latitude longitude
  latitudeNumeric longitudeNumeric movementDir movementSpeed lastUpdate
  publicAdvisory forecastAdvisory windSpeedProbabilities forecastDiscussion
  forecastGraphics forecastTrack windWatchesWarnings trackCone initialWindExtent
  forecastWindRadiiGIS bestTrackGIS earliestArrivalTimeTSWindsGIS
  mostLikelyTimeTSWindsGIS windSpeedProbabilitiesGIS stormSurgeWatchWarningGIS
  potentialStormSurgeFloodingGIS peakSurgeKML
/;

sub new {
    my ( $class, $data, %args ) = @_;
    die qq{Storm constructor requires a hash reference\n} if reftype($data) ne q{HASH};

    for my $field (qw/id binNumber name classification/) {
        die qq{Field validation errors found creating package instance for: $field\n}
          if !exists $data->{$field} || !defined $data->{$field} || $data->{$field} eq q{};
    }
    if ( !exists $CLASSIFICATIONS->{ $data->{classification} } ) {
        die qq{Field validation errors found creating package instance for: classification\n};
    }

    my %copy = %$data;
    my $self = baptise -recurse, \%copy, $class, @FIELDS, @COMPAT_FIELDS, q{_http};
    $self->{_http} = $args{http} || Weather::NHC::TropicalCyclone::HTTP->new;
    return $self;
}

sub _get_validation_rules {
    return {
        required        => [qw/id binNumber name classification/],
        classifications => { %{$CLASSIFICATIONS} },
    };
}

sub _fetch_text_types {
    return { text => Weather::NHC::TropicalCyclone::Resource->text_resources };
}

sub _fetch_data_types {
    return Weather::NHC::TropicalCyclone::Resource->file_types;
}

sub kind {
    my $self = shift;
    die qq{'classification' field not set\n} if !$self->classification;
    die qq{Unknown storm classification\n} if !exists $CLASSIFICATIONS->{ $self->classification };
    return $CLASSIFICATIONS->{ $self->classification };
}

sub basin {
    my $self = shift;
    my $bin = $self->binNumber;
    die qq{'binNumber' field not set\n} if !defined $bin || $bin eq q{};
    return q{atlantic}        if $bin =~ /^AT[1-5]$/i;
    return q{pacific}         if $bin =~ /^EP[1-5]$/i;    # historical return value
    return q{central_pacific} if $bin =~ /^CP[1-5]$/i;
    return undef;
}

sub fetch_forecastGraphics_urls {
    my $self = shift;
    my $graphics = $self->{forecastGraphics};
    return [] if !defined $graphics || reftype($graphics) ne q{HASH} || !$graphics->{url};

    my $response = $self->{_http}->get( $graphics->{url} );
    my $html = $response->{content} // q{};
    my ($prefix) = $html =~ m{storm_graphics/(.+?)/refresh};
    return [] if !$prefix;

    my $base = "$DEFAULT_GRAPHICS_ROOT/$prefix";
    $response = $self->{_http}->get($base);
    $html = $response->{content} // q{};

    my $id = uc $self->id;
    my @images = ( $html =~ m{href=["']($id[^"']+\.png)["']}gi );
    return [ map { "$base/$_" } @images ];
}

sub _get_text {
    my ( $self, $resource, $local_file ) = @_;
    die qq{Resource '$resource' is not a supported text resource\n}
      if Weather::NHC::TropicalCyclone::Resource->kind( $resource, undef ) ne q{text};

    my $object = $self->{$resource};
    return undef if !defined $object || reftype($object) ne q{HASH} || !$object->{url};

    my $response = $self->{_http}->get( $object->{url} );
    my $text = _extract_pre_text( $response->{content} // q{}, $object->{url} );

    _write_file( $local_file, $text ) if defined $local_file;
    return ( $text, $object->{advNum}, $local_file );
}

sub fetch_publicAdvisory {
    my ( $self, $local_file ) = @_;
    return $self->_get_text( q{publicAdvisory}, $local_file );
}

sub fetch_forecastAdvisory {
    my ( $self, $local_file ) = @_;
    return $self->_get_text( q{forecastAdvisory}, $local_file );
}

sub fetch_forecastAdvisory_as_atcf {
    my ( $self, $local_file ) = @_;
    my ( $text, $adv_num ) = $self->_get_text(q{forecastAdvisory});
    require Weather::NHC::TropicalCyclone::ForecastAdvisory;

    my $forecast = Weather::NHC::TropicalCyclone::ForecastAdvisory->new(
        input_text  => $text,
        output_file => $local_file,
    );
    $forecast->extract_atcf;
    $forecast->save_atcf if defined $local_file;
    return ( $forecast->as_atcf, $adv_num, $local_file );
}

sub fetch_forecastDiscussion {
    my ( $self, $local_file ) = @_;
    return $self->_get_text( q{forecastDiscussion}, $local_file );
}

sub fetch_windspeedProbabilities {
    my ( $self, $local_file ) = @_;
    return $self->_get_text( q{windSpeedProbabilities}, $local_file );
}

sub fetch_forecastTrack                  { my $s = shift; return $s->_get_file( q{forecastTrack},                  @_ ) }
sub fetch_windWatchesWarnings            { my $s = shift; return $s->_get_file( q{windWatchesWarnings},            @_ ) }
sub fetch_trackCone                      { my $s = shift; return $s->_get_file( q{trackCone},                      @_ ) }
sub fetch_initialWindExtent              { my $s = shift; return $s->_get_file( q{initialWindExtent},              @_ ) }
sub fetch_forecastWindRadiiGIS           { my $s = shift; return $s->_get_file( q{forecastWindRadiiGIS},           @_ ) }
sub fetch_bestTrackGIS                   { my $s = shift; return $s->_get_file( q{bestTrackGIS},                   @_ ) }
sub fetch_earliestArrivalTimeTSWindsGIS  { my $s = shift; return $s->_get_file( q{earliestArrivalTimeTSWindsGIS},  @_ ) }
sub fetch_mostLikelyTimeTSWindsGIS       { my $s = shift; return $s->_get_file( q{mostLikelyTimeTSWindsGIS},       @_ ) }
sub fetch_windSpeedProbabilitiesGIS      { my $s = shift; return $s->_get_file( q{windSpeedProbabilitiesGIS},      @_ ) }
sub fetch_stormSurgeWatchWarningGIS      { my $s = shift; return $s->_get_file( q{stormSurgeWatchWarningGIS},      @_ ) }
sub fetch_potentialStormSurgeFloodingGIS { my $s = shift; return $s->_get_file( q{potentialStormSurgeFloodingGIS}, @_ ) }
sub fetch_peakSurgeKML                   { my $s = shift; return $s->_get_file( q{peakSurgeKML},                   @_ ) }

sub _get_file {
    my ( $self, $resource, $type, $local_file ) = @_;

    if ( !Weather::NHC::TropicalCyclone::Resource->is_valid_file_type( $resource, $type ) ) {
        die qq{'$type' is not a valid type provided by '$resource'.\n};
    }

    my $object = $self->{$resource};
    return undef if !defined $object || reftype($object) ne q{HASH} || !$object->{$type};

    my $url = $object->{$type};
    $local_file //= _filename_from_url($url);
    $self->{_http}->mirror( $url, $local_file );

    my $adv_num = exists $object->{advNum} && defined $object->{advNum}
      ? $object->{advNum}
      : q{N/A};
    return ( $local_file, $adv_num );
}

sub fetch_best_track {
    my ( $self, $local_file ) = @_;
    my $btk_file = sprintf q{b%s.dat}, $self->id;
    my $url = "$DEFAULT_BTK_ROOT/$btk_file";
    $local_file //= $btk_file;
    $self->{_http}->mirror( $url, $local_file );
    return $local_file;
}

sub _extract_pre_text {
    my ( $html, $url ) = @_;
    my ($text) = $html =~ m{<pre\b[^>]*>(.*?)</pre>}is;
    die qq{No <pre> advisory text found at $url\n} if !defined $text;

    # NHC text products are intentionally plain inside <pre>. Decode the small
    # set of entities that can appear without pulling in a full HTML parser.
    $text =~ s/<[^>]+>//g;
    $text =~ s/&nbsp;/ /gi;
    $text =~ s/&lt;/</gi;
    $text =~ s/&gt;/>/gi;
    $text =~ s/&quot;/"/gi;
    $text =~ s/&#39;/'/gi;
    $text =~ s/&amp;/&/gi;
    $text =~ s/&#(\d+);/chr($1)/ge;
    return $text;
}

sub _filename_from_url {
    my ($url) = @_;
    my ($file) = $url =~ m{/([^/?]+)(?:\?.*)?$};
    die qq{Unable to determine local filename from URL '$url'\n} if !defined $file || $file eq q{};
    return $file;
}

sub _write_file {
    my ( $file, $content ) = @_;
    open my $fh, q{>}, $file or die qq{Failed to open '$file' for writing: $!\n};
    print {$fh} $content;
    close $fh or die qq{Failed to close '$file': $!\n};
    return $file;
}

1;

__END__

=head1 NAME

Weather::NHC::TropicalCyclone::Storm - one active storm from NHC CurrentStorms.json

=head1 SYNOPSIS

    my $nhc = Weather::NHC::TropicalCyclone->new;
    $nhc->fetch;

    for my $storm ( @{ $nhc->active_storms } ) {
        printf "%s %s: %s\n", $storm->id, $storm->name, $storm->kind;

        my ( $text, $adv_num ) = $storm->fetch_forecastAdvisory;
        my ( $file, $gis_adv ) = $storm->fetch_trackCone('kmzFile');
    }

=head1 DESCRIPTION

A Storm object wraps one object from NHC's C<activeStorms> array.  Scalar storm
properties are available as accessors and nested product objects remain ordinary
hash-based H2O objects, so callers can use either accessor or hash syntax.

Version 0.36 centralizes the product/type matrix in
L<Weather::NHC::TropicalCyclone::Resource>.  The historical convenience methods
below are retained as thin wrappers around shared text and file download paths.
This also leaves a clean boundary for a future bulk-download API.

=head1 STORM INFORMATION

The fields advertised by current NHC data include:

    id
    binNumber
    name
    classification
    intensity
    pressure
    latitude
    longitude
    latitudeNumeric
    longitudeNumeric
    movementDir
    movementSpeed
    lastUpdate

NHC may add fields. Unknown fields are preserved by the top-level client.

=head2 Historical compatibility accessors

The 0.35 constructor generated several top-level accessors that were not actual
current NHC field names: C<latitudelongitude>, C<latitude_numberic>,
C<kmzFile34kt>, C<kmzFile50kt>, and C<kmzFile64kt>. Version 0.36 retains those
accessors for source compatibility, but new code should use C<latitudeNumeric>
and the corresponding fields under C<windSpeedProbabilitiesGIS> instead.

=head2 kind

Returns a human-readable description of the NHC C<classification> abbreviation.

=head2 basin

Returns C<atlantic> for C<AT1>-C<AT5>, C<pacific> for C<EP1>-C<EP5> (the
historical return value), and C<central_pacific> for the currently observed
C<CP1>-C<CP5> bins.

=head1 TEXT PRODUCTS

These methods fetch the NHC HTML product and return the text inside its C<pre>
element. Each accepts an optional local filename and returns text, advisory
number, and that filename.

=head2 fetch_publicAdvisory

Fetches the current public advisory text.

=head2 fetch_forecastAdvisory

Fetches the current forecast/advisory text.

=head2 fetch_forecastDiscussion

Fetches the current forecast discussion text.

=head2 fetch_windspeedProbabilities

Fetches the current wind-speed probability text product.

=head1 GIS AND DOWNLOADABLE PRODUCTS

The following methods accept a product representation such as C<zipFile>,
C<kmzFile>, C<kmzFile34kt>, or C<kmlFile>, plus an optional local filename.
They return the saved filename and advisory number. Products without an advisory
number return C<N/A> for that value. A currently unavailable NHC product returns
C<undef>.

=head2 fetch_forecastTrack

Downloads the requested forecast-track representation.

=head2 fetch_windWatchesWarnings

Downloads the requested wind-watch/warning representation when NHC provides it.

=head2 fetch_trackCone

Downloads the requested forecast-cone representation.

=head2 fetch_initialWindExtent

Downloads the requested initial wind-extent representation.

=head2 fetch_forecastWindRadiiGIS

Downloads the requested forecast wind-radii GIS representation.

=head2 fetch_bestTrackGIS

Downloads the requested best-track GIS representation.

=head2 fetch_earliestArrivalTimeTSWindsGIS

Downloads the requested earliest reasonable tropical-storm-wind arrival-time representation.

=head2 fetch_mostLikelyTimeTSWindsGIS

Downloads the requested most-likely tropical-storm-wind arrival-time representation.

=head2 fetch_windSpeedProbabilitiesGIS

Downloads a requested GIS wind-speed-probability representation.

=head2 fetch_stormSurgeWatchWarningGIS

Downloads the storm-surge watch/warning KML product when available.

=head2 fetch_potentialStormSurgeFloodingGIS

Downloads a requested potential storm-surge flooding GIS product.

=head2 fetch_peakSurgeKML

Downloads the peak-surge KML product when available.

C<peakSurgeKML> is present in current NHC status data and is frequently C<null>
when the product does not apply.

=head1 OTHER PRODUCTS

=head2 fetch_forecastGraphics_urls

Returns an array reference containing the currently advertised PNG graphic URLs
for the storm. Returns an empty array reference if no graphics directory can be
determined.

=head2 fetch_best_track

Downloads the preliminary best-track C<b<storm-id>.dat> file from NHC's ATCF
best-track directory. The optional argument overrides the local filename.

=head2 fetch_forecastAdvisory_as_atcf

Fetches the current forecast/advisory, converts it to ATCF forecast records using
L<Weather::NHC::TropicalCyclone::ForecastAdvisory>, and returns the ATCF array
reference, advisory number, and optional saved filename.

=head1 RESOURCE CATALOG

The product/type relationships used by these methods live in
L<Weather::NHC::TropicalCyclone::Resource>. Keeping that information declarative
makes it possible for a later release to provide filtered bulk downloads by
product family, category, representation, or file extension without duplicating
the download implementation.

=head1 DEFAULT URLS

C<$DEFAULT_GRAPHICS_ROOT> is the NHC storm graphics root.
C<$DEFAULT_BTK_ROOT> is the HTTPS ATCF preliminary best-track root.

=head1 LICENSE

This module is distributed under the same terms as Perl itself.

=cut
