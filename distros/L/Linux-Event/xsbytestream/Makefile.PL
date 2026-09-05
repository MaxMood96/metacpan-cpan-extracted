use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Linux::Event::_ByteStream',
    VERSION_FROM     => '../lib/Linux/Event.pm',
    ABSTRACT         => 'Native ordered-byte I/O engine for Linux::Event',
    AUTHOR           => 'Joshua S. Day <hax@cpan.org>',
    LICENSE          => 'perl_5',
    MIN_PERL_VERSION => '5.036000',
    PM               => {},
    XS               => { 'ByteStream.xs' => 'ByteStream.c' },
    OBJECT           => join(' ', map { "$_\$(OBJ_EXT)" } qw(
        ByteStream
        stream_state
        stream_transport
        stream_callbacks
        stream_input
        stream_delivery
        stream_consumer
        stream_test_consumer
        stream_read
        stream_write
        stream_transition
        framer_delimiter
        framer_fixed
        framer_length
        framer_netstring
        framer_varint
        framer_decimal
    )),
    depend           => {
        '$(OBJECT)' => 'stream_internal.h stream_transport_abi.h stream_consumer_abi.h',
    },
    clean            => { FILES => 'ByteStream.c' },
);
