use strict;
use warnings;
use Test::More;
BEGIN { do './t/sibling.pl' }

BEGIN {
    plan skip_all => 'Punk 0.22+ required for the plugin tests'
        unless eval { require Punk; Punk->VERSION('0.22'); 1 };
}

# Recovery codes: their own issue/take path over the token table
# shape, because issue_token's semantics - older same-kind tokens die
# first, ttl must be positive - are right for mailed links and wrong
# for a drawer of ten codes that never expire.

# ---- a per-table in-memory backend with a filtering search -----------------
{
    package T::Backend::Memory;
    my %TABLES;
    my $NEXT = 1;
    sub _rows { $TABLES{ $_[0] } ||= {} }
    sub _reset { %TABLES = (); $NEXT = 1 }
    sub new    { my ($class, %a) = @_; bless { table => $a{table} }, $class }
    sub get    { my ($self, %k) = @_; _rows($self->{table})->{ $k{id} } }
    sub search {
        my ($self, $filter, $opts) = @_;
        my @rows = grep {
            my $row = $_;
            !grep { ($row->{$_} // '') ne ($filter->{$_} // '') }
                 keys %{ $filter || {} };
        } values %{ _rows($self->{table}) };
        return { rows => \@rows, has_more_data => 0, next => undef };
    }
    sub all    { $_[0]->search({}, {}) }
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

my ($codes_h, $use_h);
{
    package T;
    use Punk;

    session secret => 'x' x 32;
    database backend => 'T::Backend::Memory';
    model 'User';
    model 'Token';
    plugin 'TOTP' => { issuer => 'test.example' };

    get '/probe' => sub {
        my ($c) = @_;
        $codes_h = sub { $c->totp_recovery_codes(@_) };
        $use_h   = sub { $c->totp_use_recovery(@_) };
        return $c->text('ok');
    };
}

require Punk::Test;
my $t = Punk::Test->new('T');
$t->get_ok('/probe');

my $tokens = sub { [ values %{ T::Backend::Memory::_rows('tokens') } ] };
my $user   = { id => 7 };

# ---- issue -----------------------------------------------------------------
my $codes = $codes_h->($user);
is scalar @$codes, 10, 'ten codes by default';
is scalar @{ $tokens->() }, 10, 'and ten rows coexist - no same-kind purge';

for my $code (@$codes) {
    like $code, qr/\A[A-Z2-7]{8}-[A-Z2-7]{8}\z/,
        'grouped base32, no confusable digits';
}
{
    my %uniq = map { $_ => 1 } @$codes;
    is scalar keys %uniq, 10, 'all distinct';
    my $row = $tokens->()->[0];
    is $row->{kind}, 'totp_recovery', 'rows carry the kind';
    is $row->{expires}, 0, 'and never expire';
    like $row->{digest}, qr/\A[0-9a-f]{64}\z/,
        'digest is lowercase sha256 hex - pwd_token_digest wire form';
    isnt $row->{digest}, $codes->[0],
        'the plaintext is not stored';
}

# ---- take: single use, delete first ----------------------------------------
ok $use_h->($user, $codes->[0]), 'a code is accepted';
is scalar @{ $tokens->() }, 9, 'and its row is gone';
ok !$use_h->($user, $codes->[0]), 'the same code refuses a second time';

ok $use_h->($user, lc "$codes->[1]"), 'lowercase folds';
(my $spaced = $codes->[2]) =~ s/-/ /;
ok $use_h->($user, $spaced), 'spacing variants fold';
is scalar @{ $tokens->() }, 7, 'three spent';

# ---- the wrong user does not spend another user's code ---------------------
# The search is scoped to the challenged user, so another account's row is
# never fetched - and so never burned. The burn discipline below still holds
# for every row the search CAN reach.
ok !$use_h->({ id => 99 }, $codes->[3]),
    'another user cannot use the code';
is scalar @{ $tokens->() }, 7,
    'and the probe did not reach the row, so it did not burn it';
ok $use_h->($user, $codes->[3]),
    'the real owner still has it';
is scalar @{ $tokens->() }, 6, 'four spent';

# ---- wrong-kind probe burns the row it hit ---------------------------------
{
    # a mailed-link token sharing the table, as production tables do
    my $m = T::Backend::Memory->new(table => 'tokens');
    $m->create({ user_id => 7, kind => 'reset',
                 digest  => Punk::Plugin::TOTP::_recovery_digest('AAAAAAAA-AAAAAAAA'),
                 expires => time + 3600 });
    my $before = scalar @{ $tokens->() };
    ok !$use_h->($user, 'AAAAAAAA-AAAAAAAA'),
        'a recovery attempt against a reset token refuses';
    is scalar @{ $tokens->() }, $before - 1,
        'and burns the reset token rather than leaving it live';
}

# ---- unknown code, garbage code --------------------------------------------
ok !$use_h->($user, 'BBBBBBBB-BBBBBBBB'), 'an unknown code refuses';
ok !$use_h->($user, ''), 'an empty code refuses';
ok !$use_h->($user, undef), 'undef refuses';

# ---- a new set revokes the old ---------------------------------------------
my $second = $codes_h->($user, count => 5);
is scalar @$second, 5, 'count option honoured';
is scalar grep({ $_->{kind} eq 'totp_recovery' } @{ $tokens->() }), 5,
    'the old set is gone with the new one issued';
ok !$use_h->($user, $codes->[4]),
    'a code from the revoked set refuses';
ok $use_h->($user, $second->[0]), 'a code from the new set works';

# ---- non-numeric user ids (CVE-2026-78619) ---------------------------------
# A user model may be keyed on a username, an email address or a UUID. Those
# all coerce to 0 under integer comparison, which made any two of them equal
# and let one account's recovery code pass another's challenge. The ownership
# test compares identifiers as the bytes they are.
for my $pair (
    [ 'alice',             'bob'               ],
    [ 'alice@example.com', 'bob@example.com'   ],
    [ '3f1a-uuid',         '9c2b-uuid'         ],
) {
    my ($vid, $aid) = @$pair;
    my $victim   = { id => $vid };
    my $attacker = { id => $aid };
    my $vcodes   = $codes_h->($victim);
    my $acodes   = $codes_h->($attacker);

    ok !$use_h->($victim, $acodes->[0]),
        "a code issued to $aid does not pass the challenge for $vid";
    ok !$use_h->($attacker, $vcodes->[0]),
        'and it does not work the other way round either';

    # the refusal did not spend either owner's code
    ok $use_h->($attacker, $acodes->[0]), "$aid still holds their own code";
    ok $use_h->($victim,   $vcodes->[0]), "$vid still holds their own code";
}

# a numeric id keeps comparing as it always did, including across the
# string/integer seam a database round trip puts identifiers through
{
    my $ncodes = $codes_h->({ id => 41 });
    ok !$use_h->({ id => 4 }, $ncodes->[0]), 'no prefix match on numeric ids';
    ok $use_h->({ id => '41' }, $ncodes->[0]),
        'the owner passes with the id stringified';
}

done_testing;
