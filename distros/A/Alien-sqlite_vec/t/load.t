use Test2::V0;
use Test::Alien;
use Alien::sqlite_vec;

alien_ok 'Alien::sqlite_vec';

my @libs = Alien::sqlite_vec->dynamic_libs;
ok scalar @libs, 'dynamic_libs returns at least one path';
like $libs[0], qr/vec/, 'library contains vec in name';

done_testing;
