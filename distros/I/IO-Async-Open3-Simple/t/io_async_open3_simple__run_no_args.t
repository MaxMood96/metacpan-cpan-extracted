use Test2::V0 -no_srand => 1;
use 5.042;
use IO::Async::Open3::Simple;

my $ipc = IO::Async::Open3::Simple->new;
isa_ok $ipc, ['IO::Async::Open3::Simple'], 'isa IO::Async::Open3::Simple';

like( dies { $ipc->run }, qr/run method requires at least one argument/, 'run with no arguments dies', );

done_testing;
