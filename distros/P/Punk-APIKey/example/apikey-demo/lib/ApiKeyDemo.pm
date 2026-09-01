package ApiKeyDemo;

use strict;
use warnings;
use Punk;
use Punk::Plugin::APIKey;      # compile time: api_key_guard parses as a word

our $VERSION = '0.01';

# Views, the static mount, the database and the models. See the note in the
# file about what is deliberately NOT in it.
config 'config/punk.yml';

# Minted per boot, so restarting the demo signs everybody out. A real
# application sources this from outside its configuration - see
# perldoc Punk/secret.
session secret => Punk::Auth::Password::token();

# The ladder API key scopes are measured against, below.
auth model => 'User', rank => [qw(member admin)];

# ---------------------------------------------------------------------------
# The plugin
# ---------------------------------------------------------------------------
#
# After `auth`, because scope_rank names rungs on its ladder and the plugin
# reads that ladder as it registers.
plugin 'APIKey' => {
    owner  => 'owner_id',
    kinds  => { live => 'sk_live_', test => 'sk_test_' },
    scopes => [qw(read write admin)],

    # What makes a key answer to its owner's CURRENT standing rather than
    # only to its own row. Without it a suspended account's keys keep
    # working and a demoted admin's key stays an admin key until somebody
    # remembers to revoke it by hand.
    #
    # With it: a suspended owner is a 403, an owner who is gone is a 401,
    # and a scope the owner's role no longer reaches is dropped from the
    # effective set for that request - the key keeps the rest.
    owner_model => 'User',
    owner_ttl   => 10,        # seconds, per worker; 10 so the demo is lively
    scope_rank  => { read => 'member', write => 'member', admin => 'admin' },
};

# ---------------------------------------------------------------------------
# The browser half: signing in, and managing your keys
# ---------------------------------------------------------------------------

get  '/'       => 'Web::Root#index',   { name => 'home' };
post '/login'  => 'Web::Root#login',   { name => 'login' };
post '/logout' => 'Web::Root#logout',  { name => 'logout' };

# Everything under here needs a session, not a key: minting a credential is
# not something a credential should be able to do.
my $account = under '/keys' => auth_guard;

$account->get('/'            => 'Web::Keys#index',  { name => 'keys' });
$account->post('/'           => 'Web::Keys#issue',  { name => 'keys_issue' });
$account->post('/:id/revoke' => 'Web::Keys#revoke', { name => 'keys_revoke' });

# The self-service switches the owner-standing check reads. A real
# application puts these behind an admin area; here they are one click, so
# the effect on a live key is visible immediately.
$account->post('/demote'  => 'Web::Keys#demote',  { name => 'keys_demote' });
$account->post('/promote' => 'Web::Keys#promote', { name => 'keys_promote' });
$account->post('/suspend' => 'Web::Keys#suspend', { name => 'keys_suspend' });
$account->post('/restore' => 'Web::Keys#restore', { name => 'keys_restore' });

# ---------------------------------------------------------------------------
# The API half: guarded by keys, and by nothing else
# ---------------------------------------------------------------------------
#
# One guard per scope. Denial is an API's denial - 401 with
# WWW-Authenticate: Bearer for a credential that is not good, 403 for a
# scope it lacks, never a redirect.

my $api = under '/api/v1' => api_key_guard(scope => 'read');

$api->get('/whoami' => 'API::V1#whoami', { name => 'api_whoami' });
$api->get('/notes'  => 'API::V1#list',   { name => 'api_notes' });

my $writer = under '/api/v1' => api_key_guard(scope => 'write');
$writer->post('/notes' => 'API::V1#create', { name => 'api_notes_create' });

my $admin = under '/api/v1/admin' => api_key_guard(scope => 'admin');
$admin->get('/stats' => 'API::V1#stats', { name => 'api_stats' });

1;