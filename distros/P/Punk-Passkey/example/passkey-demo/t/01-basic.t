#!perl
use 5.010;
use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/../lib";
use Test::More;

# The demo, driven without a browser.
#
# A passkey ceremony needs an authenticator to produce a signature, and
# there is not one here - so this test proves what a test can prove
# about a demo: that every route it mounts exists, answers the right
# shape, and refuses in the right way. That the CEREMONIES are correct
# is the dist's own suite (t/06, t/08, t/09), which drives them against
# registrations and assertions captured from real devices.
#
# The division is deliberate. A demo test that faked a signature would
# be asserting that the fake matched the fake.

BEGIN {
    chdir "$FindBin::Bin/.." or die "cannot chdir to the application root: $!\n";
    # the origin the browser will be on; see lib/PasskeyDemo.pm
    $ENV{PASSKEY_DEMO_ORIGIN} = 'http://localhost:5000';
}

# The schema is Sqitch's, not this test's. A test that created the
# tables itself would be testing tables nobody deploys - so it uses the
# deployed database or says what to run.
BEGIN {
    my $missing = 1;
    if (-f 'passkey-demo.db' && eval { require DBI; 1 }) {
        my $dbh = eval {
            DBI->connect('dbi:SQLite:dbname=passkey-demo.db', '', '',
                         { RaiseError => 0, PrintError => 0 });
        };
        $missing = 0 if $dbh && $dbh->selectrow_array(
            "SELECT 1 FROM sqlite_master WHERE type='table' AND name='passkeys'");
    }
    if ($missing) {
        require Test::More;
        Test::More::plan(skip_all =>
            'the schema is not deployed - run `punk sqitch deploy` first');
    }
}

use Punk::Test;
use MIME::Base64 ();
use File::Raw::JSON qw(file_json_encode);

sub b64u {
    my $s = shift;
    $s =~ tr{-_}{+/};
    $s .= '=' x ((4 - length($s) % 4) % 4);
    return MIME::Base64::decode_base64($s);
}

# The deployed database persists between runs - it is a demo database,
# not a fixture this test creates - so the test uses addresses of its
# own and removes them afterwards. A fixed address would collide with
# the previous run on the users table's unique index, and every
# assertion after the failed signup would then be testing a signed-out
# session.
my $RUN   = time . q{-} . $$;
my $EMAIL = qq{ada-$RUN\@example.com};

my $t = Punk::Test->new(q{PasskeyDemo});

# ---- the front page ----------------------------------------------------------

$t->get_ok('/')
  ->status_is(200)
  ->content_like(qr/Sign in with a passkey/, 'the front page offers a passkey')
  ->content_unlike(qr/type="password"/,
      'and never asks for a password - there is not one in this application');

$t->get_ok('/punk-passkey.js')
  ->status_is(200, 'the plugin serves its browser helper')
  ->content_like(qr/PunkPasskey/, 'which defines the helper the pages call');

# ---- creating an account -----------------------------------------------------

$t->post_ok(q{/signup}, form => { email => $EMAIL })
  ->status_is(302)
  ->header_is(Location => '/account/passkeys',
      'signing up goes straight to enrolment, because the account is only '
    . 'somebody for the credential to belong to');

$t->get_ok('/account/passkeys')
  ->status_is(200)
  ->content_like(qr/Your passkeys/, 'the management page renders')
  ->content_like(qr/None yet/, 'with nothing enrolled')
  ->content_like(qr/Recovery/,
      'and carries the recovery nudge, which is the part a demo usually '
    . 'leaves out');

# it is THIS application's layout, not the plugin's built-in page
$t->content_like(qr/Punk::Plugin::Passkey/,
    'through the app\'s own layout - the `render` option replaced the '
  . 'plugin\'s built-in page with a helper');

# ---- the creation options the browser would ask for --------------------------

$t->post_ok('/account/passkeys/options')
  ->status_is(200)
  ->json_is('/rp/id', 'localhost',
      'the rpId is the host of the DECLARED origin - not the request\'s, '
    . 'which is the check the whole scheme rests on')
  ->json_is('/attestation', 'none', 'and the attestation stance is stated')
  ->json_is('/authenticatorSelection/userVerification', 'preferred',
      'user verification is preferred, not required');

is(length b64u($t->json->{challenge}), 32,
    'with a 32-byte challenge, minted per ask');
is($t->json->{user}{name}, $EMAIL,
    'and the account it belongs to, which is what the authenticator '
  . 'shows the person choosing a credential');

# ---- the database, and the one thing SQLite could quietly break --------------
#
# A public key is the COSE bytes the authenticator sent: arbitrary
# binary, NUL bytes and all. If the column were TEXT, or the handle
# decoded UTF-8 on the way back, the key read at login would differ from
# the key stored at registration - and every signature would fail with
# nothing obviously wrong anywhere. So the round trip is asserted rather
# than assumed.
{
    ok(-f q{passkey-demo.db}, q{the database is the one sqitch deployed});

    my $schema = do {
        require DBI;
        my $dbh = DBI->connect('dbi:SQLite:dbname=passkey-demo.db', '', '',
                               { RaiseError => 1 });
        my ($sql) = $dbh->selectrow_array(
            'SELECT sql FROM sqlite_master WHERE name = ?', undef, 'passkeys');
        $dbh->disconnect;
        $sql // '';
    };
    like($schema, qr/public_key\s+BLOB/i,
        q{deployed from the SQL this distribution ships, with public_key }
      . q{a BLOB - `punk sqitch deploy` ran it, so the demo cannot drift }
      . q{from the schema everybody else gets});
    like($schema, qr/credential_id\s+TEXT\s+NOT NULL UNIQUE/i,
        'and credential_id unique across the whole table');

    # a COSE key shaped like a real one, with the bytes that break things
    my $cose = "\xa5\x01\x02\x03\x26\x20\x01\x21\x58\x20"
             . ("\x00\xff\x41" x 10) . "\x00\x00";
    my $app  = PasskeyDemo->punk_app;
    my $keys = $app->model_instance('Passkey');
    my $user = $app->model_instance('User')
                   ->create({ email => "binary-$RUN\@example.com" });

    my $made = $keys->create({
        user_id       => $user->{id},
        credential_id => qq{round-trip-$RUN},
        public_key    => $cose,
        sign_count    => 0,
        created_at    => time,
    });
    ok($made, 'a credential with a binary key stores');

    my $back = $keys->get(credential_id => qq{round-trip-$RUN});
    is(length $back->{public_key}, length $cose,
        'and reads back at its full length - a NUL did not truncate it');
    is($back->{public_key}, $cose,
        'byte for byte identical, which is the whole requirement: a key '
      . 'that changed in the database is a login that can never succeed');
    ok(!utf8::is_utf8($back->{public_key}),
        'and comes back as bytes, not characters');
}

# ---- removing what does not exist --------------------------------------------

$t->delete_ok('/account/passkeys/nothing-like-this')
  ->status_is(409,
      'with no passkeys at all the delete route still refuses - this '
    . 'application has no other factor, so it will not remove a last one');

# ---- signing out -------------------------------------------------------------

$t->post_ok('/signout')->status_is(302);
$t->get_ok('/')
  ->content_like(qr/Sign in with a passkey/,
      'and the front page is back to offering a passkey');

$t->get_ok('/account/passkeys')
  ->status_is(401, 'the management page is closed when nobody is signed in');

# ---- the login endpoint ------------------------------------------------------

$t->post_ok('/login/passkey/options')
  ->status_is(200)
  ->json_is('/rpId', 'localhost', 'the request options carry the rpId');

$t->post_ok('/login/passkey',
    body => file_json_encode({
        id                => 'no-such-credential',
        clientDataJSON    => 'x',
        authenticatorData => 'y',
        signature         => 'z',
    }),
    type => 'application/json')
  ->status_is(401, 'a bogus assertion is refused')
  ->json_is('/error', 'authentication failed',
      'with the one message every failure gets - the endpoint is not an '
    . 'oracle for which credentials this site knows');

# tidy up: the database outlives this test, so it should not accumulate
# a user and a credential per run
{
    require DBI;
    my $dbh = DBI->connect(q{dbi:SQLite:dbname=passkey-demo.db}, q{}, q{},
                           { RaiseError => 0, PrintError => 0 });
    if ($dbh) {
        $dbh->do(q{DELETE FROM passkeys WHERE credential_id LIKE ?},
                 undef, qq{round-trip-$RUN});
        $dbh->do(q{DELETE FROM users WHERE email LIKE ?},
                 undef, qq{%-$RUN\@example.com});
        $dbh->disconnect;
    }
}

done_testing();
