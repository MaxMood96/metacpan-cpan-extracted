use Test2::V0;
use Test::Lib;
use MIDI::Stream::Test 'run_file';

run_file({
   test_type => 'decoding',
   filename  => '100_channel_messages.json'
});

run_file({
   test_type => 'encoding',
   filename  => '100_channel_messages.json'
});


done_testing;
