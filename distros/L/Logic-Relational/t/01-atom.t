use v5.38;
use lib ('../lib', 'lib');
use Test2::V0;
use Logic::Relational::Atom;

my $atom = Logic::Relational::Atom->new('gold');
is( $atom->value,         'gold', 'Atom value is correct' );
is( $atom->as_string,     'gold', 'Atom string representation is correct' );
is( $atom->freshen( {} ), $atom,  'Atom freshen returns itself' );

done_testing;
