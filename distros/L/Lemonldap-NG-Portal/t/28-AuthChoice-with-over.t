use warnings;
use Test::More;
use strict;
use IO::String;
use JSON qw(from_json);

require 't/test-lib.pm';

my $res;

my $client = LLNG::Manager::Test->new( {
        ini => {
            logLevel          => 'error',
            useSafeJail       => 1,
            portalMainLogo    => 'common/logos/logo_llng_old.png',
            authentication    => 'Choice',
            restSessionServer => 1,
            nullAuthnLevel    => 1,
            userDB            => 'Same',
            authChoiceParam   => 'test',
            authChoiceModules => {
                '1_securenull' => 'Null;Null;Null;;;{"nullAuthnLevel": 3}',
                '2_null'       => 'Null;Null;Null;;;{}',
            },
        }
    }
);

ok( $res = $client->_get( '/', accept => 'text/html' ), 'Get Menu' );
ok( $res->[2]->[0] =~ /1_securenull/, '1_securenull displayed' );
ok( $res->[2]->[0] =~ /2_null/,       '2_null displayed' );

# Authenticate on first choice
my $postString = 'user=dwho&password=dwho&test=1_securenull';

ok(
    $res = $client->_post(
        '/',
        IO::String->new($postString),
        length => length($postString)
    ),
    'Auth query'
);
expectOK($res);
my $id = expectCookie($res);
is( getSession($id)->data->{authenticationLevel},
    3, "Overriden authentication level" );
$client->logout($id);

# Authenticate on second choice
$postString = 'user=dwho&password=dwho&test=2_null';

# Try to authenticate
# -------------------
ok(
    $res = $client->_post(
        '/',
        IO::String->new($postString),
        length => length($postString)
    ),
    'Auth query'
);
expectOK($res);
$id = expectCookie($res);
is( getSession($id)->data->{authenticationLevel},
    1, "Default authentication level" );
$client->logout($id);
clean_sessions();
done_testing();
