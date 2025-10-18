# Test sessions explorer API

use warnings;
use Test::More;
use IO::String;
use JSON;
use strict;
use Lemonldap::NG::Common::Session;

require 't/test-lib.pm';

eval { mkdir "$main::tmpdir/sessions/oidc" };
eval { mkdir "$main::tmpdir/sessions/lock" };

$LLNG::Manager::Test::defaultIni = {
    protection                      => 'none',
    issuerDBOpenIDConnectActivation => 1,
    oidcStorage                     => 'Apache::Session::File',
    oidcStorageOptions              => {
        Directory      => "$main::tmpdir/sessions/oidc",
        LockDirectory  => "$main::tmpdir/sessions/oidc",
        generateModule =>
          'Lemonldap::NG::Common::Apache::Session::Generate::SHA256'
    },
};

sub newSession {
    my ( $uid, $ip, $kind, $storage ) = @_;
    my $tmp;
    $storage ||= "$main::tmpdir/sessions";
    ok(
        $tmp = Lemonldap::NG::Common::Session->new( {
                storageModule        => 'Apache::Session::File',
                storageModuleOptions => {
                    Directory      => $storage,
                    LockDirectory  => "$main::tmpdir/sessions/lock",
                    generateModule =>
'Lemonldap::NG::Common::Apache::Session::Generate::SHA256',
                },
            }
        ),
        'Sessions module'
    );
    count(1);
    $tmp->update( {
            ipAddr        => $ip,
            _whatToTrace  => $uid,
            uid           => $uid,
            _utime        => time,
            _session_kind => ( $kind || 'SSO' ),
        }
    );
    return $tmp->{id};
}

# Single session access
my @ids;
$ids[0] = newSession( 'dwho', '127.10.0.1' );
$ids[1] = newSession( 'dwho', '127.2.0.2' );
$ids[2] = newSession( 'foo',  '127.3.0.3' );
$ids[3] = newSession( 'foo',  '127.3.0.3' );
$ids[4] = newSession( 'dwho', '127.2.3.4', 'OIDCI', "$main::tmpdir/oidc" );
$ids[4] = newSession( 'dwho', '127.2.3.4', 'OIDCI', "$main::tmpdir/oidc" );

# Delete sessions using globalLogout
foreach ( $ids[0], $ids[2] ) {
    my $res;
    ok(
        $res = &client->_post(
            "/sessions/glogout/global/$_", undef,
            IO::String->new(),             'text/plain',
            0
        ),
        "Call global logout on session $_"
    );
    ok( $res->[0] == 200, 'Result code is 200' );
    ok( from_json( $res->[2]->[0] )->{result} == 1,
        'Body is JSON and result==1' );
    ok( from_json( $res->[2]->[0] )->{count} >= 2,
        'at least 2 sessions deleted' );
    count(4);
}

opendir D, "$main::tmpdir/sessions/oidc" or die $!;
my @files = grep { not /(?:^(?:(?:lock|oidc)$|\.)|\.lock$)/ } readdir D;
ok( @files == 0, "OIDC Session directory is empty" )
  or print STDERR "Files found:\n" . join( "\n", @files ) . "\n";
closedir D;
count(1);
opendir D, "$main::tmpdir/sessions" or die $!;
@files =
  grep { not /(?:^(?:(?:lock|oidc)$|\.)|\.lock$)/ } readdir D;
ok( @files == 0, "Session directory is empty" )
  or print STDERR "Files found:\n" . join( "\n", @files ) . "\n";
closedir D;
count(1);

done_testing( count() );
