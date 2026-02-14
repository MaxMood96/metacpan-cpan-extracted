use Test2::V0;
use Test::Lib;
use MIDI::Stream::Test 'run_file';

run_file({
   test_type => 'decoding',
   filename  => '000_example.json'
});

run_file({
   test_type => 'encoding',
   filename  => '000_example.json'
});


done_testing;
