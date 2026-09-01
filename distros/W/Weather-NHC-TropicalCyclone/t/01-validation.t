use strict;
use warnings;
use Test::More;
use Weather::NHC::TropicalCyclone::Validation ();

my $v = 'Weather::NHC::TropicalCyclone::Validation';

my $r = $v->validate({ activeStorms => [] });
is_deeply $r, { errors => [], warnings => [] }, 'empty activeStorms is valid';

$r = $v->validate([]);
like $r->{errors}->[0], qr/root must be an object/, 'root type checked';

$r = $v->validate({});
like $r->{errors}->[0], qr/activeStorms array/, 'activeStorms required';

$r = $v->validate({ activeStorms => [ q{not-an-object} ] });
like $r->{errors}->[0], qr/must be an object/, 'storm object checked';

my $base = {
    id => 'al012026', binNumber => 'AT1', name => 'One', classification => 'TS',
    latitudeNumeric => 10.2, longitudeNumeric => -45.5, movementDir => 270, movementSpeed => 10,
};

for my $field (qw/id binNumber name classification/) {
    my %bad = %$base;
    delete $bad{$field};
    $r = $v->validate({ activeStorms => [ \%bad ] });
    ok scalar grep( /missing required field '$field'/, @{ $r->{errors} } ), "missing $field detected";
}

$r = $v->validate({ activeStorms => [ { %$base, classification => 'XX' } ] });
ok scalar grep( /unknown classification/, @{ $r->{errors} } ), 'unknown classification rejected';

$r = $v->validate({ activeStorms => [ { %$base, binNumber => 'CP9' } ] });
ok scalar grep( /unexpected binNumber/, @{ $r->{errors} } ), 'bad bin rejected';

$r = $v->validate({ activeStorms => [ { %$base, id => 'wp012026' } ] });
ok scalar grep( /unexpected storm id/, @{ $r->{errors} } ), 'bad id rejected';

for my $field (qw/latitudeNumeric longitudeNumeric movementDir movementSpeed/) {
    $r = $v->validate({ activeStorms => [ { %$base, $field => 'not-a-number' } ] });
    ok scalar grep( /$field must be numeric/, @{ $r->{errors} } ), "$field numeric check";
}

$r = $v->validate({ activeStorms => [ { %$base, futureThing => 1 } ] });
is scalar @{ $r->{errors} }, 0, 'unknown field is not an error';
like $r->{warnings}->[0], qr/futureThing.*preserved/, 'unknown field warns and is preserved';

ok exists $v->classifications->{HU}, 'classification map available';
ok scalar grep( $_ eq 'peakSurgeKML', @{ $v->known_storm_fields } ), 'current peak surge field known';

done_testing;
