use Test2::V0;
use Test::Lib;
use MIDI::Stream::Test 'encode_hex';

use MIDI::Stream::Encoder;

my $encoder = MIDI::Stream::Encoder->new();

my $msg = $encoder->encode([ note_on => 0xe, 0x44, 0x55,
                                             0x66, 0x77,
                                             0x88, 0x99 ]);
is(
    encode_hex( $msg ),
    "9e 44 55 66 77 88 99",
    "encode() can receive additional bytes to handroll a running status"
);

done_testing;
