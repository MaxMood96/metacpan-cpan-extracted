use Test2::V0;
use Test::Lib;
use MIDI::Stream::Test 'run_file';

run_file({
   test_type => 'decoding',
   filename  => '200_running_status.json'
});

run_file({
   test_type => 'encoding',
   filename  => '200_running_status.json',
   params    => { enable_running_status => 1 }
});


done_testing;
