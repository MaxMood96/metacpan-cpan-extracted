#!perl
use 5.010;
use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/lib";
use Test::More;
use PPKTest qw(fixture b64u_decode b64u_encode auth_data);

BEGIN {
    plan skip_all => 'Punk 0.31+ is needed to mount the plugin'
        unless eval { require Punk; Punk->VERSION('0.31'); 1 };
    plan skip_all => 'Punk::Test is needed to drive the routes'
        unless eval { require Punk::Test; require Punk::Model; 1 };
}
use Punk::Passkey ();
use Punk::Plugin::Passkey ();
use File::Raw::JSON qw(file_json_decode file_json_encode);

# `plugin 'Passkey'` end to end: the routes it mounts, driven through
# Punk::Test against the same captured fixtures the ceremonies were
# tested with in phases 1 and 2.
#
# Testing here rather than trusting those phases is worth it because
# everything BETWEEN the request and the ceremony is new - who the
# current user is, which model the credential lands in, what a refusal
# looks like on the wire, and whether the last credential can be
# removed.

# ---- a backend, in memory ---------------------------------------------------
# The plugin reaches storage through $c->model($name) and the six-method
# contract, so this is a real Punk::Model over a real registry with the
# database swapped for a hash. What is under test is the plugin's use of
# the contract, not a database driver.

our @ROWS;
our $SEQ = 0;
{
    package PPKMem;
    sub new { my ($c, %a) = @_; bless { primary => $a{primary} || 'id' }, $c }
    sub get {
        my ($s, %k) = @_;
        for my $r (@main::ROWS) {
            my $hit = 1;
            for my $f (keys %k) { $hit = 0 if ($r->{$f} // '') ne ($k{$f} // '') }
            return { %$r } if $hit;
        }
        return undef;
    }
    sub search {
        my ($s, $filter, $opts) = @_;
        $filter ||= {};
        my @rows = grep {
            my $r = $_;
            !grep { ($r->{$_} // '') ne ($filter->{$_} // '') } keys %$filter
        } @main::ROWS;
        return { rows => [ map { +{ %$_ } } @rows ],
                 has_more_data => 0, next => undef };
    }
    sub all   { $_[0]->search({}, {}) }
    sub count { scalar @{ $_[0]->search($_[1], {})->{rows} } }
    sub create {
        my ($s, $data) = @_;
        # the unique constraint the real schema carries, in miniature
        for my $r (@main::ROWS) {
            return undef if ($r->{credential_id} // '')
                         eq ($data->{credential_id} // '');
        }
        my $row = { %$data, id => ++$main::SEQ };
        push @main::ROWS, $row;
        return { %$row };
    }
    sub update {
        my ($s, $data) = @_;
        for my $r (@main::ROWS) {
            next unless ($r->{id} // '') eq ($data->{id} // '');
            %$r = (%$r, %$data);
            return { %$r };
        }
        return undef;
    }
    sub delete {
        my ($s, %k) = @_;
        my $before = @main::ROWS;
        @main::ROWS = grep {
            my $r = $_;
            grep { ($r->{$_} // '') ne ($k{$_} // '') } keys %k
        } @main::ROWS;
        return $before - @main::ROWS;
    }
}

our $USER  = 42;
our $OTHER = 0;
our @SIGNED;
our @CLONES;
our $reg_challenge;
our $auth_challenge;

{
    package PKApp::Model::Passkey;
    use Punk::Model;
    table 'passkeys';
    field id => { type => 'integer', primary => 1 };
}

{
    package PKApp;
    use Punk;
    session secret => 'plugin-test-secret';
    host 'https://webauthn.io';
    database backend => 'PPKMem';
    model 'Passkey';

    helper sign_in => sub {
        my ($c, $uid) = @_;
        push @SIGNED, $uid;
        $c->session->{user_id} = $uid;
        return $c->json({ signed_in => $uid });
    };

    # The captured ceremonies answered challenges of their own, so the
    # session has to hold those. The plugin reads the session like any
    # other Punk code, so a route that writes it is enough - and this is
    # the only thing arranged anywhere in this file.
    post '/t/seed-reg' => sub {
        my ($c) = @_;
        $c->session->{'punk.passkey.reg'} =
            { c => $main::reg_challenge, exp => time + 300 };
        $c->text('ok');
    };
    post '/t/seed-auth' => sub {
        my ($c) = @_;
        $c->session->{'punk.passkey.auth'} =
            { c => $main::auth_challenge, exp => time + 300 };
        $c->text('ok');
    };

    plugin 'Passkey' => {
        user_id          => sub { $USER },
        has_other_factor => sub { $OTHER },
        on_clone_signal  => sub { push @CLONES, [ @_[1, 2] ] },
        credentials_for  => sub {
            my ($c, $username) = @_;
            return [] unless $username eq 'ada';
            return [ map { $_->{credential_id} } @main::ROWS ];
        },
    };
}

my $t = Punk::Test->new('PKApp');

# ---- what it mounted ---------------------------------------------------------

{
    my $cfg = Punk::Plugin::Passkey::state_for('PKApp');
    ok($cfg, 'the plugin froze a configuration for the class');
    is($cfg->{register_path}, '/account/passkeys', 'the default register path');
    is($cfg->{login_path},    '/login/passkey',    'the default login path');
    is($cfg->{asset_path},    '/punk-passkey.js',  'and asset path');
    is($cfg->{model},         'Passkey',           'the default model name');
    is($cfg->{user_verification}, 'preferred', 'user verification preferred');
}

# ---- the browser helper ------------------------------------------------------

{
    $t->get_ok('/punk-passkey.js')->status_is(200);
    my $js = $t->body;
    like($t->header('Content-Type'), qr{javascript}, 'served as JavaScript');
    like($t->header('ETag'), qr/\A"[A-Za-z0-9_-]+"\z/, 'with a strong ETag');

    unlike($js, qr{https?://}i,
        'the asset references NO external origin - an application with a '
      . 'Content-Security-Policy must not have to widen it to let sign-in '
      . 'work, and a login page is the last place to invite a third party');
    like($js, qr/w\.PunkPasskey|window\.PunkPasskey/, 'it defines PunkPasskey');
    like($js, qr/isConditionalMediationAvailable/,
        'and feature-detects conditional UI rather than assuming it - a '
      . 'browser without it shows the button instead of breaking');
    is($js, Punk::Plugin::Passkey::_asset(),
        'the bytes served are the bytes compiled in');

    my $etag = $t->header('ETag');
    $t->get_ok('/punk-passkey.js', headers => { 'If-None-Match' => $etag })
      ->status_is(304, 'a matching If-None-Match is answered 304')
      ->content_is('', '...with no body, so revalidating is nearly free');

    # The header that matters more than it looks. A long max-age here
    # means a browser does not ASK for an hour, so an upgrade that fixes
    # the sign-in script reaches nobody who has already loaded the page
    # - which is not hypothetical, it is how the conditional-UI fix
    # failed to reach a user. `no-cache` stores it and revalidates,
    # which the ETag above makes cheap.
    is($t->header('Cache-Control'), 'no-cache',
        'the asset is revalidated rather than held - this URL is stable '
      . 'across versions, so a stale copy is a stale copy for ever');
}

# ---- registration through the routes -----------------------------------------

my $reg    = fixture('reg-none.txt');
my $reg_cd = file_json_decode(b64u_decode($reg->{clientDataJSON}));
$reg_challenge = $reg_cd->{challenge};

sub post_json {
    my ($path, $data) = @_;
    return $t->post_ok($path, body => file_json_encode($data),
                       type => 'application/json');
}

{
    @ROWS = ();
    $t->post_ok('/account/passkeys/options')->status_is(200);
    my $o = $t->json;
    is($o->{rp}{id}, 'webauthn.io', 'the options carry the declared rpId');
    is(b64u_decode($o->{user}{id}), '42', 'and the current user');
    is_deeply($o->{excludeCredentials}, [],
        'with nothing to exclude for a user who has no credentials yet');
}

{
    @ROWS = ();
    $t->post_ok('/t/seed-reg')->status_is(200);
    post_json('/account/passkeys', {
        clientDataJSON    => $reg->{clientDataJSON},
        attestationObject => $reg->{attestationObject},
        label             => 'my laptop',
    })->status_is(200, 'a real captured registration is accepted by the route');
    ok($t->json->{ok}, 'and reports success');

    is(scalar @ROWS, 1, 'one credential was stored');
    is($ROWS[0]{user_id}, 42, 'against the current user');
    is($ROWS[0]{label}, 'my laptop', 'with the label the client sent');
    ok(length $ROWS[0]{public_key} > 40, 'and the COSE key, as it arrived');
    ok(defined $ROWS[0]{created_at}, 'stamped');
}

{   # the options now exclude what the user has
    $t->post_ok('/account/passkeys/options')->status_is(200);
    is(scalar @{ $t->json->{excludeCredentials} }, 1,
        'the ids the user already has are offered for exclusion, so the '
      . 'platform refuses a repeat in its own UI rather than letting it '
      . 'reach the unique constraint');
}

{   # the same credential again
    $t->post_ok('/t/seed-reg');
    post_json('/account/passkeys', {
        clientDataJSON    => $reg->{clientDataJSON},
        attestationObject => $reg->{attestationObject},
    })->status_is(409, 'a credential already registered is refused');
    is(scalar @ROWS, 1, 'and nothing was stored twice');
}

{   # a nonsense body
    $t->post_ok('/t/seed-reg');
    post_json('/account/passkeys',
        { clientDataJSON => 'x', attestationObject => 'y' })
      ->status_is(400, 'a nonsense registration is refused');
    like($t->json->{error}, qr/registration failed/,
        '...with a message that names no check');
    unlike($t->json->{error}, qr/challenge|origin|rpId|signature/i,
        'the wire answer does not say WHICH check failed');
}

# ---- the management page -----------------------------------------------------

{
    @ROWS = ({ id => 1, user_id => 42, credential_id => 'x',
               label => 'my laptop' });
    $t->get_ok('/account/passkeys')->status_is(200);
    like($t->body, qr/Your passkeys/, 'the built-in page renders');
    like($t->body, qr/my laptop/, 'listing the stored credential');
    like($t->header('Cache-Control'), qr/no-store/,
        'and is not cached - a list of one person\'s devices is not a page '
      . 'a shared cache should keep');
    like($t->body, qr{src="/punk-passkey\.js"}, 'it loads the helper');
}

{   # the label is the one thing on the page a user typed
    @ROWS = ({ id => 1, user_id => 42, credential_id => 'x',
               label => '<script>alert(1)</script>' });
    $t->get_ok('/account/passkeys')->status_is(200);
    unlike($t->body, qr/<script>alert/, 'a label is HTML-escaped');
    like($t->body, qr/&lt;script&gt;/, '...entity-encoded');
}

# ---- authentication through the routes ---------------------------------------

my $auth    = fixture('auth-webauthn-io.txt');
my $auth_cd = file_json_decode(b64u_decode($auth->{clientDataJSON}));
my $auth_ad = auth_data(b64u_decode($auth->{authenticatorData}));
$auth_challenge = $auth_cd->{challenge};
my $auth_id = b64u_encode($auth_ad->{credentialId});

sub stored_credential {
    return { id => 1, user_id => 42, credential_id => $auth_id,
             public_key => $auth_ad->{cose}, sign_count => 0 };
}

{
    @ROWS = (stored_credential());
    @SIGNED = ();

    $t->post_ok('/login/passkey/options')->status_is(200);
    my $o = $t->json;
    is($o->{rpId}, 'webauthn.io', 'the login options carry the rpId');
    ok(!exists $o->{allowCredentials},
        'and no allowCredentials for the usernameless flow');

    $t->post_ok('/t/seed-auth');
    post_json('/login/passkey', {
        id                => $auth_id,
        clientDataJSON    => $auth->{clientDataJSON},
        authenticatorData => $auth->{authenticatorData},
        signature         => $auth->{signature},
    })->status_is(200, 'a real captured assertion signs in through the route');

    is_deeply(\@SIGNED, [42],
        'and it handed off to the application\'s sign_in rather than '
      . 'deciding for itself what logging in means');
    is($t->json->{signed_in}, 42, 'the response is sign_in\'s own');
    is($ROWS[0]{sign_count}, 1553097241,
        'the sign count was recorded through the model');
    ok(defined $ROWS[0]{last_used_at}, 'and the last-used stamp');
}

{   # a username narrows the list, without reporting who exists
    $t->post_ok('/login/passkey/options', body => file_json_encode({
        username => 'ada' }), type => 'application/json')->status_is(200);
    is(scalar @{ $t->json->{allowCredentials} || [] }, 1,
        'a known username produces that user\'s credentials');

    $t->post_ok('/login/passkey/options', body => file_json_encode({
        username => 'nobody' }), type => 'application/json')->status_is(200);
    ok(!exists $t->json->{allowCredentials},
        'an unknown one produces no list rather than an error - this '
      . 'endpoint does not report who has an account');
}

{   # every login failure is one answer
    @SIGNED = ();
    $t->post_ok('/t/seed-auth');
    post_json('/login/passkey', {
        id                => 'no-such-credential',
        clientDataJSON    => $auth->{clientDataJSON},
        authenticatorData => $auth->{authenticatorData},
        signature         => $auth->{signature},
    })->status_is(401, 'an unknown credential is refused');
    is($t->json->{error}, 'authentication failed',
        '...with the same message every other failure gets');
    is_deeply(\@SIGNED, [], 'and nothing was signed in');

    my $unknown = $t->body;

    @ROWS = (stored_credential());
    $t->post_ok('/t/seed-auth');
    my $bad = b64u_decode($auth->{signature});
    substr($bad, -1, 1) = chr(ord(substr($bad, -1, 1)) ^ 0xff);
    post_json('/login/passkey', {
        id                => $auth_id,
        clientDataJSON    => $auth->{clientDataJSON},
        authenticatorData => $auth->{authenticatorData},
        signature         => b64u_encode($bad),
    })->status_is(401, 'a bad signature is refused');
    is($t->body, $unknown,
        'byte-identically to an unknown credential - only the log tells '
      . 'them apart, because otherwise this endpoint is an oracle for '
      . 'which authenticators the site knows');
}

{   # the clone signal reaches the application through the plugin
    @ROWS = (stored_credential());
    $ROWS[0]{sign_count} = 2_000_000_000;
    @CLONES = ();
    @SIGNED = ();
    $t->post_ok('/t/seed-auth');
    post_json('/login/passkey', {
        id                => $auth_id,
        clientDataJSON    => $auth->{clientDataJSON},
        authenticatorData => $auth->{authenticatorData},
        signature         => $auth->{signature},
    })->status_is(200,
        'a sign count that went backwards STILL signs in through the route');
    is_deeply(\@SIGNED, [42], '...reaching sign_in');
    is_deeply($CLONES[0], [2_000_000_000, 1553097241],
        'while on_clone_signal is handed both counts, so an operator who '
      . 'wants to force re-enrolment can');
}

# ---- removing a credential ---------------------------------------------------

{
    @ROWS = ({ id => 1, user_id => 42, credential_id => 'only-one' });
    $OTHER = 0;
    $t->delete_ok('/account/passkeys/only-one')
      ->status_is(409, 'the last passkey cannot be removed');
    like($t->json->{error}, qr/last passkey/,
        '...saying why, because this refusal is protecting the account '
      . 'rather than reporting an error');
    is(scalar @ROWS, 1, 'and it is still there');
}

{
    @ROWS = ({ id => 1, user_id => 42, credential_id => 'only-one' });
    $OTHER = 1;                        # the application says TOTP is on
    $t->delete_ok('/account/passkeys/only-one')->status_is(200);
    is(scalar @ROWS, 0,
        'the last passkey IS removable when another factor exists - which '
      . 'is knowledge the application has and this plugin does not');
}

{
    @ROWS = ({ id => 1, user_id => 42, credential_id => 'a' },
             { id => 2, user_id => 42, credential_id => 'b' });
    $OTHER = 0;
    $t->delete_ok('/account/passkeys/a')->status_is(200);
    is(scalar @ROWS, 1, 'with two, either may go');
    is($ROWS[0]{credential_id}, 'b', 'and the right one went');
}

{
    @ROWS = ({ id => 1, user_id => 99, credential_id => 'theirs' },
             { id => 2, user_id => 42, credential_id => 'mine' },
             { id => 3, user_id => 42, credential_id => 'mine2' });
    $OTHER = 1;
    $t->delete_ok('/account/passkeys/theirs')->status_is(200);
    is(scalar(grep { $_->{credential_id} eq 'theirs' } @ROWS), 1,
        'a credential belonging to another account is untouched - the '
      . 'delete is scoped to the signed-in user, because a credential id '
      . 'is an identifier and not a capability');
}

# ---- not signed in -----------------------------------------------------------

{
    local $USER = undef;
    $t->get_ok('/account/passkeys')
      ->status_is(401, 'the management page refuses when nobody is signed in');
    $t->post_ok('/account/passkeys/options')
      ->status_is(401, '...as do the options');
    post_json('/account/passkeys', {})->status_is(401, '...and registration');
    $t->delete_ok('/account/passkeys/x')->status_is(401, '...and deletion');
}

# ---- what fails at boot ------------------------------------------------------

{
    my $err = do { local $@; eval {
        package BadOpt;
        use Punk;
        session secret => 'x';
        host 'https://example.com';
        plugin 'Passkey' => { nonsense => 1 };
    }; $@ };
    like($err, qr/unknown Passkey plugin option 'nonsense'/,
        'an unknown option croaks at the keyword, naming it');
}

{
    my $err = do { local $@; eval {
        package BadUV;
        use Punk;
        session secret => 'x';
        host 'https://example.com';
        plugin 'Passkey' => { user_verification => 'sometimes' };
    }; $@ };
    like($err, qr/user_verification must be/, 'an invalid preference croaks');
}

{
    my $err = do { local $@; eval {
        package BadCode;
        use Punk;
        session secret => 'x';
        host 'https://example.com';
        plugin 'Passkey' => { has_other_factor => 'not a coderef' };
    }; $@ };
    like($err, qr/has_other_factor must be a coderef/,
        'a coderef option given something else croaks, so a typo is a boot '
      . 'error rather than a callback that silently never fires');
}

{
    my $err = do { local $@; eval {
        package NoSession;
        use Punk;
        host 'https://example.com';
        plugin 'Passkey';
        NoSession->to_app;
    }; $@ };
    like($err, qr/needs the `session` keyword/,
        'no session croaks at to_app, naming what to add');
}

{
    my $err = do { local $@; eval {
        package NoHost;
        use Punk;
        session secret => 'x';
        plugin 'Passkey';
        NoHost->to_app;
    }; $@ };
    like($err, qr/needs the `host` keyword/,
        'and no host croaks too - the origin check is the whole scheme, so '
      . 'it is not something to default');
}

# ---- inert without the plugin ------------------------------------------------

{
    package NoPlugin;
    use Punk;
    session secret => 'x';
    host 'https://example.com';
    get '/' => sub { $_[0]->text('plain') };
    package main;
    my $n = Punk::Test->new('NoPlugin');
    $n->get_ok('/')->status_is(200)->content_is('plain');
    $n->get_ok('/punk-passkey.js')
      ->status_is(404, 'an application without the plugin has none of its routes');
    $n->get_ok('/account/passkeys')->status_is(404, '...none at all');
}

# ---- the render override -----------------------------------------------------

{
    package Rendered;
    use Punk;
    session secret => 'x';
    host 'https://example.com';
    database backend => 'PPKMem';
    model 'Passkey';
    plugin 'Passkey' => {
        user_id => sub { 7 },
        render  => sub {
            my ($c, $rows) = @_;
            $c->text('MY OWN PAGE: ' . scalar(@$rows));
        },
    };
    package Rendered::Model::Passkey;
    use Punk::Model;
    table 'passkeys';
    field id => { type => 'integer', primary => 1 };
    package main;
    @ROWS = ({ id => 1, user_id => 7, credential_id => 'x' });
    my $r = Punk::Test->new('Rendered');
    $r->get_ok('/account/passkeys')->status_is(200)
      ->content_is('MY OWN PAGE: 1',
        'render replaces the built-in page, and is handed the rows');
}

done_testing;
