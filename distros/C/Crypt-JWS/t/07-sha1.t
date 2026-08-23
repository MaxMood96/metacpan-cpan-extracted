use strict;
use warnings;
use Test::More;
use Crypt::JWS qw(sha1 hmac_sha1 hmac_sha512);

# The version 2 surface: SHA-1 and its HMAC, added for HMAC-based
# protocols whose interop default is SHA-1 (RFC 6238 TOTP above all).
# Vectors are the published ones, retyped from the RFCs rather than
# generated, so an error in the implementation cannot vouch for itself.

# FIPS 180 SHA-1
is unpack('H*', sha1('abc')),
   'a9993e364706816aba3e25717850c26c9cd0d89d', 'FIPS 180 "abc"';
is unpack('H*', sha1('')),
   'da39a3ee5e6b4b0d3255bfef95601890afd80709', 'FIPS 180 empty';
is unpack('H*',
   sha1('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq')),
   '84983e441c3bd26ebaae4aa1f95129e5e54670f1', 'FIPS 180 two-block';

# RFC 2202 HMAC-SHA1, all seven cases
my @rfc2202 = (
    [ "\x0b" x 20, 'Hi There',
      'b617318655057264e28bc0b6fb378c8ef146be00' ],
    [ 'Jefe', 'what do ya want for nothing?',
      'effcdf6ae5eb2fa2d27416d5f184df9c259a7c79' ],
    [ "\xaa" x 20, "\xdd" x 50,
      '125d7342b9ac11cd91a39af48aa17b4f63f175d3' ],
    [ pack('H*', '0102030405060708090a0b0c0d0e0f10111213141516171819'),
      "\xcd" x 50,
      '4c9007f4026250c6bc8414f9bf50c86c2d7235da' ],
    [ "\x0c" x 20, 'Test With Truncation',
      '4c1a03424b55e07fe7f27be1d58bb9324a9a5a04' ],
    [ "\xaa" x 80, 'Test Using Larger Than Block-Size Key - Hash Key First',
      'aa4ae5e15272d00e95705637ce8a3b55ed402112' ],
    [ "\xaa" x 80,
      'Test Using Larger Than Block-Size Key and Larger Than One '
    . 'Block-Size Data',
      'e8e99d0f45237d786d6bbaa7965c7808bbff1a91' ],
);
for my $i (0 .. $#rfc2202) {
    my ($key, $data, $want) = @{ $rfc2202[$i] };
    is unpack('H*', hmac_sha1($key, $data)), $want,
        'RFC 2202 case ' . ($i + 1);
}

# RFC 4231 case 1 for HMAC-SHA512, which was exported but never
# vector-tested while the ABI lacked it
is unpack('H*', hmac_sha512("\x0b" x 20, 'Hi There')),
   '87aa7cdea5ef619d4ff0b4241a1d6cb02379f4e2ce4ec2787ad0b30545e17cde'
 . 'daa833b7d6b8a702038b274eaea3f4e4be9d914eeb61f1702e696c203a126854',
   'RFC 4231 case 1 HMAC-SHA512';

# the ABI carries all of it
my $st = Crypt::JWS::_abi_selftest();
ok $st, 'ABI selftest covers the v2 members';

done_testing;
