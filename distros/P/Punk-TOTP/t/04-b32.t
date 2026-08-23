use strict;
use warnings;
use Test::More;
BEGIN { do './t/sibling.pl' }
use Punk::TOTP;

# RFC 4648 base32, and above all the property the shelf's other
# implementations lack: rejection. A decoder that absorbs a typo
# produces a different secret that verifies nothing and reports
# nothing.

# --- the RFC 4648 section 10 vectors ----------------------------------------
my @vec = (
    [ '',       ''                 ],
    [ 'f',      'MY======'         ],
    [ 'fo',     'MZXQ===='         ],
    [ 'foo',    'MZXW6==='         ],
    [ 'foob',   'MZXW6YQ='         ],
    [ 'fooba',  'MZXW6YTB'         ],
    [ 'foobar', 'MZXW6YTBOI======' ],
);
for my $v (@vec) {
    my ($plain, $b32) = @$v;
    is +Punk::TOTP->b32_encode($plain), $b32, "encode '$plain'";
    is +Punk::TOTP->b32_decode($b32), $plain, "decode '$b32'";
}

# --- round trip at every length, covering all five padding cases ------------
for my $len (0 .. 72) {
    my $bytes = join '', map { chr(($_ * 37 + $len) % 256) } 1 .. $len;
    is +Punk::TOTP->b32_decode(Punk::TOTP->b32_encode($bytes)), $bytes,
        "round trip at $len bytes";
}

# --- what people type -------------------------------------------------------
is +Punk::TOTP->b32_decode('mzxw6ytb'), 'fooba', 'lowercase folds';
is +Punk::TOTP->b32_decode('MZXW 6YTB'), 'fooba', 'spaces skip';
is +Punk::TOTP->b32_decode('MZXW-6YTB'), 'fooba', 'hyphens skip';
is +Punk::TOTP->b32_decode("MZXW\t6YTB"), 'fooba', 'tabs skip';
is +Punk::TOTP->b32_decode('MZXW6YQ'), 'foob', 'bare (unpadded) accepted';

# --- rejection, one assertion per refused byte ------------------------------
# the confusable digits, mid-string padding, and punctuation outside
# the skip set - each must refuse, not correct
for my $bad ('0', '1', '8', '9', '!', '@', '/', '+', ',', '.', "\n") {
    my $err = do {
        local $@;
        eval { Punk::TOTP->b32_decode("MZX${bad}6YTB") };
        $@;
    };
    like $err, qr/not valid base32/,
        sprintf 'byte 0x%02x refuses', ord $bad;
}

my $err = do {
    local $@;
    eval { Punk::TOTP->b32_decode('MZ==XW') };
    $@;
};
like $err, qr/not valid base32/, 'padding in the middle refuses';

$err = do {
    local $@;
    eval { Punk::TOTP->b32_decode('M') };
    $@;
};
like $err, qr/not valid base32/,
    'a symbol count no encoding produces refuses';

$err = do {
    local $@;
    eval { Punk::TOTP->b32_decode('MZXW6YTZ' . 'B') };
    $@;
};
like $err, qr/not valid base32/, 'trailing bits that are not zero refuse';

# and the front door: a typo'd secret croaks at the method, before any
# arithmetic happens on the wrong bytes
$err = do {
    local $@;
    eval { Punk::TOTP->code('MZX16YTB') };
    $@;
};
like $err, qr/secret is not valid base32/, 'a bad secret refuses at code()';

done_testing;
