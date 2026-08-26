use v5.10; use strict; use warnings;
use Test::More;
use_ok('Curl::Impersonate');
my $c = Curl::Impersonate->new;
isa_ok($c, 'Curl::Impersonate', 'new returns a handle');
done_testing;
