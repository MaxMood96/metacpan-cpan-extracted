#!perl
use 5.010;
use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/../lib";
use Test::More;

# The same fallback app.psgi uses: this dist's blib and its siblings.
BEGIN {
    my $dist = "$FindBin::Bin/../../..";
    for my $b ("$dist/blib", map { "$dist/../$_/blib" }
               'File-Raw-Hash', 'QR-Code', 'Punk-TOTP') {
        unshift @INC, "$b/lib", "$b/arch" if -d $b;
    }
}
use Punk::Test;
use Punk::TOTP ();

# One Punk::Test object is one browser: its cookie jar carries the session
# across every request, which is what a sign-in flow needs.
chdir "$FindBin::Bin/.." or die "cannot chdir to the application root: $!\n";

my $t = Punk::Test->new('TOTPDemo');

# ---- signed out ---------------------------------------------------------
$t->get_ok('/')->status_is(200)
  ->content_like(qr/Sign in/, 'the signed-out page')
  ->content_like(qr{/static/style\.css}, 'through the layout');
$t->get_ok('/static/style.css')->status_is(200);
$t->post_ok('/login', form => { password => 'nope' })->status_is(302);
$t->get_ok('/')->content_like(qr/wrong password/, 'a bad password is noticed');

# ---- no factor yet: straight in, then enrol -----------------------------
$t->post_ok('/login', form => { password => 'punk' })->status_is(302);
$t->get_ok('/')->status_is(200)
  ->content_like(qr/Enrol a phone/, 'enrolment is offered')
  ->content_like(qr/signed in as <code>you\@example\.com/, 'the layout knows who');
my ($secret) = $t->body =~ m{by hand: <code>([A-Z2-7]+)</code>};
ok $secret, 'the pending secret is shown';
like $t->body, qr/<svg/, 'and the QR rendered raw';

$t->post_ok('/enrol', form => { code => '000000' })->status_is(302);
$t->get_ok('/')->content_like(qr/enrolment refused/, 'a wrong code is refused');
my $now = time;
$t->post_ok('/enrol', form => { code => Punk::TOTP->code($secret, time => $now) })
  ->status_is(302);
$t->get_ok('/')->content_like(qr/Enrolled/, 'a right code completes enrolment')
  ->content_like(qr/has NOT passed the factor/, 'but this session has not met the challenge');

# ---- the step-up guard --------------------------------------------------
$t->get_ok('/vault/contents')->status_is(302)
  ->header_is(Location => '/login/totp', 'totp_guard steps up');
$t->get_ok('/login/totp')->status_is(200)
  ->content_like(qr/Second factor/, 'the challenge page, through the layout');
$t->post_ok('/login/totp', form => { code => Punk::TOTP->code($secret, time => $now) })
  ->status_is(200)->content_like(qr/did not work/,
      'the enrolment code is a replay - refused by the floor');
$t->post_ok('/login/totp', form => { code => Punk::TOTP->code($secret, time => $now + 30) })
  ->status_is(302)->header_is(Location => '/vault/contents',
      'the next window passes and returns to the stepped-up page');
$t->get_ok('/vault/contents')->status_is(200)->content_like(qr/The vault/);

# ---- recovery codes, then the real sign-in ------------------------------
$t->post_ok('/recovery')->status_is(200);
my @codes = $t->body =~ m{<code>([A-Z2-7]{8}-[A-Z2-7]{8})</code>}g;
is scalar @codes, 5, 'five recovery codes, shown once';

$t->post_ok('/logout')->status_is(302);
$t->post_ok('/login', form => { password => 'punk' })->status_is(302)
  ->header_is(Location => '/login/totp', 'enrolled: the password leads to the challenge');
$t->get_ok('/')->content_like(qr/Sign in/, 'pending is not a login');
$t->post_ok('/login/totp', form => { code => lc $codes[0] })->status_is(302)
  ->header_is(Location => '/', 'a recovery code passes, case folded');
$t->get_ok('/')->content_like(qr/passed the factor/, 'the session carries totp_at');

# ---- three misses un-answer the password --------------------------------
$t->post_ok('/logout');
$t->post_ok('/login', form => { password => 'punk' });
$t->post_ok('/login/totp', form => { code => '111111' }) for 1 .. 2;
$t->post_ok('/login/totp', form => { code => '111111' })->status_is(302)
  ->header_is(Location => '/', 'three misses drop the pending state');

$t->get_ok('/no-such-page')->status_is(404);
done_testing();
