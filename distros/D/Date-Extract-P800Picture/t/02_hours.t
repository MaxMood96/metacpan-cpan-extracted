# -*- cperl; cperl-indent-level: 4 -*-
## no critic (RequireExplicitPackage RequireEndWithOne)
use 5.014;
use strict;
use warnings;
use utf8;
use Readonly;

use Test::More;
our $VERSION = v1.1.7;

BEGIN {
## no critic (ProhibitCallsToUnexportedSubs)
    Readonly::Scalar my $BASE_TESTS => 24;
## use critic;
    Test::More::plan 'tests' => $BASE_TESTS;
}
my %hours = (
    '00000001.JPG' => [ '2000-01-01T00:00:00', '0:00' ],
    '00010001.JPG' => [ '2000-01-01T01:00:00', '1:00' ],
    '00020001.JPG' => [ '2000-01-01T02:00:00', '2:00' ],
    '00030001.JPG' => [ '2000-01-01T03:00:00', '3:00' ],
    '00040001.JPG' => [ '2000-01-01T04:00:00', '4:00' ],
    '00050001.JPG' => [ '2000-01-01T05:00:00', '5:00' ],
    '00060001.JPG' => [ '2000-01-01T06:00:00', '6:00' ],
    '00070001.JPG' => [ '2000-01-01T07:00:00', '7:00' ],
    '00080001.JPG' => [ '2000-01-01T08:00:00', '8:00' ],
    '00090001.JPG' => [ '2000-01-01T09:00:00', '9:00' ],
    '000A0001.JPG' => [ '2000-01-01T10:00:00', '10:00' ],
    '000B0001.JPG' => [ '2000-01-01T11:00:00', '11:00' ],
    '000C0001.JPG' => [ '2000-01-01T12:00:00', '12:00' ],
    '000D0001.JPG' => [ '2000-01-01T13:00:00', '13:00' ],
    '000E0001.JPG' => [ '2000-01-01T14:00:00', '14:00' ],
    '000F0001.JPG' => [ '2000-01-01T15:00:00', '15:00' ],
    '000G0001.JPG' => [ '2000-01-01T16:00:00', '16:00' ],
    '000H0001.JPG' => [ '2000-01-01T17:00:00', '17:00' ],
    '000I0001.JPG' => [ '2000-01-01T18:00:00', '18:00' ],
    '000J0001.JPG' => [ '2000-01-01T19:00:00', '19:00' ],
    '000K0001.JPG' => [ '2000-01-01T20:00:00', '20:00' ],
    '000L0001.JPG' => [ '2000-01-01T21:00:00', '21:00' ],
    '000M0001.JPG' => [ '2000-01-01T22:00:00', '22:00' ],
    '000N0001.JPG' => [ '2000-01-01T23:00:00', '23:00' ],
);

use Date::Extract::P800Picture;
my $parser = Date::Extract::P800Picture->new();
while ( my ( $filename, $expect ) = each %hours ) {
    Test::More::is(
        "@{[$parser->extract($filename)]}",
## no critic (ProhibitAccessOfPrivateData)
        $expect->[0], $expect->[1],
## use critic
    );
}
