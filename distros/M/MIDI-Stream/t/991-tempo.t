use Test2::V0;
use Test::Time::HiRes;

use Time::HiRes qw/ usleep /;
use MIDI::Stream::Decoder;

my $ppqn = 24;
my $tempo = 120;
my $usecs = ( ( 60 / $tempo ) / $ppqn ) * 1_000_000;

my $decoder = MIDI::Stream::Decoder->new(
    clock_samples => 10,
    round_tempo => 1
);

for ( 1..11 ) {
    $decoder->decode( chr 0xf8 );
    usleep( $usecs );
}

is( $decoder->tempo, $tempo, "Decoder tracks tempo from clock messages" );

done_testing;
