package DateTime::Format::EraLegis;
$DateTime::Format::EraLegis::VERSION = '0.013';
# ABSTRACT: DateTime formatter for Era Legis (https://eralegis.info)

use strict;
use warnings;
use Function::Parameters qw(fun method);
use Moo;
use strictures 2;
use namespace::clean;
use Astro::Sunrise qw(sunrise);

has 'ephem' => (
    is => 'ro',
#    isa => 'DateTime::Format::EraLegis::Ephem',
    lazy => 1,
    builder => 1,
    );

has 'style' => (
    is => 'ro',
#    isa => 'DateTime::Format::EraLegis::Style',
    lazy => 1,
    builder => 1,
    );

method _build_ephem() {
    return DateTime::Format::EraLegis::Ephem::DBI->new;
}

method _build_style() {
    return DateTime::Format::EraLegis::Style->new;
}

method format_datetime($dt, :$format = 'plain', :$geo = undef) {
    $dt = $dt->clone;

    ### Day of week should match existing time zone
    my $dow = $dt->day_of_week;

    ### Adjust $dow based on sunrise time
    my $sunrise = '06:00:00';     # default to 6am sunrise
    if ($geo) {
        ($sunrise, undef) = sunrise(
            { year => $dt->year
                  , month => $dt->month
                  , day => $dt->day
                  , lat => $geo->[0]
                  , lon => $geo->[1]
                  , tz => ($dt->offset / 3600)
                  , precise => 1
              }
        );
        $sunrise .= ':00';
    }
    if ($dt->hms lt $sunrise) {
        $dow = $dow == 1 ? 7 : $dow - 1;
    }

    my %tdate = (
        evdate_local => $dt->ymd . ' ' . $dt->hms,
        dow => $dow,
        sunrise => $sunrise,
        is_dst => $dt->is_dst,
        tz_offset => $dt->offset,
        );

    ### But pull ephemeris data based on UTC
    $dt->set_time_zone('UTC');
    $tdate{evdate_utc} = $dt->ymd . ' ' . $dt->hms;

    for ( qw(sol luna) ) {
        my $deg = $self->ephem->lookup( $_, $dt );
        $tdate{$_}{sign} = int($deg / 30);
        $tdate{$_}{deg} = int($deg % 30);
    }

    my $years = $dt->year -
        (($dt->month <= 3 && $tdate{sol}{sign} > 0) ? 1905 : 1904);
    $tdate{year} = [ int( $years/22 ), int( $years%22 ) ];

    $tdate{plain} = $self->style->express( \%tdate );

    return ($format eq 'raw') ? \%tdate : $tdate{plain};
}

######################################################
package DateTime::Format::EraLegis::Ephem;
use Moo::Role;
use strictures 2;

requires 'lookup';

######################################################
package DateTime::Format::EraLegis::Ephem::DBI;
$DateTime::Format::EraLegis::Ephem::DBI::VERSION = '0.013';
use 5.010;
use Function::Parameters qw(fun method);
use Moo;
use strictures 2;
use namespace::clean;
use Carp;
use DBI;

with 'DateTime::Format::EraLegis::Ephem';

has 'ephem_db' => (
    is => 'ro',
#    isa => 'Str',
    builder => 1,
    lazy => 1,
    );

has 'dbh' => (
    is => 'ro',
#    isa => 'DBI::db',
    builder => 1,
    lazy => 1,
    );

method _build_ephem_db() {
    return $ENV{ERALEGIS_EPHEMDB}
        // croak 'No ephemeris database defined';
}

method _build_dbh() {
    return DBI->connect( 'dbi:SQLite:dbname='.$self->ephem_db );
}

method lookup($body, $dt) {
    my $time = $dt->ymd . ' ' . $dt->hms;
    croak 'Date is before era legis' if $time lt '1904-03-20';
    my $rows = $self->dbh->selectcol_arrayref(
        q{SELECT degree FROM ephem
          WHERE body = ? AND time < ?
          ORDER BY time DESC LIMIT 1},
        undef, $body, $time );
    croak "Cannot find date entry for $time." unless $rows;

    return $rows->[0];
}

######################################################

package DateTime::Format::EraLegis::Style;

use 5.010;
use Function::Parameters qw(fun method);
use Moo;
use strictures 2;
use namespace::clean;
use utf8;
use Roman::Unicode qw(to_roman);

has 'lang' => (
    is => 'ro',
#    isa => 'Str',
    default => 'latin',
    required => 1,
    );

has 'dow' => (
    is => 'ro',
#    isa => 'ArrayRef',
    builder => 1,
    lazy => 1,
    );

has 'signs' => (
    is => 'ro',
#    isa => 'ArrayRef',
    builder => 1,
    lazy => 1,
    );

has 'years' => (
    is => 'ro',
#    isa => 'ArrayRef',
    builder => 1,
    lazy => 1,
    );

has 'show_terse' => (
    is => 'ro',
#    isa => 'Bool',
    default => 0,
    );

has [ qw( show_deg show_dow show_year roman_year ) ] => (
    is => 'ro',
#    isa => 'Bool',
    default => 1,
    );

has 'template' => (
    is => 'ro',
#    isa => 'Str',
    builder => 1,
    lazy => 1,
    );

has 'vs15' => (
    is => 'ro',
#    isa => 'Bool',
    default => 1,
    );

method _build_dow() {
    return
        ($self->lang eq 'symbol')
        ? [qw( ☉ ☽ ♂ ☿ ♃ ♀ ♄ ☉ )]
        : ($self->lang eq 'english')
        ? [qw(Sunday Monday Tuesday Wednesday Thursday Friday Saturday Sunday)]
        : [qw(Solis Lunae Martis Mercurii Iovis Veneris Saturni Solis)];
}

method _build_signs() {
    return [qw( ♈ ♉ ♊ ♋ ♌ ♍ ♎ ♏ ♐ ♑ ♒ ♓ )]
        if $self->lang eq 'symbol';

    return [qw(Aries Taurus Gemini Cancer Leo Virgo Libra Scorpio Sagittarius Capricorn Aquarius Pisces)]
        if $self->lang eq 'english';

    return [qw(Aries Taurus Gemini Cancer Leo Virgo Libra Scorpio Sagittarius Capricorn Aquarius Pisces)]
        if $self->lang eq 'poor-latin';

    return [qw(Arietis Tauri Geminorum Cancri Leonis Virginis Librae Scorpii Sagittarii Capricorni Aquarii Piscis)]
        if $self->lang eq 'latin' && $self->show_deg;

    return [qw(Ariete Tauro Geminis Cancro Leone Virginie Libra Scorpio Sagittario Capricorno Aquario Pisci)];
}

method _build_years() {
    return
        ($self->roman_year)
        ? [ 0, map { to_roman($_) } 1..21 ]
        : [ 0..21 ];
}

method _build_template() {
    my $template = '';
    my $vs = $self->vs15 ? '︎' : '';
    if ($self->show_deg) {
        $template = "☉$vs in {sdeg}° {ssign} : ☽$vs in {ldeg}° {lsign}";
    }
    else {
        $template = "☉$vs in {ssign} : ☽$vs in {lsign}";
    }
    if ($self->show_terse) {
        $template =~ s/ in / /g;
    }
    if ($self->show_dow) {
        $template .= ' : ';
        $template .= ($self->lang eq 'latin')
            ? 'dies '
            : '';
        $template .= '{dow}';
    }
    if ($self->show_year) {
        $template .= ' : ';
        $template .= ($self->lang eq 'symbol')
            ? '{year1}{year2}'
            : ($self->lang eq 'english')
            ? 'Year {year1}.{year2} of the New Aeon'
            : 'Anno {year1}{year2} æræ legis';
    }

    return $template;
}

method express( $tdate ) {
    my $datestr = $self->template;

    my $vs = $self->lang eq 'symbol' && $self->vs15 ? '︎' : '';

    $datestr =~ s/{sdeg}/$tdate->{sol}{deg}/ge;
    $datestr =~ s/{ssign}/$self->signs->[$tdate->{sol}{sign}].$vs/ge;
    $datestr =~ s/{ldeg}/$tdate->{luna}{deg}/ge;
    $datestr =~ s/{lsign}/$self->signs->[$tdate->{luna}{sign}].$vs/ge;
    $datestr =~ s/{dow}/$self->dow->[$tdate->{dow}].$vs/ge;
    $datestr =~ s/{year1}/$self->years->[$tdate->{year}[0]]/ge;
    $datestr =~ s/{year2}/lc($self->years->[$tdate->{year}[1]])/ge;

    return $datestr;
}

1;

__END__

=head1 NAME

 DateTime::Format::EraLegis - DateTime converter for Era Legis
 DateTime::Format::EraLegis::Ephem - planetary ephemeris role
 DateTime::Format::EraLegis::Ephem::DBI - default ephemeris getter
 DateTime::Format::EraLegis::Style - customize output styles

=head1 SYNOPSIS

 use DateTime::Format::EraLegis;

 my $ephem = DateTime::Format::EraLegis::Ephem::DBI->new(
     ephem_db => 'db.sqlite3');
 my $style = DateTime::Format::EraLegis::Style->new(
     show_terse => 1, lang => 'symbol');
 my $dtf = DateTime::Format::EraLegis->new(
     ephem => $ephem, style => $style);

 my $dt->set_formatter($dtf);

=head1 DESCRIPTION

These three modules combined enable DateTime objects to emit date strings
formatted according to the Thelemic calendar. The ephemeris provides access
to the planetary location of the Sun and Moon keyed by UTC timestamp. The
style dictates the specific expression of the of datetime value using a
template into which one can place tokens which can be converted into the
sign/degree coordinates for the given date. A default style exists and is
permutable by boolean attributes.

All three classes are built with Moose and behave accordingly. Method
arguments are typechecked and will die on failure. Defaults exist for
all attributes. All attributes are read-only and must be assigned at
the time of instantiation.

=head1 ATTRIBUTES AND METHODS

=over

=item *

DateTime::Format::EraLegis

=over

=item *

ephem: DT::F::EL::Ephem object. Creates a new DBI one by default.

=item *

style: DT::F::EL::Style object. Creates a new one by default.

=item *

format_datetime(DateTime $dt, Str $format): Standard interface for a
DateTime::Format package. $format is one of 'plain' or 'raw'.
Defaults to 'plain'.

=back

=item *

DateTime::Format::EraLegis::Ephem (Role)

=over

=item *

lookup(Str $body, DateTime $dt): Required by any role consumer. $body
is one of "sol" or "luna". $dt is the date in question (in UTC!).
Returns the number of degrees away from 0 degrees Aries. Divide by
thirty to get the sign. Modulo by thirty to get the degrees of that
sign.

=back

=item *

DateTime::Format::EraLegis::Ephem::DBI

=over

=item *

Consumes DT::F::EL::Ephem role.

=item *

ephem_db: Filename of the sqlite3 ephemeris database. Defaults to the value
of $ENV{ERALEGIS_EPHEMDB}.

=item *

dbh: DBI handle for ephemeris database. Defaults to creating a new one pointing
to the ephem_db database.

=back

=item *

DateTime::Format::EraLegis::Style

=over

=item *

template: Assign a custom template value. Variables (enclosed in '{}')
include 'ssign' and 'sdeg' for Sol sign and degree, 'lsign' and 'ldeg'
for Luna sign and degree, 'dow' for day of the week, and 'year1' and
'year2' for the two docosades. Example:

 "Sol in {sdeg} degrees {ssign}, anno {year1}{year2} era legis"

Interpolated values get assigned based on the setting of 'lang'.

=item *

lang: Set the output language, one of latin, english, symbol, poor-latin.
Defaults to 'latin'.

=item *

show_terse, show_deg, show_dow, show_year, roman_year: Flags to direct
the style to alter the default template.

=back

=back

=head1 DATABASE SCHEMA

The schema for the DBI ephemeris table is very simple and the querying
SQL very generic. Most DBI backends should work without issue, though
SQLite3 is the only one tested. The schema is:

 CREATE TABLE ephem (
   body TEXT,               -- one of 'sol' or 'luna'
   time DATETIME,           -- UTC timestamp of shift into degree
   degree INTEGER NOT NULL, -- degrees from 0 degrees Aries
   PRIMARY KEY (body, time)
 );

=head1 BUGS

Please report bugs as issues at:
https://gitlab.com/clayfouts/datetime-format-eralegis

=head1 AUTHOR

Clay Fouts <cfouts@khephera.net>

=head1 COPYRIGHT & LICENSE

Copyright (c) 2012 Clay Fouts

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
