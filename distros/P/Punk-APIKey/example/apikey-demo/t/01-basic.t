#!perl
use 5.010;
use strict;
use warnings;
use FindBin ();
use Test::More;
use Cwd ();
use File::Path ();
use File::Spec ();

# The whole demo, driven: sign in, mint a key, spend it, narrow it, suspend
# it, revoke it.
#
# It is the example's proof that the README is not fiction, and it doubles as
# the shortest readable description of what the plugin does to a request.

BEGIN {
    # Before the application compiles, because `config` reads the environment
    # as it does.
    $ENV{PUNK_ENV} = 'test';
}

chdir "$FindBin::Bin/.." or die "cannot chdir to the application root: $!\n";

BEGIN {
    # Run against the working copies when this is a checkout rather than an
    # install: this distribution's blib, and Punk's beside it.
    my $dist = "$FindBin::Bin/../../..";
    for my $b ($dist, "$dist/../Punk") {
        unshift @INC, "$b/blib/lib", "$b/blib/arch" if -d "$b/blib";
    }
    unshift @INC, "$FindBin::Bin/../lib";
}

use Punk::Test;

plan skip_all => 'DBD::SQLite required' unless eval { require DBD::SQLite; 1 };
plan skip_all => 'App::Sqitch and the sqlite3 client are required to deploy'
    unless eval { require App::Sqitch; 1 } && _which('sqlite3');

# ---- a schema, deployed the way an operator deploys one ----------------------
#
# In a child, and not for tidiness: `punk sqitch` loads the application to
# find its plugins' projects, and to_app compiles a class once per
# interpreter - so doing it here would leave nothing for Punk::Test to build.

File::Path::remove_tree('var/test') if -d 'var/test';
File::Path::make_path('var/test');

{
    my $inc = join ' ', map { "-I'$_'" } grep { !ref } @INC;
    my $out = qx{PUNK_ENV=test $^X $inc -e 'require Punk::Command; require Punk::Command::Sqitch; exit Punk::Command->main("sqitch","deploy")' 2>&1};
    is($?, 0, 'punk sqitch deploy applies both projects') or BAIL_OUT($out);
    like($out, qr/punk_apikey/,
        'the plugin\'s own project deploys - the application never named it');
    like($out, qr/api_keys \.\. ok/, 'creating the api_keys table');
    like($out, qr/users \.\. ok/,    'and this project\'s own users table');
}

my $t = Punk::Test->new('ApiKeyDemo');

# ---- the browser half -------------------------------------------------------

$t->get_ok('/')->status_is(200)->content_like(qr/Sign in/, 'the sign-in page');

$t->post_ok('/login', form => { email => 'dev@example.com' }, csrf => 1)
  ->status_is(302, 'signing in redirects');

$t->get_ok('/keys')->status_is(200)
  ->content_like(qr/Mint one/, 'the keys page');

# ---- minting ----------------------------------------------------------------

$t->post_ok('/keys', csrf => 1, form => {
    label  => 'CI',
    scopes => 'read write admin',
    kind   => 'live',
})->status_is(200);

my ($key) = $t->body =~ /data-reveal>([^<]+)</;

# data-reveal rather than the first <code> on the page: the table under it
# prints every key's PREFIX in a <code> too, and a prefix does not
# authenticate anything.
ok($key, 'the page prints the key once') or BAIL_OUT('no key to spend');
like($key, qr/\Ask_live_[A-Za-z0-9_-]{43}[A-Za-z0-9]{6}\z/,
    'kind prefix, 43 characters of base64url, six of checksum');

$t->get_ok('/keys')->content_unlike(qr/\Q$key\E/,
    'and the list does not print it again - nothing kept it');

# ---- spending it ------------------------------------------------------------

$t->request_header(Authorization => "Bearer $key");

$t->get_ok('/api/v1/whoami')->status_is(200)
  ->json_is('/kind' => 'live')
  ->json_is('/label' => 'CI');

$t->get_ok('/api/v1/notes')->status_is(200)
  ->json_is('/notes' => [], 'no notes yet');

$t->post_ok('/api/v1/notes', json => { body => 'from CI' })
  ->status_is(201, 'the write scope writes')
  ->json_is('/note/body' => 'from CI');

$t->get_ok('/api/v1/admin/stats')->status_is(200, 'and admin admins')
  ->json_is('/notes' => 1);

# ---- a credential that is not good -----------------------------------------

{
    my $t2 = Punk::Test->new('ApiKeyDemo');
    $t2->get_ok('/api/v1/notes')->status_is(401, 'no credential is a 401');

    $t2->request_header(Authorization => 'Bearer sk_live_nonsense');
    $t2->get_ok('/api/v1/notes')
       ->status_is(401, 'and so is a malformed one - the checksum is refused '
                      . 'before the database is touched');

    # Every reason is the same 401: a client that could tell "unknown" from
    # "revoked" could enumerate keys.
    $t2->request_header(Authorization => "Bearer $key" . 'x');
    $t2->get_ok('/api/v1/notes')->status_is(401, 'a mangled checksum too');
}

# ---- the owner's standing narrows the key ----------------------------------

$t->post_ok('/keys/demote', csrf => 1)->status_is(302);

$t->get_ok('/api/v1/admin/stats')
  ->status_is(403, 'demoted: the admin scope is gone');
$t->get_ok('/api/v1/notes')
  ->status_is(200, 'and the scopes the new role still reaches keep working');
$t->get_ok('/api/v1/whoami')
  ->json_is('/scopes' => ['read', 'write'],
      'the effective set is narrower than the row, which is unchanged')
  ->json_is('/granted' => 'read write admin');

$t->post_ok('/keys/promote', csrf => 1)->status_is(302);
$t->get_ok('/api/v1/admin/stats')->status_is(200, 'promoted: it is back');

# ---- suspension ------------------------------------------------------------

$t->post_ok('/keys/suspend', csrf => 1)->status_is(302);

$t->get_ok('/api/v1/notes')
  ->status_is(403, 'a suspended owner is 403, not 401: the caller has already '
                 . 'proved they hold the key, so there is nothing to hide');

$t->post_ok('/keys/restore', csrf => 1)->status_is(302);
$t->get_ok('/api/v1/notes')->status_is(200, 'restored');

# ---- revoking --------------------------------------------------------------

my ($id) = $t->get_ok('/keys')->body =~ /<td><code>(\d+)<\/code><\/td>/;
$t->post_ok("/keys/$id/revoke", csrf => 1)->status_is(302);

$t->get_ok('/api/v1/notes')->status_is(401, 'a revoked key is a 401');
$t->get_ok('/keys')->content_like(qr/revoked/,
    'and the row stays in the list - revoking is a timestamp, not a delete');

sub _which {
    my ($cmd) = @_;
    for my $p (split /:/, ($ENV{PATH} || '')) {
        return 1 if -x File::Spec->catfile($p, $cmd);
    }
    return 0;
}

done_testing();
