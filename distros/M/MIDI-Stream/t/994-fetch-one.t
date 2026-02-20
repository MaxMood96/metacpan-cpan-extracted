use Test2::V0;
use Test::Lib;
use MIDI::Stream::Test;

use experimental qw/ signatures /;

use MIDI::Stream::Decoder;
use MIDI::Stream::Encoder;

my @events = (
    [ control_change => 0xf, 0x3f, 0x7f ],
    [ note_on => 0x2, 0x40, 0x40 ],
    [ pitch_bend => 0xe, 0x1a2b ],
);

my $decoder = MIDI::Stream::Decoder->new;
$decoder->decode( MIDI::Stream::Encoder->new->encode_events( @events ) );

plan scalar @events;

while( @events ) {
    is ( $decoder->fetch_one_event->as_arrayref, shift @events );
}

done_testing;
