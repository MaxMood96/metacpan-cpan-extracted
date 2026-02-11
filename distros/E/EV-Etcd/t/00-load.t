use strict;
use warnings;
use lib 'blib/lib', 'blib/arch';
use Test::More;

BEGIN {
    eval { require EV };
    if ($@) {
        plan skip_all => 'EV module not available';
        exit;
    }
}

plan tests => 2;

use_ok('EV::Etcd');

my $client = EV::Etcd->new(endpoints => ['127.0.0.1:2379']);
isa_ok($client, 'EV::Etcd');
