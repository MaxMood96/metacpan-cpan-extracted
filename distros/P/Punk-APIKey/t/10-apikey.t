#!perl
use 5.010;
use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/lib";
use Test::More;

BEGIN {
    plan skip_all => 'Punk 0.32+ required'
        unless eval { require Punk; Punk->VERSION('0.32'); 1 };
}

use TFake ();
use Punk::Plugin::APIKey ();

my $P = 'Punk::Plugin::APIKey';
my %KINDS = ( live => 'sk_live_', test => 'sk_test_' );

# ---- the key format ----------------------------------------------------------
#
# Asserted directly. A key that fails to parse never becomes a query, so this
# is the layer that has to be right before anything else is worth testing.

{
    my $k = $P->_mint('sk_live_');
    is(length $k, 8 + 43 + 6, 'a key is its prefix, 43 random and 6 checksum');
    like($k, qr/\Ask_live_[A-Za-z0-9_-]{43}[A-Za-z0-9]{6}\z/,
        'in the two alphabets it declares');

    my ($verdict, $kind) = $P->_parse(\%KINDS, $k);
    is($verdict, 'ok',   'and it parses');
    is($kind,    'live', 'as the kind its prefix names');

    my ($v2, $k2) = $P->_parse(\%KINDS, $P->_mint('sk_test_'));
    is("$v2/$k2", 'ok/test', 'the other kind too');

    isnt($P->_mint('sk_live_'), $P->_mint('sk_live_'),
        'two keys differ - the entropy is Punk::Auth::Password::token');

    is($P->_stored_prefix($k, 8), substr($k, 0, 16),
        'the stored prefix is the kind prefix plus eight characters: '
      . 'recognisable in a list, useless as a credential');

    like($P->_digest($k), qr/\A[0-9a-f]{64}\z/,
        'the stored digest is lowercase sha256 hex, the same wire form '
      . 'auth_tokens uses');
    is($P->_digest($k), $P->_digest($k), 'and it is a function of the key');
}

{
    # every verdict the parser can reach
    my $k = $P->_mint('sk_live_');

    my $bad = $k;
    substr($bad, -1) = (substr($bad, -1) eq 'A' ? 'B' : 'A');
    is(($P->_parse(\%KINDS, $bad))[0], 'bad_checksum',
        'one character of the checksum is enough');

    my $flip = $k;
    substr($flip, 10, 1) = (substr($flip, 10, 1) eq 'A' ? 'B' : 'A');
    is(($P->_parse(\%KINDS, $flip))[0], 'bad_checksum',
        'and so is one character of the random part');

    is(($P->_parse(\%KINDS, 'sk_live_short'))[0], 'malformed',
        'a truncated key is malformed');
    is(($P->_parse(\%KINDS, $k . 'x'))[0], 'malformed', 'so is a long one');
    is(($P->_parse(\%KINDS, 'sk_live_' . ('!' x 49)))[0], 'malformed',
        'and one outside the alphabet');
    is(($P->_parse(\%KINDS, 'zz_' . ('a' x 49)))[0], 'unknown_kind',
        'a prefix nobody configured is its own verdict');
    is(($P->_parse(\%KINDS, ''))[0], 'malformed', 'and so is nothing at all');

    # the checksum is over the random part, and _checksum says what it is
    my $rand = substr($k, 8, 43);
    is($P->_checksum($rand), substr($k, -6),
        '_checksum computes what _mint appended');
}

# ---- the application ---------------------------------------------------------

{
    package App;
    use Punk;
    use Punk::Plugin::APIKey;

    session secret => 'x' x 32;
    auth model => 'TFake::Model::User', rank => [qw(member admin owner)];
    database backend => 'TFake::KeyBackend';
    model 'TFake::Model::ApiKey';
    model 'TFake::Model::User';

    plugin 'APIKey' => {
        model  => 'TFake::Model::ApiKey',
        owner  => 'owner_id',
        kinds  => { live => 'sk_live_', test => 'sk_test_' },
        scopes => [qw(read write admin)],

        owner_model => 'TFake::Model::User',
        owner_ttl   => 30,
        scope_rank  => { read => 'member', write => 'member',
                         admin => 'admin' },
    };

    get '/open' => sub { $_[0]->text('open') };

    my $api = under '/api' => api_key_guard;
    $api->get('/any' => sub {
        my ($c) = @_;
        my $a = $c->stash->{auth} || {};
        return $c->text(join '|', $a->{owner} // '-', $a->{kind} // '-',
                        join(',', @{ $a->{scopes} || [] }));
    });

    my $w = under '/w' => api_key_guard(scope => 'write');
    $w->get('/x' => sub { $_[0]->text('wrote') });

    my $adm = under '/adm' => api_key_guard(scope => 'admin');
    $adm->get('/x' => sub { $_[0]->text('administered') });

    my $rw = under '/rw' => api_key_guard(scope => [qw(read write)]);
    $rw->get('/x' => sub { $_[0]->text('either') });

    # A checker needs a real context to be called with, so a route lends it
    # one. The OpenAPI mount would supply the same four arguments.
    our ($CHECKER, $CRED, $OUT);
    get '/checker' => sub {
        my ($c) = @_;
        $OUT = $CHECKER->($CRED, $c, 'someOp', []);
        return $c->text('done');
    };
}

my $app = App->to_app;

sub hit {
    my ($path, %o) = @_;
    my %env = (
        REQUEST_METHOD => 'GET', PATH_INFO => $path, QUERY_STRING => '',
        SERVER_NAME => 'x', SERVER_PORT => 80, HTTP_HOST => 'x',
        'psgi.url_scheme' => 'http',
    );
    $env{HTTP_AUTHORIZATION} = "Bearer $o{key}" if defined $o{key};
    $env{HTTP_AUTHORIZATION} = $o{raw_auth}     if defined $o{raw_auth};
    my $r = $app->(\%env);
    my %h = @{ $r->[1] };
    return { status => $r->[0],
             body   => join('', map { defined $_ ? $_ : '' } @{ $r->[2] }),
             headers => \%h };
}

sub fresh {
    TFake::KeyBackend->reset_all;
    TFake::KeyBackend->set_users(
        { id => 1, email => 'a@x', role => 'admin',  verified => 1 },
        { id => 2, email => 'b@x', role => 'member', verified => 1 },
    );
    Punk::Plugin::APIKey->forget_owners('App');
    return;
}

# ---- issue, and a passing request --------------------------------------------

fresh();
my ($key, $row) = $P->issue_for('App', owner => 1, label => 'CI',
                                scopes => ['read'], kind => 'test');

ok($key, 'issue returns the plaintext');
like($key, qr/\Ask_test_/, 'of the kind asked for');
ok(!exists $row->{digest},
    'and a row with no digest in it - a list that leaks the digest has '
  . 'leaked every key on the page');
is($row->{label}, 'CI', 'with the label');
is($row->{owner_id}, 1, 'and the owner');

{
    my $r = hit('/api/any', key => $key);
    is($r->{status}, 200, 'a good key passes the guard');
    is($r->{body}, '1|test|read', 'and the auth slot has owner, kind, scopes');
}

is(hit('/open')->{status}, 200, 'an unguarded route needs no key');

# ---- every refusal is the same refusal ---------------------------------------
#
# Missing, malformed, bad checksum, unknown kind, unknown digest, revoked,
# expired: one status and one body. A client that could tell "unknown" from
# "revoked" could enumerate keys.

{
    my $good = hit('/api/any', key => $key);
    my $bad_ck = $key;
    substr($bad_ck, -1) = (substr($bad_ck, -1) eq 'A' ? 'B' : 'A');

    my $unknown = $P->_mint('sk_live_');    # never issued
    my $expired_key;
    my $revoked_key;
    {
        my ($k2, $r2) = $P->issue_for('App', owner => 1, label => 'gone',
                                      scopes => ['read']);
        $P->revoke_for('App', $r2->{id});
        $revoked_key = $k2;

        my ($k3) = $P->issue_for('App', owner => 1, label => 'old',
                                 scopes => ['read'], expires => time - 1);
        $expired_key = $k3;
    }

    my @cases = (
        [ 'no credential at all', undef ],
        [ 'a malformed key',      'sk_live_nope' ],
        [ 'a bad checksum',       $bad_ck ],
        [ 'an unknown kind',      'zz_' . ('a' x 49) ],
        [ 'an unknown digest',    $unknown ],
        [ 'a revoked key',        $revoked_key ],
        [ 'an expired key',       $expired_key ],
    );
    for my $c (@cases) {
        my ($what, $k) = @$c;
        my $r = defined $k ? hit('/api/any', key => $k) : hit('/api/any');
        is($r->{status}, 401, "$what is a 401");
        is($r->{body}, '{"errors":[{"message":"Unauthorized"}]}',
            "...with the same body as every other");
        is($r->{headers}{'WWW-Authenticate'}, 'Bearer',
            '...and WWW-Authenticate');
    }
}

# ---- a mangled key never reaches the database --------------------------------

{
    # The whole value of carrying a checksum: a typo costs no query, and
    # cannot be timed against a real lookup.
    my $bad = $key;
    substr($bad, -1) = (substr($bad, -1) eq 'A' ? 'B' : 'A');

    TFake::KeyBackend->reset_calls;
    hit('/api/any', key => $bad);
    is(TFake::KeyBackend->key_calls, 0,
        'a bad checksum is refused before the database is touched');

    TFake::KeyBackend->reset_calls;
    hit('/api/any', key => 'sk_live_short');
    is(TFake::KeyBackend->key_calls, 0, 'so is a malformed key');

    TFake::KeyBackend->reset_calls;
    hit('/api/any', key => $key);
    cmp_ok(TFake::KeyBackend->key_calls, '>=', 1,
        'while a well-formed one does look itself up');
}

# ---- the kind mismatch -------------------------------------------------------

{
    # A key whose prefix claims one kind while its row records another is
    # forged or mangled, and the row is the one this application wrote.
    fresh();
    my ($k, $r) = $P->issue_for('App', owner => 1, label => 'k',
                                scopes => ['read'], kind => 'live');
    is(hit('/api/any', key => $k)->{status}, 200, 'a live key passes');

    for my $row (@{ TFake::KeyBackend->keys_rows }) {
        $row->{kind} = 'test' if $row->{id} == $r->{id};
    }
    is(hit('/api/any', key => $k)->{status}, 401,
        'and is refused once its row says a different kind');
}

# ---- scopes ------------------------------------------------------------------

{
    fresh();
    my ($read)  = $P->issue_for('App', owner => 1, label => 'r',
                                scopes => ['read']);
    my ($write) = $P->issue_for('App', owner => 1, label => 'w',
                                scopes => ['write']);
    my ($both)  = $P->issue_for('App', owner => 1, label => 'rw',
                                scopes => ['read', 'write']);

    is(hit('/w/x', key => $write)->{status}, 200, 'the scope the guard wants');
    is(hit('/w/x', key => $both)->{status},  200, 'or one of several held');

    my $r = hit('/w/x', key => $read);
    is($r->{status}, 403, 'a scope the key lacks is a 403, not a 401');
    is($r->{body}, '{"errors":[{"message":"Forbidden"}]}', 'with that body');

    # write does not imply read: a scope is a permission, not a rank
    is(hit('/api/any', key => $write)->{status}, 200,
        'a guard with no scope takes any valid key');
    is(hit('/rw/x', key => $read)->{status},  200, 'an any-of guard, one way');
    is(hit('/rw/x', key => $write)->{status}, 200, '...and the other');
}

{
    # A guard naming a scope outside the vocabulary is a build failure, not a
    # route that refuses everyone in production.
    my $err = '';
    eval { $P->_check_guard_opts($P->state_for('App'), { scope => 'wrte' }) }
        or $err = $@;
    like($err, qr/scope 'wrte' is not in the vocabulary \(admin, read, write\)/,
        'a mistyped guard scope croaks, listing the vocabulary');

    $err = '';
    eval { $P->_check_guard_opts($P->state_for('App'), { scoop => 'read' }) }
        or $err = $@;
    like($err, qr/unknown guard option 'scoop'/, 'and so does a mistyped option');
}

# ---- the header form ---------------------------------------------------------

{
    fresh();
    my ($k) = $P->issue_for('App', owner => 1, label => 'h', scopes => ['read']);
    is(hit('/api/any', raw_auth => "bearer $k")->{status}, 200,
        'the Bearer scheme is case insensitive, as RFC 7235 says');
    is(hit('/api/any', raw_auth => $k)->{status}, 200,
        'and a bare key is taken too, for a client that sent no scheme');
}

# ---- the owner's standing ----------------------------------------------------

{
    fresh();
    my ($admin_key) = $P->issue_for('App', owner => 1, label => 'a',
                                    scopes => [qw(read write admin)]);

    is(hit('/adm/x', key => $admin_key)->{status}, 200,
        'an admin owner may use an admin-scoped key');

    # demotion NARROWS: the CI keeps deploying and stops administering
    $_->{role} = 'member' for grep { $_->{id} == 1 }
                                   @{ TFake::KeyBackend->users_rows };
    $P->forget_owners('App');

    is(hit('/adm/x', key => $admin_key)->{status}, 403,
        'a demoted owner loses the scope their rank no longer reaches');
    is(hit('/w/x', key => $admin_key)->{status}, 200,
        '...and keeps the ones it does - a demotion is not a revocation');

    {
        my $r = hit('/api/any', key => $admin_key);
        is($r->{body}, '1|live|read,write',
            'and the effective scope set is what the auth slot reports');
    }
}

{
    fresh();
    my ($k) = $P->issue_for('App', owner => 2, label => 's', scopes => ['read']);
    is(hit('/api/any', key => $k)->{status}, 200, 'a good owner passes');

    $_->{suspended} = time for grep { $_->{id} == 2 }
                                    @{ TFake::KeyBackend->users_rows };
    $P->forget_owners('App');

    my $r = hit('/api/any', key => $k);
    is($r->{status}, 403,
        'a suspended owner is a 403: the caller has already proved they hold '
      . 'the key, so there is nothing to enumerate');
    is($r->{body}, '{"errors":[{"message":"Forbidden"}]}', 'with that body');
}

{
    fresh();
    my ($k) = $P->issue_for('App', owner => 2, label => 'd', scopes => ['read']);
    TFake::KeyBackend->set_users(
        { id => 1, email => 'a@x', role => 'admin', verified => 1 });
    $P->forget_owners('App');

    my $r = hit('/api/any', key => $k);
    is($r->{status}, 401,
        'an owner who is gone is a 401 - the same answer as an unknown key, '
      . 'because which of the two it is is nobody else\'s business');
}

{
    # The standing is read once per owner_ttl, not once per request.
    fresh();
    my ($k) = $P->issue_for('App', owner => 1, label => 't', scopes => ['read']);
    hit('/api/any', key => $k);           # warm it

    TFake::KeyBackend->reset_calls;
    hit('/api/any', key => $k) for 1 .. 5;
    is(TFake::KeyBackend->user_calls, 0,
        'the owner standing is cached for owner_ttl, not read per request');

    $P->forget_owners('App');
    hit('/api/any', key => $k);
    cmp_ok(TFake::KeyBackend->user_calls, '>=', 1, 'and re-read once it expires');
}

{
    # THE ONE PLACE THIS DISTRIBUTION FAILS CLOSED. A missing rate-limit arena
    # means no limiting, which is degraded service; an unreadable owner table
    # means the guard cannot tell whether this credential is still good.
    fresh();
    my ($k) = $P->issue_for('App', owner => 1, label => 'x', scopes => ['read']);
    hit('/api/any', key => $k);
    $P->forget_owners('App');

    TFake::KeyBackend->die_users(1);
    my $r = hit('/api/any', key => $k);
    TFake::KeyBackend->die_users(0);

    is($r->{status}, 503,
        'an unreadable owner table refuses rather than honouring a '
      . 'credential nobody can vouch for');
    ok($r->{headers}{'Retry-After'}, 'with Retry-After');
}

# ---- revoke, list, and the rotation grace ------------------------------------

{
    fresh();
    my ($k1, $r1) = $P->issue_for('App', owner => 1, label => 'one',
                                  scopes => ['read']);
    my ($k2, $r2) = $P->issue_for('App', owner => 1, label => 'two',
                                  scopes => ['read']);
    my ($k3)      = $P->issue_for('App', owner => 2, label => 'other',
                                  scopes => ['read']);

    my $list = $P->keys_for('App', 1);
    is(scalar @$list, 2, 'keys_for lists one owner\'s keys');
    ok(!grep({ exists $_->{digest} } @$list), 'and never the digest');
    is_deeply([ sort map { $_->{label} } @$list ], [qw(one two)], 'by label');

    $P->revoke_for('App', $r1->{id});
    is(hit('/api/any', key => $k1)->{status}, 401, 'a revoked key stops working');
    is(hit('/api/any', key => $k2)->{status}, 200, 'and its sibling does not');

    my ($row) = grep { $_->{id} == $r1->{id} } @{ TFake::KeyBackend->keys_rows };
    ok($row, 'revoke is a timestamp, not a delete: the row is still there');
    ok($row->{revoked}, 'stamped');

    is(scalar @{ $P->keys_for('App', 1) }, 2,
        'so a revoked key is still listed, which is the audit');
}

{
    # A rotation must not break the deployment that has not picked up the new
    # key yet, so the old one is given a grace period.
    fresh();
    my ($old, $old_row) = $P->issue_for('App', owner => 1, label => 'old',
                                        scopes => ['read']);
    my ($new) = $P->issue_for('App', owner => 1, label => 'new',
                              scopes => ['read'], replaces => $old_row->{id});

    is(hit('/api/any', key => $new)->{status}, 200, 'the new key works');
    is(hit('/api/any', key => $old)->{status}, 200,
        'and so does the old one, for its grace period');

    my ($row) = grep { $_->{id} == $old_row->{id} }
                     @{ TFake::KeyBackend->keys_rows };
    cmp_ok($row->{expires}, '>', time, 'which is an expiry in the future');
    cmp_ok($row->{expires}, '<=', time + 3600, 'of the configured length');
}

# ---- issue refuses what it should --------------------------------------------

{
    fresh();
    my $err = '';
    eval { $P->issue_for('App', owner => 1, scopes => ['wrte']) } or $err = $@;
    like($err, qr/scope 'wrte' is not in the vocabulary/,
        'issuing a scope outside the vocabulary croaks');

    $err = '';
    eval { $P->issue_for('App', owner => 1, kind => 'sandbox') } or $err = $@;
    like($err, qr/no kind 'sandbox'/, 'and so does an unknown kind');

    $err = '';
    eval { $P->issue_for('App', label => 'no owner') } or $err = $@;
    like($err, qr/issue needs an owner/, 'and an issue with no owner');

    $err = '';
    eval { $P->issue_for('App', owner => 1, lable => 'typo') } or $err = $@;
    like($err, qr/unknown issue option 'lable'/, 'and a mistyped option');
}

# ---- which kind an issue gets when it does not say ---------------------------

{
    # NOT "the first declared": kinds are a hash, and hash order is not an
    # order. Minting a `test` key because the iterator felt like it - and
    # having it work everywhere a live one does, since what a kind MEANS is
    # the application's business - is a bug that is found late.
    fresh();
    my ($k) = $P->issue_for('App', owner => 1, label => 'default');
    like($k, qr/\Ask_live_/, 'with no kind given, `live` is what is minted');

    for (1 .. 20) {
        my ($again) = $P->issue_for('App', owner => 1, label => 'again');
        like($again, qr/\Ask_live_/, 'every time') if $_ == 20;
    }
}

{
    package App::OneKind;
    use Punk;
    database backend => 'TFake::KeyBackend';
    model 'TFake::Model::ApiKey';
    plugin 'APIKey' => { model => 'TFake::Model::ApiKey', owner => 'owner_id',
                         prefix => 'ak_', scopes => ['read'] };
}
{
    App::OneKind->to_app;      # model_instance needs the compiled registry
    my ($k) = $P->issue_for('App::OneKind', owner => 1, label => 'only');
    like($k, qr/\Aak_/, 'a single unnamed kind is the default by being alone');
}

{
    package App::NoLive;
    use Punk;
    database backend => 'TFake::KeyBackend';
    model 'TFake::Model::ApiKey';
    plugin 'APIKey' => { model => 'TFake::Model::ApiKey', owner => 'owner_id',
                         kinds => { alpha => 'a_', beta => 'b_' },
                         scopes => ['read'] };
}
{
    App::NoLive->to_app;
    my $err = '';
    eval { $P->issue_for('App::NoLive', owner => 1, label => 'x') } or $err = $@;
    like($err, qr/which kind\? there is no `live` to default to/,
        'with two kinds and no `live`, an issue must name one rather than '
      . 'have the answer chosen by hash order');
    like($err, qr/alpha, beta/, 'listing them');

    my ($k) = $P->issue_for('App::NoLive', owner => 1, label => 'x',
                            kind => 'beta');
    like($k, qr/\Ab_/, 'and naming one works');
}

# ---- the kinds overlap check -------------------------------------------------

{
    # One prefix being a prefix of another would leave match order as the only
    # thing telling two credentials apart, and match order is a rule nobody
    # can see. Refused at boot.
    my $err = '';
    eval q{
        package App::Overlap;
        use Punk;
        database backend => 'TFake::KeyBackend';
        model 'TFake::Model::ApiKey';
        plugin 'APIKey' => { model => 'TFake::Model::ApiKey',
                             kinds => { live => 'sk_', test => 'sk_test_' },
                             scopes => ['read'] };
        1;
    } or $err = $@;
    like($err, qr/kinds '\w+' and '\w+' overlap/,
        'overlapping prefixes are refused at boot');
    like($err, qr/one prefix is a prefix of the other/, 'saying why');
}

{
    my $err = '';
    eval q{
        package App::Both;
        use Punk;
        database backend => 'TFake::KeyBackend';
        model 'TFake::Model::ApiKey';
        plugin 'APIKey' => { model => 'TFake::Model::ApiKey',
                             kinds => { live => 'sk_' }, prefix => 'x_',
                             scopes => ['read'] };
        1;
    } or $err = $@;
    like($err, qr/give kinds or prefix, not both/,
        'two ways to say one thing is refused');
}

# ---- last_used ---------------------------------------------------------------

{
    fresh();
    my ($k, $r) = $P->issue_for('App', owner => 1, label => 'u',
                                scopes => ['read']);
    hit('/api/any', key => $k);

    my ($row) = grep { $_->{id} == $r->{id} } @{ TFake::KeyBackend->keys_rows };
    ok($row->{last_used}, 'a passing request stamps last_used');

    my $first = $row->{last_used};
    hit('/api/any', key => $k) for 1 .. 3;
    ($row) = grep { $_->{id} == $r->{id} } @{ TFake::KeyBackend->keys_rows };
    is($row->{last_used}, $first,
        'and does not stamp it again inside a minute - "is anyone still '
      . 'using this key" does not need second precision');

    $row->{last_used} = time - 120;
    hit('/api/any', key => $k);
    ($row) = grep { $_->{id} == $r->{id} } @{ TFake::KeyBackend->keys_rows };
    cmp_ok($row->{last_used}, '>', time - 10, 'but does once a minute has passed');
}

# ---- the per-key rate limit --------------------------------------------------

{
    # A test has no Hyperman arena, so rate_hit is replaced on the context
    # subclass - which is also how an application would find out that the
    # limiter fails open when the arena is absent.
    fresh();
    my ($k, $r) = $P->issue_for('App', owner => 1, label => 'limited',
                                scopes => ['read'], rate_per_min => 2);

    my $ctx = 'App::_Context';
    my @asked;
    my $reset = time + 30;
    no strict 'refs';
    no warnings 'redefine';
    local *{"${ctx}::rate_hit"} = sub {
        my ($c, $key, $limit, $window) = @_;
        push @asked, [ $key, $limit, $window ];
        return (scalar @asked <= 2 ? 1 : 0, 0, $reset);
    };
    use strict 'refs';

    is(hit('/api/any', key => $k)->{status}, 200, 'under the limit');
    is(hit('/api/any', key => $k)->{status}, 200, 'still under');

    my $over = hit('/api/any', key => $k);
    is($over->{status}, 429, 'over the limit is a 429');
    is($over->{headers}{'Content-Type'}, 'application/problem+json',
        'in the limiter\'s shape, not this plugin\'s - a client that handles '
      . 'rate_limit\'s 429 must handle this one identically');
    ok($over->{headers}{'Retry-After'}, 'with Retry-After');
    is($over->{headers}{'X-RateLimit-Limit'}, 2, 'and the limit');
    is($over->{headers}{'X-RateLimit-Remaining'}, 0, 'and what is left');

    is($asked[0][0], 'apikey:' . $r->{id},
        'the counter is keyed by ROW ID and never by the credential - '
      . 'rate_limit counters live in shared memory under their key name');
    is($asked[0][1], 2, 'with the row\'s limit');
    is($asked[0][2], 60, 'over a minute');
}

{
    # A key with no rate_per_min asks the limiter nothing at all.
    fresh();
    my ($k) = $P->issue_for('App', owner => 1, label => 'free',
                            scopes => ['read']);
    my $ctx = 'App::_Context';
    my $asked = 0;
    no strict 'refs';
    no warnings 'redefine';
    local *{"${ctx}::rate_hit"} = sub { $asked++; return (1, 99, time + 60) };
    use strict 'refs';

    is(hit('/api/any', key => $k)->{status}, 200, 'an unlimited key passes');
    is($asked, 0, 'and costs no arena hit');
}

# ---- the OpenAPI checker form ------------------------------------------------

sub check_with {
    my ($checker, $cred) = @_;
    local $App::CHECKER = $checker;
    local $App::CRED    = $cred;
    $App::OUT = undef;
    hit('/checker');
    return $App::OUT;
}

{
    fresh();
    my ($read)  = $P->issue_for('App', owner => 1, label => 'r',
                                scopes => ['read']);
    my ($write) = $P->issue_for('App', owner => 1, label => 'w',
                                scopes => ['write']);

    my $checker = $P->_checker_for($P->state_for('App'), 'write');

    # A scope miss returns FALSE, not a 403 triplet. punk_oa_security_cb
    # stores anything truthy as the authorisation, so a triplet returned here
    # would AUTHORISE the request - which is the whole reason the two forms
    # differ, and the POD says so.
    ok(!check_with($checker, $read),
        'the checker returns false for a scope miss, never a triplet');

    my $out = check_with($checker, $write);
    ok($out, 'and something true when the scope is held');
    is(ref $out, 'HASH', 'which is the auth hash');
    is($out->{owner}, 1, 'with the owner');
    is($out->{kind}, 'live', 'and the kind');

    ok(!check_with($checker, 'sk_live_rubbish'),
        'a malformed credential is false');
    ok(!check_with($checker, undef), 'and so is none at all');
    ok(!check_with($checker, $P->_mint('sk_live_')),
        'and so is a well-formed key nobody issued');

    # A suspended owner is false here too - the mount turns it into a 401,
    # which is the one thing the checker form cannot say differently.
    $_->{suspended} = time for grep { $_->{id} == 1 }
                                    @{ TFake::KeyBackend->users_rows };
    $P->forget_owners('App');
    ok(!check_with($checker, $write),
        'a suspended owner is false, and the mount answers 401');
}

done_testing();
