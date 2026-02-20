use Test::More;   # see done_testing()

require_ok( 'Sumi::CSS' );

my $c = Sumi::CSS->new;

isa_ok($c, "Sumi::CSS");

done_testing()