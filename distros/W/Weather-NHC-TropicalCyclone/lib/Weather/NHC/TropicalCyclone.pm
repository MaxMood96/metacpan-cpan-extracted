package Weather::NHC::TropicalCyclone;

use strict;
use warnings;
use JSON::PP qw/decode_json/;
use Util::H2O::More qw/h2o/;
use Weather::NHC::TropicalCyclone::HTTP ();
use Weather::NHC::TropicalCyclone::Storm ();
use Weather::NHC::TropicalCyclone::Validation ();

our $VERSION                     = q{0.36};
our $DEFAULT_URL                 = q{https://www.nhc.noaa.gov/CurrentStorms.json};
our $DEFAULT_RSS_ATLANTIC        = q{https://www.nhc.noaa.gov/index-at.xml};
our $DEFAULT_RSS_EAST_PACIFIC    = q{https://www.nhc.noaa.gov/index-ep.xml};
our $DEFAULT_RSS_CENTRAL_PACIFIC = q{https://www.nhc.noaa.gov/index-cp.xml};
our $DEFAULT_TIMEOUT             = 10;

sub new {
    my ( $class, %args ) = @_;

    my $http = Weather::NHC::TropicalCyclone::HTTP->new(
        ( exists $args{http} ? ( client => $args{http} ) : () ),
    );

    return bless {
        _obj                 => undef,
        _storms              => {},
        _http                => $http,
        _validation_warnings => [],
    }, $class;
}

sub fetch {
    my ( $self, @args ) = @_;
    my %opts = $self->_fetch_options(@args);

    my $url     = $opts{url} // $DEFAULT_URL;
    my $timeout = exists $opts{timeout} ? $opts{timeout} : $DEFAULT_TIMEOUT;

    my $response = $self->_get_with_timeout( $url, $timeout );
    my $content  = $response->{content};

    my $file = $opts{save_to} // $opts{file};
    _write_file( $file, $content ) if defined $file;

    return $self->load_json($content);
}

sub load_json {
    my ( $self, $json ) = @_;
    die qq{JSON input is required\n} if !defined $json;

    my $data = eval { decode_json($json) };
    die qq{JSON decode error: $@} if $@ || !defined $data;

    return $self->_load_data($data);
}

sub load_file {
    my ( $self, $file ) = @_;
    die qq{JSON file is required\n} if !defined $file;
    open my $fh, q{<}, $file or die qq{Can't open '$file': $!\n};
    local $/;
    my $json = <$fh>;
    close $fh or die qq{Can't close '$file': $!\n};
    return $self->load_json($json);
}

sub validate {
    my ( $self, $input ) = @_;
    my $data = $input;

    if ( !ref $input ) {
        $data = eval { decode_json($input) };
        return { errors => [ qq{JSON decode error: $@} ], warnings => [] } if $@ || !defined $data;
    }

    return Weather::NHC::TropicalCyclone::Validation->validate($data);
}

sub validation_warnings {
    my $self = shift;
    return [ @{ $self->{_validation_warnings} } ];
}

sub active_storms {
    my $self = shift;
    return [ map { $self->{_storms}->{$_} } sort keys %{ $self->{_storms} } ];
}

sub get_storm_by_id {
    my ( $self, $id ) = @_;
    return undef if !defined $id;
    return $self->{_storms}->{$id};
}

sub get_storm_ids {
    my $self = shift;
    return [ sort keys %{ $self->{_storms} } ];
}

sub fetch_rss_atlantic {
    my ( $self, $local_file ) = @_;
    return $self->_fetch_rss( $DEFAULT_RSS_ATLANTIC, $local_file );
}

sub fetch_rss_east_pacific {
    my ( $self, $local_file ) = @_;
    return $self->_fetch_rss( $DEFAULT_RSS_EAST_PACIFIC, $local_file );
}

sub fetch_rss_central_pacific {
    my ( $self, $local_file ) = @_;
    return $self->_fetch_rss( $DEFAULT_RSS_CENTRAL_PACIFIC, $local_file );
}

sub _load_data {
    my ( $self, $data ) = @_;
    my $report = Weather::NHC::TropicalCyclone::Validation->validate($data);

    if ( @{ $report->{errors} } ) {
        die q{NHC CurrentStorms.json validation failed: }
          . join( q{; }, @{ $report->{errors} } ) . qq{\n};
    }

    $self->{_validation_warnings} = [ @{ $report->{warnings} } ];

    # Keep the decoded structure recognizable as HASH/ARRAY data while adding
    # convenient accessors to hashes. Storm objects are created separately.
    $self->{_obj} = h2o -recurse, $data;
    $self->_update_storm_cache;
    return $self;
}

sub _update_storm_cache {
    my $self = shift;
    $self->{_storms} = {};

    for my $storm ( @{ $self->{_obj}->{activeStorms} } ) {
        my $object = Weather::NHC::TropicalCyclone::Storm->new(
            $storm,
            http => $self->{_http},
        );
        $self->{_storms}->{ $object->id } = $object;
    }

    return $self->{_storms};
}

sub _fetch_rss {
    my ( $self, $rss_url, $local_file ) = @_;
    my $response = $self->{_http}->get($rss_url);
    my $content  = $response->{content};
    _write_file( $local_file, $content ) if defined $local_file;
    return $content;
}

sub _get_with_timeout {
    my ( $self, $url, $timeout ) = @_;

    return $self->{_http}->get($url) if !$timeout;

    local $SIG{ALRM} = sub { die qq{Request has timed out.\n} };
    my $response;
    my $ok = eval {
        alarm($timeout);
        $response = $self->{_http}->get($url);
        alarm(0);
        1;
    };
    my $error = $@;
    alarm(0);
    die $error if !$ok;
    return $response;
}

sub _fetch_options {
    my ( $self, @args ) = @_;
    return () if !@args;

    if ( @args % 2 == 0 && defined $args[0] && $args[0] =~ /^(?:timeout|save_to|file|url)$/ ) {
        return @args;
    }

    # Backward-compatible positional form: fetch($timeout, $file)
    return (
        timeout => $args[0],
        ( @args > 1 ? ( save_to => $args[1] ) : () ),
    );
}

sub _write_file {
    my ( $file, $content ) = @_;
    open my $fh, q{>}, $file or die qq{Can't open '$file': $!\n};
    print {$fh} $content;
    close $fh or die qq{Can't close '$file': $!\n};
    return $file;
}

1;

__END__

=head1 NAME

Weather::NHC::TropicalCyclone - client and object interface for NHC tropical cyclone status data

=head1 SYNOPSIS

Fetch the current NHC status feed:

    use Weather::NHC::TropicalCyclone ();

    my $nhc = Weather::NHC::TropicalCyclone->new;
    $nhc->fetch;

    for my $storm ( @{ $nhc->active_storms } ) {
        printf "%s (%s) - %s\n",
          $storm->name,
          $storm->id,
          $storm->kind;
    }

Load an archived C<CurrentStorms.json> without making a network request:

    my $nhc = Weather::NHC::TropicalCyclone->new;
    $nhc->load_file('CurrentStorms.json');

Or load JSON already held in memory:

    $nhc->load_json($json_text);

=head1 DESCRIPTION

C<Weather::NHC::TropicalCyclone> reads the National Hurricane Center's
C<CurrentStorms.json> status file and exposes each active storm as a
L<Weather::NHC::TropicalCyclone::Storm> object.

Version 0.36 separates network access, lightweight feed validation, and storm
resource dispatch so those concerns can be tested independently.  Existing
C<fetch>, storm lookup, RSS, and storm C<fetch_*> methods remain available.

The parser is deliberately tolerant of additive changes to the NHC feed. Fields
that this distribution does not yet know about are preserved and reported via
L</validation_warnings>; they do not cause parsing to fail.

=head1 LOADING NHC DATA

=head2 fetch

    $nhc->fetch;

Fetches C<$DEFAULT_URL>.  The historical positional arguments remain supported:

    $nhc->fetch(120, '/tmp/CurrentStorms.json');

The preferred form uses named options:

    $nhc->fetch(
        timeout => 120,
        save_to => '/tmp/CurrentStorms.json',
    );

Supported options are:

=over 4

=item * C<timeout>

Request timeout in seconds. The default is C<$DEFAULT_TIMEOUT>. A false value
disables the alarm-based timeout retained for backward compatibility.

=item * C<save_to>

Save the exact fetched JSON text to this path before parsing it. C<file> is an
alias.

=item * C<url>

Override C<$DEFAULT_URL>, useful for mirrors and replay services.

=back

=head2 load_json

    $nhc->load_json($json_text);

Parses and validates NHC JSON already in memory.  This is useful for archived
storms, replay systems, and deterministic tests.

=head2 load_file

    $nhc->load_file('/archive/CurrentStorms.json');

Reads and processes a saved NHC status file.

=head2 validate

    my $report = $nhc->validate($json_or_hashref);

Returns a hash reference with C<errors> and C<warnings> array references.  The
validation is intentionally lightweight rather than a full JSON-Schema
implementation.

=head2 validation_warnings

Returns warnings generated by the most recent successful load.  Currently this
is primarily used to report previously unknown NHC storm fields that were
preserved without interpretation.

=head1 ACTIVE STORMS

=head2 active_storms

Returns an array reference of L<Weather::NHC::TropicalCyclone::Storm> objects.
The array is empty when NHC reports no active storms.

=head2 get_storm_ids

Returns an array reference containing the active ATCF/NHC storm identifiers,
for example C<al042026> or C<cp012026>.

=head2 get_storm_by_id

    my $storm = $nhc->get_storm_by_id('al042026');

Returns the cached storm object or C<undef> when that id is not active.

=head1 RSS FEEDS

=head2 fetch_rss_atlantic

Fetches the Atlantic basin RSS feed.

=head2 fetch_rss_east_pacific

Fetches the Eastern Pacific basin RSS feed.

=head2 fetch_rss_central_pacific

Fetches the Central Pacific basin RSS feed.

All three RSS methods fetch the corresponding raw NHC RSS XML.  Each accepts an optional filename to
which the response will also be written.

=head1 TESTING AND CUSTOM HTTP CLIENTS

A C<HTTP::Tiny>-compatible object can be injected into the constructor:

    my $nhc = Weather::NHC::TropicalCyclone->new(
        http => $mock_http,
    );

The object must provide C<get> and C<mirror>. This is primarily useful for tests,
replay systems, and applications that need custom transport behavior.

=head1 NHC DATA COMPATIBILITY

NHC documents C<CurrentStorms.json> as a root object containing one
C<activeStorms> array, with unavailable products represented by JSON C<null>.
The 0.36 parser also reflects observed NHC data through the 2026 season,
including Central Pacific C<CP1>-C<CP5> bin numbers, camelCase
C<latitudeNumeric>/C<longitudeNumeric>, and the C<peakSurgeKML> field.

The distribution contains representative offline fixtures. Maintainers can also
run C<xt/archive-compatibility.t> against a checkout of the
C<StormSurgeLive/storm-archive> repository to exercise the parser against the
full historical corpus.

=head1 SEE ALSO

L<Weather::NHC::TropicalCyclone::Storm>,
L<Weather::NHC::TropicalCyclone::ForecastAdvisory>,
L<Weather::NHC::TropicalCyclone::StormTable>,
L<https://www.nhc.noaa.gov/productexamples/>,
L<https://www.nhc.noaa.gov/gis/>.

=head1 LICENSE

This module is distributed under the same terms as Perl itself.

=cut
