use strict;
use warnings;
use Test::More;
BEGIN { do './t/sibling.pl' }
use Punk::TOTP;

# The verifier: the skew window, the matched counter, and the replay
# rule that lives INSIDE it - a verifier returning a bare boolean
# cannot be made replay-safe from outside.

my $secret = Punk::TOTP->b32_encode('12345678901234567890');
my $t      = 1111111109;                 # counter 37037036
my $centre = int($t / 30);

my $code = Punk::TOTP->code($secret, time => $t);

# --- the window -------------------------------------------------------------
ok scalar +Punk::TOTP->verify($secret, $code, time => $t),
    'the current code verifies';
ok scalar +Punk::TOTP->verify($secret, $code, time => $t + 30),
    'and still does one step later (skew 1)';
ok scalar +Punk::TOTP->verify($secret, $code, time => $t - 30),
    'and one step earlier';
ok !Punk::TOTP->verify($secret, $code, time => $t + 61),
    'but not two steps later';
ok !Punk::TOTP->verify($secret, $code, time => $t - 60),
    'nor two steps earlier';

ok !Punk::TOTP->verify($secret, $code, time => $t + 30, skew => 0),
    'skew 0 accepts only the exact step';
ok scalar +Punk::TOTP->verify($secret, $code, time => $t + 90, skew => 3),
    'a wider skew widens the window';

# --- the matched counter ----------------------------------------------------
my ($ok, $counter) = Punk::TOTP->verify($secret, $code, time => $t);
ok $ok, 'list context verifies';
is $counter, $centre, 'and reports the matched counter';

($ok, $counter) = Punk::TOTP->verify($secret, $code, time => $t + 30);
is $counter, $centre,
    'the counter names the step the CODE belongs to, not the clock';

($ok, $counter) = Punk::TOTP->verify($secret, 'wrong', time => $t);
ok !$ok, 'a wrong code refuses';
ok !defined $counter, 'and reports no counter';

# --- replay, by construction ------------------------------------------------
ok scalar +Punk::TOTP->verify($secret, $code, time => $t,
                             last_counter => $centre - 1),
    'a counter above the floor verifies';
ok !Punk::TOTP->verify($secret, $code, time => $t,
                       last_counter => $centre),
    'the same counter again is a replay and refuses';
ok !Punk::TOTP->verify($secret, $code, time => $t + 30,
                       last_counter => $centre),
    'still refused later in the window - the whole point';

# the full ritual: accept, store, replay refused
{
    my ($ok1, $c1) = Punk::TOTP->verify($secret, $code, time => $t,
                                        last_counter => 0);
    ok $ok1, 'first submission accepted';
    my ($ok2) = Punk::TOTP->verify($secret, $code, time => $t,
                                   last_counter => $c1);
    ok !$ok2, 'identical second submission refused via the stored counter';
}

# counter zero is a real counter (RFC 4226 vector 0 exists); only an
# absent last_counter means no floor
ok scalar +Punk::TOTP->verify($secret,
        Punk::TOTP->hotp($secret, 0), time => 15),
    'the counter-zero code verifies with no floor';

# --- refused before any HMAC ------------------------------------------------
ok !Punk::TOTP->verify($secret, '12345',   time => $t), 'five digits';
ok !Punk::TOTP->verify($secret, '1234567', time => $t), 'seven digits';
ok !Punk::TOTP->verify($secret, '12345a',  time => $t), 'a letter';
ok !Punk::TOTP->verify($secret, '',        time => $t), 'empty';

done_testing;
