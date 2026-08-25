use strict;
use warnings;
use Test::More;
BEGIN { do './t/sibling.pl' }

BEGIN {
    plan skip_all => 'Punk 0.22+ required for the plugin tests'
        unless eval { require Punk; Punk->VERSION('0.22'); 1 };
}

# The plugin against a real Punk application: registration, the
# helpers, the counter write-back, and the equal-work rule for
# accounts without a secret.

# ---- an in-memory backend implementing the six-method contract -------------
{
    package T::Backend::Memory;
    my %ROWS;
    sub _rows { \%ROWS }
    sub new    { my ($class, %a) = @_; bless { table => $a{table} }, $class }
    sub get    { my ($self, %k) = @_; $ROWS{ $k{id} } }
    sub search { return { rows => [ values %ROWS ],
                          has_more_data => 0, next => undef } }
    sub all    { $_[0]->search({}, {}) }
    sub create { my ($self, $d) = @_; $ROWS{ $d->{id} } = { %$d }; $d }
    sub update {
        my ($self, $d) = @_;
        my $row = $ROWS{ $d->{id} } ||= {};
        @{$row}{ keys %$d } = values %$d;
        return { %$row };
    }
    sub delete { my ($self, %k) = @_; delete $ROWS{ $k{id} } ? 1 : 0 }
}

{
    package T::Model::User;
    use Punk::Model;
    table 'users';
    field id => { type => 'integer', primary => 1 };
}

# ---- the application -------------------------------------------------------
my ($app, $verify, $secret_helper, $uri_helper, $qr_helper);
{
    package T;
    use Punk;

    session secret => 'x' x 32;
    database backend => 'T::Backend::Memory';
    model 'User';
    plugin 'TOTP' => { issuer => 'test.example' };

    get '/probe' => sub {
        my ($c) = @_;
        # capture bound helpers for direct exercise below
        $verify        = sub { $c->totp_verify(@_) };
        $secret_helper = sub { $c->totp_secret };
        $uri_helper    = sub { $c->totp_uri(@_) };
        $qr_helper     = sub { $c->totp_qr(@_) };
        return $c->text('ok');
    };
}

require Punk::Test;
my $t = Punk::Test->new('T');
$t->get_ok('/probe');

# ---- config police ---------------------------------------------------------
{
    my $err = do {
        local $@;
        eval { Punk::Plugin::TOTP->register(T::punk_app(), {}) };
        $@;
    };
    like $err, qr/already registered/, 'double registration croaks';

    like +Punk::Plugin::TOTP::state_for('T')->{issuer},
        qr/test\.example/, 'config frozen under the app class';

    my $cfg = Punk::Plugin::TOTP::state_for('T');
    is $cfg->{attempts}, 5, 'attempts defaults to 5';
    is $cfg->{attempt_window}, 900, 'attempt_window defaults to 900';
    is $cfg->{fields}{failed}, 'totp_failed',
        'the attempt count has a default column';
    is $cfg->{fields}{failed_at}, 'totp_failed_at',
        'and so does the epoch that dates it';
}

# both of these fail in a direction that is hard to spot from the outside: no
# attempts locks every account out for good, and no window means every failure
# has already lapsed, which is a limit that never counts
{
    package BadAttempts;
    use Punk;
    session secret => 'x' x 32;
    package BadWindow;
    use Punk;
    session secret => 'x' x 32;
    package main;

    my %bad = (
        BadAttempts => [ attempts       => 0, qr/attempts must be 1 or more/ ],
        BadWindow   => [ attempt_window => 0,
                         qr/attempt_window must be 1 second or more/ ],
    );
    for my $app (sort keys %bad) {
        my ($k, $val, $re) = @{ $bad{$app} };
        my $err = do {
            local $@;
            eval { $app->punk_app->plugin('TOTP',
                       { issuer => 'x', $k => $val }) };
            $@;
        };
        like $err, $re, "$k => $val croaks at boot";
    }
}

# ---- the helpers -----------------------------------------------------------
my $secret = $secret_helper->();
is length(Punk::TOTP->b32_decode($secret)), 20,
    'totp_secret is a 20-byte sha1 secret';

my $uri = $uri_helper->($secret, account => 'alice@example.com');
like $uri, qr{^otpauth://totp/test\.example:alice%40example\.com\?},
    'totp_uri carries the configured issuer';
unlike $uri, qr/algorithm=/, 'defaults omitted';

{
    my $svg = $qr_helper->($secret, account => 'alice@example.com');
    like $svg, qr/^<svg /, 'totp_qr renders SVG';
    like $svg, qr/viewBox/, 'with a viewBox';
}

# ---- verify + the counter write-back ---------------------------------------
my $now  = time;
my $code = Punk::TOTP->code($secret, time => $now);
T::Backend::Memory::_rows()->{7} =
    { id => 7, totp_secret => $secret, totp_enabled => 1 };

{
    my $user = { %{ T::Backend::Memory::_rows()->{7} } };
    ok $verify->($user, $code), 'a fresh code verifies';

    my $stored = T::Backend::Memory::_rows()->{7};
    ok defined $stored->{totp_last_counter},
        'the matched counter was written through the model';
    is $stored->{totp_last_counter}, int($now / 30),
        'and names the step the code belongs to';
    is $user->{totp_last_counter}, $stored->{totp_last_counter},
        'the in-hand user hashref was advanced too';

    ok !$verify->($user, $code),
        'the identical code refuses on the second submission';
    ok !$verify->({ %$stored }, $code),
        'and refuses for a freshly loaded row - the floor is stored, '
      . 'not remembered';
}

# ---- equal work without a secret -------------------------------------------
{
    my $bare = { id => 8 };
    ok !$verify->($bare, $code), 'no secret refuses';
    ok !exists $bare->{totp_last_counter}, 'and writes nothing';
    ok !$verify->($bare, ''), 'empty code refuses without croaking';
}

done_testing;
