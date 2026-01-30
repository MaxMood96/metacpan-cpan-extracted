use strict;
use warnings;
use Test::More;

use Test::RedisServer;

eval { Test::RedisServer->new } or plan skip_all => 'redis-server is required in PATH to run this test';

my $server;
eval {
    $server = Test::RedisServer->new( conf => {
        'unknown_key' => 'unknown_val',
    });
};

ok !$server, 'server did not initialize ok';

like $@, qr/(?:\*\*\* FATAL CONFIG FILE ERROR( \([^\)]+\))? \*\*\*|Module Configuration detected without loadmodule directive or no ApplyConfig call: aborting)/, 'error msg ok';

done_testing;
