use strict;
use warnings;
use Test::More;
BEGIN { do './t/sibling.pl' }
use Punk::TOTP;

# RFC 4226 Appendix D, the full table: the ASCII secret
# "12345678901234567890", counters 0 through 9. Retyped from the RFC,
# not generated, so the implementation cannot vouch for itself.

my $secret = Punk::TOTP->b32_encode('12345678901234567890');
is $secret, 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
    'the reference secret base32-encodes as the RFC shows it';

my @want = qw(755224 287082 359152 969429 338314
              254676 287922 162583 399871 520489);

for my $counter (0 .. 9) {
    is +Punk::TOTP->hotp($secret, $counter), $want[$counter],
        "counter $counter";
}

# 8 digits keeps the low eight of the same dynamic truncation
is +Punk::TOTP->hotp($secret, 0, digits => 8), '84755224',
    '8-digit mode extends leftward';

# a counter far past 32 bits survives (the smoker trap: a counter that
# passes through an IV truncates there and only there)
my $big = Punk::TOTP->hotp($secret, 20000000000);
like $big, qr/\A\d{6}\z/, 'a 35-bit counter produces six digits';
isnt $big, Punk::TOTP->hotp($secret, 20000000000 % (2**32)),
    'and not the code of its 32-bit truncation';

done_testing;
