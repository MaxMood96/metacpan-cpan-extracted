use strict;
use warnings;
use Test::More;
BEGIN { do './t/sibling.pl' }

BEGIN {
    plan skip_all => 'Punk 0.31+ (on_compile) required for the csrf tests'
        unless eval { require Punk; Punk->VERSION('0.31'); 1 };
}

# The default challenge form and the application's csrf protection. An app
# that enabled `csrf` refuses a tokenless POST, so the plugin's own form must
# carry the token - and must keep carrying a LIVE one across the wrong-code
# re-render, because the tokens are single-use. The demo app used to override
# the challenge page for exactly this hole; this is the test that closes it.

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
    package Tc::Model::User;
    use Punk::Model;
    table 'users';
    field id => { type => 'integer', primary => 1 };
}
{
    package Tc::Model::Token;
    use Punk::Model;
    table 'tokens';
    field id => { type => 'integer', primary => 1 };
}
{
    package Tn::Model::User;
    use Punk::Model;
    table 'users';
    field id => { type => 'integer', primary => 1 };
}
{
    package Tn::Model::Token;
    use Punk::Model;
    table 'tokens';
    field id => { type => 'integer', primary => 1 };
}

# csrf is deliberately declared BELOW the plugin line: the decision is made
# at to_app through on_compile, so registration order must not matter.
{
    package Tc;
    use Punk;

    session secret => 'x' x 32;
    database backend => 'T::Backend::Memory';
    model 'User';
    model 'Token';
    auth model => 'User';
    plugin 'TOTP' => { issuer => 'test.example' };
    csrf exempt => ['/start'];   # the fixture's stand-in password step

    post '/start' => sub { $_[0]->totp_challenge({ id => 7 }, to => '/dest') };
}

my $secret = Punk::TOTP->secret;
T::Backend::Memory::_rows('users')->{7} =
    { id => 7, totp_secret => $secret, totp_enabled => 1,
      email => 'seven@example.com' };

require Punk::Test;
my $t = Punk::Test->new('Tc');

sub code_now { Punk::TOTP->code($secret, time => time) }
sub form_token {
    my ($body) = @_;
    $body =~ /name="_csrf" value="([^"]+)"/ ? $1 : undef;
}

# ---- the form carries the token, and the page is not storable ----------------
$t->post_ok('/start');
is $t->status, 302, 'the challenge helper redirects';

$t->get_ok('/login/totp');
is $t->status, 200, 'the challenge page renders';
like $t->body, qr/one-time-code/, 'the default form';
my $tok = form_token($t->body);
ok $tok, 'and it carries the hidden _csrf field';
is $t->header('Cache-Control'), 'no-store',
    'a token-bearing per-session page is no-store';

# ---- the app's protection holds over the plugin's route ----------------------
$t->post_ok('/login/totp', form => { code => code_now() });
is $t->status, 403, 'a POST without the token is refused, correct code or not';

# ---- the token works, and a wrong code re-renders a LIVE replacement ---------
$t->post_ok('/login/totp', form => { code => '000000', _csrf => $tok });
is $t->status, 200, 'a tokened wrong code reaches the handler and re-renders';
like $t->body, qr/did not work/, 'with the error';
my $tok2 = form_token($t->body);
ok $tok2, 'the re-render carries a token';
isnt $tok2, $tok, 'a fresh one - the first was spent';

$t->post_ok('/login/totp', form => { code => code_now(), _csrf => $tok2 });
is $t->status, 302, 'and the fresh token plus a correct code promotes';
is $t->header('Location'), '/dest', 'to the stored destination';

# a spent token does not come back
$t->post_ok('/start');
$t->get_ok('/login/totp');
my $tok3 = form_token($t->body);
$t->post_ok('/login/totp', form => { code => code_now(), _csrf => $tok });
is $t->status, 403, 'an old token from an earlier render stays spent';

# ---- without `csrf` the form is exactly what it always was -------------------
{
    package Tn;
    use Punk;

    session secret => 'x' x 32;
    database backend => 'T::Backend::Memory';
    model 'User';
    model 'Token';
    auth model => 'User';
    plugin 'TOTP' => { issuer => 'test.example' };

    # its own user: the codes are one-use per time step, and Tc has spent
    # user 7's current one
    post '/start' => sub { $_[0]->totp_challenge({ id => 8 }, to => '/dest') };
}
my $secret2 = Punk::TOTP->secret;
T::Backend::Memory::_rows('users')->{8} =
    { id => 8, totp_secret => $secret2, totp_enabled => 1,
      email => 'eight@example.com' };
my $n = Punk::Test->new('Tn');
$n->post_ok('/start');
$n->get_ok('/login/totp');
is $n->status, 200, 'the csrf-less app renders the challenge';
unlike $n->body, qr/_csrf/, 'with no token field';
$n->post_ok('/login/totp',
    form => { code => Punk::TOTP->code($secret2, time => time) });
is $n->status, 302, 'and a bare POST still works there';

done_testing;
