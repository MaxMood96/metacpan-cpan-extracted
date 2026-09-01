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
use Punk::Plugin::Authorisation ();

# Punk::Plugin::Authorisation: the rules are the application's, the machinery
# is the plugin's. What is asserted here is the machinery - that a refusal is
# always false, that the status it produces does not confirm a row exists, and
# that a name nobody defined is a croak rather than a decision.

# ---- the policy package ---------------------------------------------------------
{
    package TPolicy;
    use Punk::Plugin::Authorisation;

    rule 'thing.read'   => sub { 1 };
    rule 'thing.write'  => sub {
        my ($c, $row) = @_;
        return 1 if $row && $row->{owner_id} && $row->{owner_id} == ($c->auth_id // 0);
        return $c->forbidden if $c->rank_at_least('admin');
        return $c->not_yours;
    };
    rule 'thing.admin'  => sub { $_[0]->rank_at_least('admin') };
    rule 'thing.plain'  => sub { 0 };            # a bare false: no reason recorded
    rule 'thing.boom'   => sub { die "rule exploded\n" };
    rule 'doc.edit'     => sub {
        my ($c, $doc) = @_;
        return 1 if $doc->{owner_id} == ($c->auth_id // 0);
        return 1 if $c->granted('doc.edit', $doc->{id});
        return $c->not_yours;
    };
    1;
}

# The ladder belongs to the `auth` keyword, and the plugin reads it through
# Punk 0.31's $app->auth_config. An older Punk cannot be asked, so the ladder
# is passed here instead - which is exactly what the plugin's boot croak tells
# you to do, and it keeps every assertion below running on either.
require Punk::App;
my $FROM_AUTH = Punk::App->can('auth_config') ? 1 : 0;
my @RANK = $FROM_AUTH ? ()
         : (rank  => [qw(member admin owner)],
            roles => sub { my ($c, $u) = @_; $u->{role} });
diag('this Punk has no $app->auth_config: passing rank to the plugin instead')
    unless $FROM_AUTH;

{
    package App;
    use Punk;

    session secret => 'x' x 32;
    auth model => 'TFake::Model::User', rank => [qw(member admin owner)],
         roles => sub { my ($c, $u) = @_; $u->{role} };
    database backend => 'TFake::UserBackend';
    model 'TFake::Model::User';

    plugin 'Authorisation' => { policy => 'TPolicy', @RANK };

    our $AS = 0;                                  # who is signed in, per request
    hook before_dispatch => sub {
        my ($c) = @_;
        $c->session->{user_id} = $AS if $AS;
        return;
    };

    get '/read'  => sub { my ($c) = @_; $c->may('thing.read') ? $c->text('yes') : $c->deny };
    get '/write' => sub {
        my ($c) = @_;
        my $row = { id => 7, owner_id => $c->param('owner') };
        $c->may('thing.write', $row) or return $c->deny;
        return $c->text('wrote');
    };
    get '/admin' => sub { my ($c) = @_; $c->may('thing.admin') or return $c->deny; $c->text('ok') };
    get '/plain' => sub { my ($c) = @_; $c->may('thing.plain', { id => 1 }) or return $c->deny; $c->text('ok') };
    get '/plain-nosubject' => sub { my ($c) = @_; $c->may('thing.plain') or return $c->deny; $c->text('ok') };
    get '/why'   => sub { my ($c) = @_; $c->may('thing.plain') or return $c->deny('go away'); $c->text('ok') };
    get '/boom'  => sub { my ($c) = @_; $c->may('thing.boom') or return $c->deny; $c->text('ok') };
    get '/typo'  => sub { my ($c) = @_; $c->may('thing.raed') or return $c->deny; $c->text('ok') };
    get '/rank-typo' => sub { my ($c) = @_; $c->rank_at_least('supremo') ? $c->text('ok') : $c->deny };
    get '/rank'  => sub { my ($c) = @_; $c->text($c->rank_at_least($c->param('r')) ? 'yes' : 'no') };
}

my $app = App->to_app;

sub hit {
    my ($path, %o) = @_;
    my %env = (
        REQUEST_METHOD => 'GET', PATH_INFO => $path,
        QUERY_STRING => $o{query} // '',
        SERVER_NAME => 'x', SERVER_PORT => 80, HTTP_HOST => 'x',
        'psgi.url_scheme' => 'http',
    );
    $env{HTTP_ACCEPT} = $o{accept} if defined $o{accept};
    local $App::AS = $o{as} // 0;
    my $r = $app->(\%env);
    my %h = @{ $r->[1] };
    return { status => $r->[0], headers => \%h,
             body => join('', map { defined $_ ? $_ : '' } @{ $r->[2] }) };
}
sub fresh {
    TFake::UserBackend->reset_all;
    TFake::UserBackend->set_users(
        { id => 1, email => 'admin@x', role => 'admin',  verified => 1 },
        { id => 2, email => 'bob@x',   role => 'member', verified => 1 },
    );
    return;
}
fresh();

# ---- `rule` ---------------------------------------------------------------------
{
    my $rules = Punk::Plugin::Authorisation->rules_for('TPolicy');
    is_deeply([ sort keys %$rules ],
        [qw(doc.edit thing.admin thing.boom thing.plain thing.read thing.write)],
        'every rule the policy declared, and nothing else');
    my $e = ''; eval { TPolicy::rule('Bad Name' => sub { 1 }) } or $e = $@;
    like($e, qr/'Bad Name' is not an action name/, 'a name Sqitch-style dotted parts refuse croaks');
    $e = ''; eval { TPolicy::rule('thing.read' => sub { 1 }) } or $e = $@;
    like($e, qr/TPolicy defines the rule 'thing.read' twice/, 'a rule defined twice croaks naming the package');
    $e = ''; eval { TPolicy::rule('thing.x') } or $e = $@;
    like($e, qr/rule needs a name and a coderef/, 'a rule with no body croaks');
}

# ---- may: allow, and the two refusals -------------------------------------------
is(hit('/read')->{status}, 200, 'a rule that allows, allows');
{
    my $r = hit('/write', as => 2, query => 'owner=2');
    is($r->{status}, 200, 'the owner may write their own row');
    is($r->{body}, 'wrote', 'and reaches the handler');
}
{
    # bob reaching for someone else's row: 404, because a 403 would confirm it
    my $r = hit('/write', as => 2, query => 'owner=1');
    is($r->{status}, 404, "not yours: 404, so the id is not confirmed");
    like($r->{body}, qr/Not Found/, 'in the house error shape');
}
{
    # the admin may not write it either, but for them it exists: 403
    my $r = hit('/write', as => 1, query => 'owner=2');
    is($r->{status}, 403, 'forbidden: 403 when the row is known to exist');
    like($r->{body}, qr/Forbidden/, 'the house shape again');
}

# ---- THE REGRESSION: no refusal is ever true ------------------------------------
#
# The convention this plugin exists to replace had a rule return -1 for "not
# enough rank", and -1 is true in Perl: `$c->may(...) or return $c->deny`
# would have let every rank refusal through as an allow.
{
    my $r = hit('/admin', as => 2);
    is($r->{status}, 403, 'a rank refusal refuses');
    isnt($r->{body}, 'ok', 'and does NOT reach the handler');
    my $ok = hit('/admin', as => 1);
    is($ok->{status}, 200, 'and an admin passes the same rule');
}

# ---- deny's default when the rule recorded nothing ------------------------------
is(hit('/plain')->{status}, 404,
    'a bare false refusal with a subject is 404 - the safe direction');
is(hit('/plain-nosubject')->{status}, 403,
    'and without a subject it is 403: there is no row whose existence to hide');
{
    my $r = hit('/why');
    is($r->{status}, 403, 'a message does not change the status');
    like($r->{body}, qr/go away/, 'but it is the message');
}

# ---- negotiation ------------------------------------------------------------------
{
    my $r = hit('/plain-nosubject', accept => 'text/html,application/xhtml+xml');
    is($r->{status}, 403, 'a browser gets the same status');
    like($r->{headers}{'Content-Type'}, qr{text/html}, 'as a page');
    like($r->{body}, qr/<h1>403<\/h1>/, 'with the status on it');
    my $j = hit('/plain-nosubject', accept => 'application/json');
    like($j->{headers}{'Content-Type'}, qr{application/json}, 'an API client gets the object');
    my $q0 = hit('/plain-nosubject', accept => 'text/html;q=0,application/json');
    like($q0->{headers}{'Content-Type'}, qr{application/json},
        'text/html at q=0 is not a browser, as auth_guard reads it too');
}

# ---- a name nobody defined croaks, and names the ones that exist -------------------
{
    my $r = hit('/typo');
    is($r->{status}, 500, "a typo'd action is an error, not a decision");
    like($r->{body}, qr/no rule for 'thing\.raed'/, 'naming what was asked for');
    like($r->{body}, qr/have: doc\.edit, thing\.admin/, 'and what exists');
}
{
    my $r = hit('/rank-typo');
    is($r->{status}, 500, 'a rank name that is not on the ladder is an error');
    like($r->{body}, qr/'supremo' is not on the rank ladder \(member, admin, owner\)/,
        'naming the ladder');
}
{
    my $r = hit('/boom');
    is($r->{status}, 500, 'a rule that dies is a 500 - it has not allowed anything');
    like($r->{body}, qr/rule exploded/, 'carrying its own message');
}

# ---- where the ladder came from -------------------------------------------------
is_deeply(Punk::Plugin::Authorisation->state_for('App')->{rank},
    [qw(member admin owner)],
    $FROM_AUTH ? 'the ladder is the auth keyword\'s, read through $app->auth_config'
               : 'the ladder is the one passed to the plugin');

# ---- the ladder --------------------------------------------------------------------
is(hit('/rank', as => 1, query => 'r=member')->{body}, 'yes', 'admin is at least member');
is(hit('/rank', as => 1, query => 'r=admin')->{body},  'yes', 'and at least admin');
is(hit('/rank', as => 1, query => 'r=owner')->{body},  'no',  'and not owner');
is(hit('/rank', as => 2, query => 'r=admin')->{body},  'no',  'a member is not admin');
is(hit('/rank',          query => 'r=member')->{body}, 'no',  'and nobody signed in is nothing');

# ---- the default policy package -------------------------------------------------
# No `policy` option: the rules live in <AppClass>::Authorisation, so an
# application says `plugin 'Authorisation'` and nothing else.
{
    package DefaultApp::Authorisation;
    use Punk::Plugin::Authorisation;
    rule 'by.default' => sub { 1 };
    1;

    package DefaultApp;
    use Punk;
    session secret => 'x' x 32;
    plugin 'Authorisation' => { rank => [] };
    package main;

    my $st = Punk::Plugin::Authorisation->state_for('DefaultApp');
    is($st->{policy}, 'DefaultApp::Authorisation',
        'with no policy option the package is <AppClass>::Authorisation');
    is_deeply([ sort keys %{ $st->{rules} } ], ['by.default'],
        'and its rules are the ones in force');
}

# ---- registration croaks ------------------------------------------------------------
{
    my $e = ''; eval { Punk::Plugin::Authorisation->register(App->punk_app, { nope => 1 }) } or $e = $@;
    like($e, qr/unknown option 'nope' \(known: policy, grants, rank, roles, fields\)/, 'an unknown option');
    $e = ''; eval { Punk::Plugin::Authorisation->register(App->punk_app, { policy => 'No::Such::Policy' }) } or $e = $@;
    like($e, qr/cannot load the policy package No::Such::Policy/, 'a policy that will not load');
    {
        package TEmpty;
        sub _nothing { 1 }
    }
    $e = ''; eval { Punk::Plugin::Authorisation->register(App->punk_app, { policy => 'TEmpty' }) } or $e = $@;
    like($e, qr/TEmpty defines no rules/, 'a policy package with no rules');
}

# ---- no ladder at all is a BOOT croak, not a 500 per request ------------------------
# rank_at_least would otherwise croak on every name it was ever given, which
# is a 500 for something knowable at to_app.
{
    package NoRank::Policy;
    use Punk::Plugin::Authorisation;
    rule 'x.y' => sub { 1 };
    1;
}
{
    my $e = '';
    eval q{
        package NoRankApp;
        use Punk;
        session secret => 'x' x 32;
        plugin 'Authorisation' => { policy => 'NoRank::Policy' };
        1;
    } or $e = $@;
    like($e, qr/no rank ladder/, 'no ladder and none asked for croaks at boot');
    like($e, qr/rank => \[\] for a policy that never calls rank_at_least|rank => \[\]/,
        'naming what to write for a policy that never asks');
}
{
    package NoRankOk;
    use Punk;
    session secret => 'x' x 32;
    plugin 'Authorisation' => { policy => 'NoRank::Policy', rank => [] };
    get '/x' => sub { my ($c) = @_; $c->may('x.y') ? $c->text('ok') : $c->deny };
    package main;
    is_deeply(Punk::Plugin::Authorisation->state_for('NoRankOk')->{rank}, [],
        'rank => [] is how a policy that never asks says so');
}

done_testing();
