use strict;
use warnings;
use Test::More;
use EV::Telegram::TDLib;

my $res = EV::Telegram::TDLib->execute({
    '@type' => 'getTextEntities',
    text    => 'hello @durov #tag',
});

is ref($res), 'HASH', 'execute returns a decoded hashref';
is $res->{'@type'}, 'textEntities', 'got textEntities back';
ok scalar @{ $res->{entities} }, 'found at least one entity';

my $bad = EV::Telegram::TDLib->execute({ '@type' => 'noSuchSynchronousMethod' });
is $bad->{'@type'}, 'error', 'unknown method yields an error object';
ok $bad->{code}, 'error carries a code';

done_testing;
