use Test2::V0;
use Test::Lib;
use MIDI::Stream::Test 'run_file';

run_file({
   test_type => 'decoding',
   filename  => '500_undefined_running_status.json'
});

done_testing;
