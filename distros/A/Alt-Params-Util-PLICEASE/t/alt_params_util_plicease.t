use Test2::V0 -no_srand => 1;
use Params::Util qw( _POSINT );

ok( _POSINT(1) );
ok( !_POSINT(-1) );

done_testing;
