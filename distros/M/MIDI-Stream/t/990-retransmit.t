use Test2::V0;
use Test::Lib;
use MIDI::Stream::Test 'encode_hex';

use MIDI::Stream::Encoder;

my $encoder = MIDI::Stream::Encoder->new(
   enable_running_status => 1,
   running_status_retransmit => 5
);

my $msg = join '', map { $encoder->encode([ note_on => 0xe, 0x44, 0x55 ]) } 1..7;
is(
    encode_hex( $msg ),
    "9e 44 55 44 55 44 55 44 55 44 55 44 55 9e 44 55",
    "Status refreshed after 5 messages with no status"
);



done_testing;
