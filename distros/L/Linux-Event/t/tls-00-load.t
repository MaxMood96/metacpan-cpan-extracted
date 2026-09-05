use v5.36;
use Test::More;

use Linux::Event ();
use_ok('Linux::Event::TLS');
is(Linux::Event::TLS->VERSION, Linux::Event->VERSION,
    'TLS version matches distribution');

done_testing;
