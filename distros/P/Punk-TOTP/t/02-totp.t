use strict;
use warnings;
use Test::More;
BEGIN { do './t/sibling.pl' }
use Punk::TOTP;

# RFC 6238 Appendix B, every timestamp, all three algorithm columns,
# 8 digits. The classic trap is retyped along with the table: the
# published vectors use a DIFFERENT secret per algorithm - the ASCII
# seed repeated to 20, 32 and 64 bytes - and running one secret down
# all three columns produces "vectors that do not match".

my %secret = (
    sha1   => Punk::TOTP->b32_encode('12345678901234567890'),
    sha256 => Punk::TOTP->b32_encode(
        '12345678901234567890123456789012'),
    sha512 => Punk::TOTP->b32_encode(
        '1234567890123456789012345678901234567890123456789012345678901234'),
);

my @vectors = (
    # time, sha1, sha256, sha512
    [ 59,          '94287082', '46119246', '90693936' ],
    [ 1111111109,  '07081804', '68084774', '25091201' ],
    [ 1111111111,  '14050471', '67062674', '99943326' ],
    [ 1234567890,  '89005924', '91819424', '93441116' ],
    [ 2000000000,  '69279037', '90698825', '38618901' ],
    [ 20000000000, '65353130', '77737706', '47863826' ],
);

for my $v (@vectors) {
    my ($t, @want) = @$v;
    my $i = 0;
    for my $alg (qw(sha1 sha256 sha512)) {
        is +Punk::TOTP->code($secret{$alg},
                            algorithm => $alg, digits => 8, time => $t),
           $want[$i], "$alg at t=$t";
        $i++;
    }
}

# 6-digit mode is the low six of the same computation
is +Punk::TOTP->code($secret{sha1}, time => 59), '287082',
    'six digits at t=59';

# a changed period moves the counter, not the arithmetic
is +Punk::TOTP->code($secret{sha1}, time => 118, period => 60),
   Punk::TOTP->code($secret{sha1}, time => 59, period => 30),
   'same counter through a different period';

done_testing;
