#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

# ============================================================
# Phase 2: HTTP/1.1 Chunked Encoding Tests
# ============================================================

plan tests => 16;

# ============================================================
# Test 1-2: Module loads
# ============================================================
use_ok('Hypersonic');
use_ok('Hypersonic::Protocol::HTTP1');
use_ok('Hypersonic::Stream');

# ============================================================
# Test 3-5: Compile-time chunk building
# ============================================================
subtest 'build_chunk formats correctly' => sub {
    plan tests => 4;
    
    # Simple text
    my $chunk = Hypersonic::Protocol::HTTP1->build_chunk("Hello");
    is($chunk, "5\r\nHello\r\n", 'simple chunk format');
    
    # Longer text
    $chunk = Hypersonic::Protocol::HTTP1->build_chunk("Hello World!");
    is($chunk, "c\r\nHello World!\r\n", '12-byte chunk uses hex c');
    
    # Empty data
    $chunk = Hypersonic::Protocol::HTTP1->build_chunk("");
    is($chunk, '', 'empty data returns empty string');
    
    # Undefined data
    $chunk = Hypersonic::Protocol::HTTP1->build_chunk(undef);
    is($chunk, '', 'undef data returns empty string');
};

subtest 'build_final_chunk format' => sub {
    plan tests => 1;
    
    my $final = Hypersonic::Protocol::HTTP1->build_final_chunk();
    is($final, "0\r\n\r\n", 'final chunk is 0\\r\\n\\r\\n');
};

subtest 'chunk size hex encoding' => sub {
    plan tests => 4;
    
    # Various sizes to test hex encoding
    my $chunk = Hypersonic::Protocol::HTTP1->build_chunk("x" x 15);
    like($chunk, qr/^f\r\n/, '15 bytes = hex f');
    
    $chunk = Hypersonic::Protocol::HTTP1->build_chunk("x" x 16);
    like($chunk, qr/^10\r\n/, '16 bytes = hex 10');
    
    $chunk = Hypersonic::Protocol::HTTP1->build_chunk("x" x 255);
    like($chunk, qr/^ff\r\n/, '255 bytes = hex ff');
    
    $chunk = Hypersonic::Protocol::HTTP1->build_chunk("x" x 256);
    like($chunk, qr/^100\r\n/, '256 bytes = hex 100');
};

# ============================================================
# Test 6-8: JIT code generation for chunked encoding
# ============================================================
subtest 'gen_chunked_start generates correct code' => sub {
    plan tests => 5;
    
    require XS::JIT::Builder;
    my $builder = XS::JIT::Builder->new;
    
    Hypersonic::Protocol::HTTP1->gen_chunked_start($builder);
    my $code = $builder->code;
    
    like($code, qr/void send_chunked_headers\(/, 'function defined');
    like($code, qr/Transfer-Encoding: chunked/, 'chunked header included');
    like($code, qr/Content-Type: %s/, 'content-type placeholder');
    like($code, qr/Connection: keep-alive/, 'keep-alive for streaming');
    like($code, qr/send\(fd, headers/, 'sends headers');
};

subtest 'gen_chunked_write uses writev' => sub {
    plan tests => 4;
    
    require XS::JIT::Builder;
    my $builder = XS::JIT::Builder->new;
    
    Hypersonic::Protocol::HTTP1->gen_chunked_write($builder);
    my $code = $builder->code;
    
    like($code, qr/void send_chunk\(/, 'function defined');
    like($code, qr/%zx/, 'hex format for size');
    like($code, qr/struct iovec iov\[3\]/, '3-part iovec');
    like($code, qr/writev\(fd, iov, 3\)/, 'writev for efficiency');
};

subtest 'gen_chunked_end sends final chunk' => sub {
    plan tests => 2;
    
    require XS::JIT::Builder;
    my $builder = XS::JIT::Builder->new;
    
    Hypersonic::Protocol::HTTP1->gen_chunked_end($builder);
    my $code = $builder->code;
    
    like($code, qr/void send_chunk_end\(/, 'function defined');
    like($code, qr/0\\r\\n\\r\\n/, 'final chunk format');
};

# ============================================================
# Test 9-11: Stream.pm chunked integration
# ============================================================
subtest 'Stream generates chunked headers' => sub {
    plan tests => 3;

    require XS::JIT::Builder;
    my $builder = XS::JIT::Builder->new;

    Hypersonic::Stream->gen_stream_start_c($builder);
    my $code = $builder->code;

    like($code, qr/Transfer-Encoding: chunked/, 'chunked header');
    like($code, qr/HTTP\/1\.1 %d %s/, 'HTTP/1.1 status line');
    like($code, qr/Content-Type: %s/, 'content-type included');
};

subtest 'Stream generates chunk writes with writev' => sub {
    plan tests => 2;

    require XS::JIT::Builder;
    my $builder = XS::JIT::Builder->new;

    Hypersonic::Stream->gen_stream_write_chunk_c($builder);
    my $code = $builder->code;

    like($code, qr/writev/, 'uses writev');
    like($code, qr/iovec/, 'uses iovec struct');
};

subtest 'Stream generates final chunk' => sub {
    plan tests => 1;

    require XS::JIT::Builder;
    my $builder = XS::JIT::Builder->new;

    Hypersonic::Stream->gen_stream_end_c($builder);
    my $code = $builder->code;

    like($code, qr/0\\r\\n\\r\\n/, 'final chunk format');
};

# ============================================================
# Test 12-13: RFC 7230 compliance
# ============================================================
subtest 'Chunk format follows RFC 7230' => sub {
    plan tests => 3;
    
    # RFC 7230 Section 4.1:
    # chunk = chunk-size [ chunk-ext ] CRLF chunk-data CRLF
    # chunk-size = 1*HEXDIG
    
    my $chunk = Hypersonic::Protocol::HTTP1->build_chunk("test");
    
    # Must start with hex digits
    like($chunk, qr/^[0-9a-f]+\r\n/, 'starts with hex size + CRLF');
    
    # Must end with CRLF
    like($chunk, qr/\r\n$/, 'ends with CRLF');
    
    # Data in the middle
    like($chunk, qr/^4\r\ntest\r\n$/, 'complete format correct');
};

subtest 'Final chunk follows RFC 7230' => sub {
    plan tests => 2;
    
    # RFC 7230 Section 4.1:
    # last-chunk = 1*("0") [ chunk-ext ] CRLF
    # trailer-part = *( header-field CRLF )
    # CRLF
    
    my $final = Hypersonic::Protocol::HTTP1->build_final_chunk();
    
    # "0" CRLF CRLF (we don't send trailers)
    is($final, "0\r\n\r\n", 'final chunk correct');
    is(length($final), 5, 'final chunk is 5 bytes');
};

# ============================================================
# Test 14-15: Integration with Hypersonic
# ============================================================
subtest 'Hypersonic compiles streaming routes' => sub {
    plan tests => 3;
    
    my $app = Hypersonic->new();
    
    $app->get('/events' => sub {
        my ($req, $stream) = @_;
        $stream->content_type('text/event-stream');
        $stream->write("data: hello\n\n");
        $stream->end();
    }, { streaming => 1 });
    
    $app->get('/' => sub { return 'hello' });
    
    eval { $app->compile() };
    ok(!$@, 'compile succeeds') or diag($@);
    
    ok($app->{route_analysis}{needs_streaming}, 'streaming detected');
    ok($app->{compiled}, 'app is compiled');
};

subtest 'Generated code includes chunked functions' => sub {
    plan tests => 3;
    
    require XS::JIT::Builder;
    my $builder = XS::JIT::Builder->new;
    
    # Generate all HTTP1 chunked code
    Hypersonic::Protocol::HTTP1->gen_chunked_start($builder);
    Hypersonic::Protocol::HTTP1->gen_chunked_write($builder);
    Hypersonic::Protocol::HTTP1->gen_chunked_end($builder);
    
    my $code = $builder->code;
    
    like($code, qr/send_chunked_headers/, 'has chunked_headers');
    like($code, qr/send_chunk\(/, 'has send_chunk');
    like($code, qr/send_chunk_end/, 'has send_chunk_end');
};

done_testing();
