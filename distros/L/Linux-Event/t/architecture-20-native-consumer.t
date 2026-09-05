use v5.36;
use strict;
use warnings;

use Test::More;

use Linux::Event::Loop;
use Linux::Event::IO::Pipe;
use Linux::Event::_ByteStream ();
use Linux::Event::Framer;

{
    package T::ArchitectureNativeConsumer;
    use parent 'Linux::Event::IO::Pipe';
    use Linux::Event::Framer 'Delimiter', "\n";

    Linux::Event::Framer->declare_native_consumer(
        __PACKAGE__,
        Linux::Event::_ByteStream::TestSupport->_test_consumer_definition,
    );
}

is(Linux::Event::_ByteStream->_native_consumer_abi_version, 1,
    'native consumer ABI v1 is owned by the ordered-byte engine');
ok(!Linux::Event::IO::Pipe->can('_test_consumer_definition'),
    'test-only native consumer helpers are not public leaf API');

pipe(my $read_fh, my $write_fh) or die "pipe: $!";
my $loop = Linux::Event::Loop->new;
my $pipe = T::ArchitectureNativeConsumer->new(loop => $loop, read_fh => $read_fh);
ok($pipe->isa('Linux::Event::IO::Pipe'),
    'native consumer attaches to the public IO::Pipe leaf');

$pipe->{xs_state}->_test_consumer_arm(sub { $loop->stop });
is(syswrite($write_fh, "consumer-api\n"), 13,
    'wrote one framed payload to the pipe');
$loop->run;

is($pipe->{xs_state}->_test_consumer_take, 'consumer-api',
    'framed message reaches the native consumer');
ok($pipe->{xs_state}->consumer_paused,
    'pull consumer returns to paused state after receive');

$pipe->close;
close $write_fh;

done_testing;
