use strict;
use warnings;
use Test::More;
BEGIN { do './t/sibling.pl' }

BEGIN {
    plan skip_all => 'Punk 0.22+ required for the plugin tests'
        unless eval { require Punk; Punk->VERSION('0.22'); 1 };
}

# The auth seam end to end: a pending session has no identity, the
# challenge route promotes it, repeated failure clears it, and the
# step-up guard demands the factor from sessions that authenticated
# without it.

{
    package T::Backend::Memory;
    my %TABLES;
    my $NEXT = 1;
    sub _rows { $TABLES{ $_[0] } ||= {} }
    sub new    { my ($class, %a) = @_; bless { table => $a{table} }, $class }
    sub get    { my ($self, %k) = @_; _rows($self->{table})->{ $k{id} } }
    sub search {
        my ($self, $filter) = @_;
        my @rows = grep {
            my $row = $_;
            !grep { ($row->{$_} // '') ne ($filter->{$_} // '') }
                 keys %{ $filter || {} };
        } values %{ _rows($self->{table}) };
        return { rows => \@rows, has_more_data => 0, next => undef };
    }
    sub all    { $_[0]->search({}) }
    sub create {
        my ($self, $d) = @_;
        my $row = { %$d };
        $row->{id} //= $NEXT++;
        _rows($self->{table})->{ $row->{id} } = $row;
        return { %$row };
    }
    sub update {
        my ($self, $d) = @_;
        my $row = _rows($self->{table})->{ $d->{id} } ||= {};
        @{$row}{ keys %$d } = values %$d;
        return { %$row };
    }
    sub delete {
        my ($self, %k) = @_;
        delete _rows($self->{table})->{ $k{id} } ? 1 : 0;
    }
}
{
    package T::Model::User;
    use Punk::Model;
    table 'users';
    field id => { type => 'integer', primary => 1 };
}
{
    package T::Model::Token;
    use Punk::Model;
    table 'tokens';
    field id => { type => 'integer', primary => 1 };
}

my $challenge;
{
    package T;
    use Punk;

    session secret => 'x' x 32;
    database backend => 'T::Backend::Memory';
    model 'User';
    model 'Token';
    auth model => 'User';
    plugin 'TOTP' => { issuer => 'test.example', attempts => 3 };

    # the password step's chokepoint, minus the password
    post '/start' => sub {
        my ($c) = @_;
        return $c->totp_challenge({ id => 7 }, to => '/dest');
    };

    my $private = under '/private' => auth_guard();
    $private->get('/x' => sub { $_[0]->text('private ok') });

    my $admin = under '/admin' => totp_guard();
    $admin->get('/x' => sub { $_[0]->text('admin ok') });
}

my $secret = Punk::TOTP->secret;
T::Backend::Memory::_rows('users')->{7} =
    { id => 7, totp_secret => $secret, totp_enabled => 1,
      email => 'seven@example.com' };

require Punk::Test;
my $t = Punk::Test->new('T');

sub code_now { Punk::TOTP->code($secret, time => time) }

# ---- a pending session has no identity -------------------------------------
$t->post_ok('/start');
is $t->status, 302, 'the challenge helper redirects';
is $t->header('Location'), '/login/totp', 'to the challenge route';

$t->get_ok('/private/x');
isnt $t->status, 200,
    'a pending session is refused by a plain auth_guard - the '
  . 'mechanism is the missing key, not a check';

$t->get_ok('/login/totp');
is $t->status, 200, 'the challenge page renders';
like $t->body, qr/one-time-code/, 'with the default form';

# ---- wrong codes, then the clear -------------------------------------------
for my $try (1 .. 2) {
    $t->post_ok('/login/totp', form => { code => '000000' });
    is $t->status, 200, "wrong code $try re-renders";
    like $t->body, qr/did not work/, 'with the error';
}
is T::Backend::Memory::_rows('users')->{7}{totp_failed}, 2,
    'the failures are counted on the user row, not in the session';

$t->post_ok('/login/totp', form => { code => '000000' });
is $t->status, 302, 'the third failure clears the pending state';
is $t->header('Location'), '/login', 'back to the password';

$t->post_ok('/login/totp', form => { code => code_now() });
is $t->header('Location'), '/login',
    'and a correct code after the clear finds no pending - the '
  . 'attacker is back to needing the first factor';

# ---- the count survives a fresh pending marker (CVE-2026-78655) ------------
# Re-running the first factor mints a new marker. When the count lived in
# that marker, that alone handed the guesser another `attempts` tries; the
# same reason a replayed cookie did. The count is the account's, so it does
# not reset, and a correct code is refused while the account is over it.
$t->post_ok('/start');
$t->post_ok('/login/totp', form => { code => code_now() });
is $t->status, 302, 'a fresh marker does not buy more attempts';
is $t->header('Location'), '/login',
    'the account is over the limit and the code is not even judged';

# the window is what releases it, so the lock cannot be held for good
T::Backend::Memory::_rows('users')->{7}{totp_failed_at} = time - 901;

# ---- the pass --------------------------------------------------------------
$t->post_ok('/start');
$t->post_ok('/login/totp', form => { code => code_now() });
is $t->status, 302, 'the code promotes the session';
is $t->header('Location'), '/dest', 'to the stored destination';

$t->get_ok('/private/x');
is $t->status, 200, 'the promoted session has identity';
is $t->body, 'private ok', 'and reaches the guarded route';

$t->get_ok('/admin/x');
is $t->status, 200, 'and satisfies the step-up guard';

# ---- step-up: signed in without the factor ---------------------------------
my $t2 = Punk::Test->new('T');
$t2->login_as(7);
$t2->get_ok('/private/x');
is $t2->status, 200, 'login_as bypasses the factor (documented gap)';

$t2->get_ok('/admin/x');
is $t2->status, 302, 'but the step-up guard is not fooled';
is $t2->header('Location'), '/login/totp', 'and demands the factor';

# the code of THIS window was already spent by the other session's
# pass above - and the replay floor is stored on the row, so it
# refuses across sessions, browsers and workers alike
$t2->post_ok('/login/totp', form => { code => code_now() });
is $t2->status, 200,
    'the code the other session just spent is refused here too - '
  . 'the replay floor crosses sessions';

# the next window arrives (simulated: the floor sits one step back)
T::Backend::Memory::_rows('users')->{7}{totp_last_counter} =
    int(time / 30) - 1;
$t2->post_ok('/login/totp', form => { code => code_now() });
is $t2->status, 302, 'the factor passes in a fresh window';
is $t2->header('Location'), '/admin/x',
    'back to where the guard interrupted';
$t2->get_ok('/admin/x');
is $t2->body, 'admin ok', 'and through';

# ---- expiry ----------------------------------------------------------------
{
    my $t3  = Punk::Test->new('T');
    my $cfg = Punk::Plugin::TOTP::state_for('T');
    local $cfg->{pending_ttl} = 0;      # exp = now; time < exp is false
    $t3->post_ok('/start');
    $t3->get_ok('/login/totp');
    is $t3->header('Location'), '/login',
        'an expired pending is a dead end, not a stuck half-state';
}

# ---- replaying the cookie from before the failures (CVE-2026-78655) --------
# Punk carries the session in a signed cookie unless the application declares
# a store, and an earlier copy of a session stays valid until the expiry
# sealed inside it. A client that keeps the cookie from before its failed
# attempts and presents it again used to get the pending record back with its
# counter, so the limit never fired. The count is not in the cookie now.
{
    my $row = T::Backend::Memory::_rows('users')->{7};
    @{$row}{qw(totp_failed totp_failed_at totp_last_counter)} =
        (0, undef, int(time / 30) - 1);

    my $t5 = Punk::Test->new('T');
    $t5->post_ok('/start');
    my %saved = %{ $t5->{jar} };        # the cookie BEFORE any failure

    for my $try (1 .. 3) {
        $t5->post_ok('/login/totp', form => { code => '000000' });
    }
    is $t5->header('Location'), '/login', 'three failures cleared the pending';
    is $row->{totp_failed}, 3, 'and the account carries the count';

    %{ $t5->{jar} } = %saved;           # replay it

    $t5->post_ok('/login/totp', form => { code => code_now() });
    is $t5->status, 302, 'the replayed cookie does not re-open the challenge';
    is $t5->header('Location'), '/login',
        'a correct code on a replayed pending record is refused - the '
      . 'counter is not in the state the client holds';

    $t5->get_ok('/private/x');
    isnt $t5->status, 200, 'and nothing was signed in';
}

# ---- an unsigned session at the step-up guard ------------------------------
my $t4 = Punk::Test->new('T');
$t4->get_ok('/admin/x');
is $t4->status, 302, 'no identity at the guard redirects';
is $t4->header('Location'), '/login', 'to the password, not the challenge';

done_testing;
