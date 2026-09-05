use v5.36;
use strict;
use warnings;

use Test::More;

use Linux::Event::_IO ();
use Linux::Event::_ByteStream ();
use Linux::Event::_Socket ();
use Linux::Event::_Socket::Stream ();
use Linux::Event::_Socket::Listener ();
use Linux::Event::_Socket::Dgram ();

ok(Linux::Event::_ByteStream->isa('Linux::Event::_IO'),
    '_ByteStream is an internal IO specialization');
ok(Linux::Event::_Socket->isa('Linux::Event::_IO'),
    '_Socket is an internal IO specialization');
ok(!Linux::Event::_ByteStream->isa('Linux::Event::_Socket'),
    '_ByteStream is not socket-specific');
ok(!Linux::Event::_Socket->isa('Linux::Event::_ByteStream'),
    '_Socket does not imply ordered-byte semantics');

ok(Linux::Event::_Socket::Stream->isa('Linux::Event::_Socket'),
    'stream-socket implementation is socket-specific');
ok(Linux::Event::_Socket::Stream->isa('Linux::Event::_ByteStream'),
    'stream-socket implementation reuses the ordered-byte engine');
ok(Linux::Event::_Socket::Listener->isa('Linux::Event::_Socket'),
    'listener implementation is socket-specific');
ok(!Linux::Event::_Socket::Listener->isa('Linux::Event::_ByteStream'),
    'listener implementation is not an ordered-byte connection');
ok(Linux::Event::_Socket::Dgram->isa('Linux::Event::_Socket'),
    'datagram implementation is socket-specific');
ok(!Linux::Event::_Socket::Dgram->isa('Linux::Event::_ByteStream'),
    'datagram implementation preserves packet rather than byte-stream semantics');

for my $retired (qw(
    Linux::Event::Stream
    Linux::Event::Socket
    Linux::Event::Listener
    Linux::Event::Datagram
)) {
    ok(!$retired->can('new'), "$retired is not retained as an implementation base");
}

done_testing;
