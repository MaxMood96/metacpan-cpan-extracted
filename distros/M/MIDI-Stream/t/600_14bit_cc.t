use Test2::V0;
use Test::Lib;
use MIDI::Stream::Test 'run_file';

run_file({
   test_type => 'decoding',
   filename  => '600_14bit_cc.json',
   params    => {
      enable_14bit_cc => 1
   }
});

run_file({
   test_type => 'encoding',
   filename  => '600_14bit_cc.json',
   params    => {
      enable_running_status => 1,
      enable_14bit_cc => 1,
   }
});

done_testing;
