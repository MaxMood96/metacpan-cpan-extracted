#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use XS::JIT::Builder;
use XS::JIT;

# ============================================================
# Phase 3: HTTP/2 DATA Frame Streaming Tests
# ============================================================

plan tests => 18;

# ============================================================
# Test 1-3: Module loads
# ============================================================
use_ok('Hypersonic');
use_ok('Hypersonic::Protocol::HTTP2');
use_ok('Hypersonic::Stream');

# ============================================================
# Compile Stream XS for testing
# ============================================================
{
    my $builder = XS::JIT::Builder->new;

    $builder->line('#include <string.h>')
      ->line('#include <sys/socket.h>')
      ->blank;

    Hypersonic::Stream->generate_c_code($builder);

    XS::JIT->compile(
        code      => $builder->code,
        name      => 'Hypersonic::Stream',
        functions => Hypersonic::Stream->get_xs_functions,
    );
}

# ============================================================
# Test 4: Check nghttp2 availability
# ============================================================
my $has_nghttp2 = Hypersonic::Protocol::HTTP2->check_nghttp2();
ok(defined $has_nghttp2, 'nghttp2 detection works');
diag($has_nghttp2 ? 'nghttp2 found' : 'nghttp2 not available');

# ============================================================
# Test 5-9: JIT code generation for HTTP/2 streaming
# ============================================================
SKIP: {
    skip 'nghttp2 not available', 5 unless $has_nghttp2;
    
    require XS::JIT::Builder;
    
    subtest 'gen_stream_headers generates correct code' => sub {
        plan tests => 4;
        
        my $builder = XS::JIT::Builder->new;
        Hypersonic::Protocol::HTTP2->gen_stream_headers($builder);
        my $code = $builder->code;
        
        like($code, qr/h2_stream_headers/, 'function defined');
        like($code, qr/nghttp2_submit_headers/, 'uses submit_headers');
        like($code, qr/NGHTTP2_FLAG_END_HEADERS/, 'has END_HEADERS flag');
        unlike($code, qr/NGHTTP2_FLAG_END_STREAM/, 'no END_STREAM on headers');
    };
    
    subtest 'gen_stream_data generates correct code' => sub {
        plan tests => 4;
        
        my $builder = XS::JIT::Builder->new;
        Hypersonic::Protocol::HTTP2->gen_stream_data($builder);
        my $code = $builder->code;
        
        like($code, qr/h2_stream_data/, 'function defined');
        like($code, qr/H2ChunkProvider/, 'defines chunk provider');
        like($code, qr/nghttp2_submit_data/, 'uses submit_data');
        like($code, qr/NGHTTP2_FLAG_NONE/, 'uses FLAG_NONE (not END_STREAM)');
    };
    
    subtest 'gen_stream_end generates correct code' => sub {
        plan tests => 2;
        
        my $builder = XS::JIT::Builder->new;
        Hypersonic::Protocol::HTTP2->gen_stream_end($builder);
        my $code = $builder->code;
        
        like($code, qr/h2_stream_end/, 'function defined');
        like($code, qr/NGHTTP2_FLAG_END_STREAM/, 'uses END_STREAM flag');
    };
    
    subtest 'gen_flow_control generates correct code' => sub {
        plan tests => 3;
        
        my $builder = XS::JIT::Builder->new;
        Hypersonic::Protocol::HTTP2->gen_flow_control($builder);
        my $code = $builder->code;
        
        like($code, qr/h2_can_send/, 'h2_can_send defined');
        like($code, qr/h2_window_size/, 'h2_window_size defined');
        like($code, qr/get_remote_window_size/, 'checks window size');
    };
    
    subtest 'gen_stream_xs_wrappers generates correct code' => sub {
        plan tests => 3;
        
        my $builder = XS::JIT::Builder->new;
        Hypersonic::Protocol::HTTP2->gen_stream_xs_wrappers($builder);
        my $code = $builder->code;
        
        like($code, qr/hypersonic_h2_stream_start/, 'h2_stream_start XS wrapper');
        like($code, qr/hypersonic_h2_stream_write/, 'h2_stream_write XS wrapper');
        like($code, qr/hypersonic_h2_stream_end/, 'h2_stream_end XS wrapper');
    };
}

# ============================================================
# Test 10-12: Stream.pm HTTP/2 protocol detection
# ============================================================
subtest 'Stream object with http2 protocol' => sub {
    plan tests => 2;

    my $stream = Hypersonic::Stream->new(
        fd       => 10,
        protocol => 'http2',
    );

    is($stream->protocol, 'http2', 'protocol is http2');
    is($stream->fd, 10, 'fd is set');
};

subtest 'Stream object with http1 protocol' => sub {
    plan tests => 2;
    
    my $stream = Hypersonic::Stream->new(
        fd       => 5,
        protocol => 'http1',
    );
    
    is($stream->protocol, 'http1', 'protocol is http1');
    is($stream->fd, 5, 'fd is set');
};

subtest 'Stream defaults to http1' => sub {
    plan tests => 1;
    
    my $stream = Hypersonic::Stream->new(fd => 1);
    is($stream->protocol, 'http1', 'default protocol is http1');
};

# ============================================================
# Test 13-15: generate_streaming method
# ============================================================
SKIP: {
    skip 'nghttp2 not available', 3 unless $has_nghttp2;
    
    subtest 'generate_streaming generates all functions' => sub {
        plan tests => 5;
        
        require XS::JIT::Builder;
        my $builder = XS::JIT::Builder->new;
        
        Hypersonic::Protocol::HTTP2->generate_streaming($builder);
        my $code = $builder->code;
        
        like($code, qr/h2_stream_headers/, 'has h2_stream_headers');
        like($code, qr/h2_stream_data/, 'has h2_stream_data');
        like($code, qr/h2_stream_end/, 'has h2_stream_end');
        like($code, qr/h2_can_send/, 'has h2_can_send');
        like($code, qr/hypersonic_h2_stream/, 'has XS wrappers');
    };
    
    subtest 'Stream.generate_c_code with http2 option' => sub {
        plan tests => 2;

        require XS::JIT::Builder;
        my $builder = XS::JIT::Builder->new;

        Hypersonic::Stream->generate_c_code($builder, {
            max_connections => 100,
            http2           => 1,
        });
        my $code = $builder->code;

        # HTTP/1.1 streaming code (always present)
        like($code, qr/stream_start|stream_write_chunk/, 'has HTTP/1.1 streaming code');

        # Stream registry tracks http2 flag for future HTTP/2 support
        like($code, qr/int http2/, 'has http2 flag in StreamState');
    };
    
    subtest 'Stream.generate_c_code without http2 option' => sub {
        plan tests => 2;
        
        require XS::JIT::Builder;
        my $builder = XS::JIT::Builder->new;
        
        Hypersonic::Stream->generate_c_code($builder, {
            max_connections => 100,
            http2           => 0,
        });
        my $code = $builder->code;
        
        # HTTP/1.1 streaming code
        like($code, qr/stream_start|stream_write_chunk/, 'has HTTP/1.1 streaming code');
        
        # No HTTP/2 streaming code
        unlike($code, qr/h2_stream_headers/, 'no HTTP/2 streaming code');
    };
}

# ============================================================
# Test 16-18: Integration with Hypersonic
# ============================================================
SKIP: {
    skip 'nghttp2 not available', 3 unless $has_nghttp2;
    
    # Check for TLS test certificates
    my $cert_file = 't/certs/server.crt';
    my $key_file = 't/certs/server.key';
    my $has_certs = (-f $cert_file && -f $key_file);
    
    SKIP: {
        skip 'TLS certificates not found', 1 unless $has_certs;
        
        subtest 'Hypersonic compile with http2 and streaming' => sub {
            plan tests => 3;
            
            my $app = Hypersonic->new(
                http2    => 1,
                tls      => 1,
                cert     => $cert_file,
                key      => $key_file,
            );
            
            $app->get('/events' => sub {
                my ($req, $stream) = @_;
                $stream->write("data: test\n\n");
                $stream->end();
            }, { streaming => 1 });
            
            $app->get('/' => sub { return { status => 200, body => 'hello' } });
            
            eval { $app->compile() };
            ok(!$@, 'compile succeeds') or diag($@);
            ok($app->{http2}, 'http2 enabled');
            ok($app->{route_analysis}{needs_streaming}, 'streaming detected');
        };
    }
    
    SKIP: {
        skip 'TLS certificates not found', 1 unless $has_certs;
        
        subtest 'Hypersonic compile with http2, no streaming' => sub {
            plan tests => 3;
            
            my $app = Hypersonic->new(
                http2    => 1,
                tls      => 1,
                cert     => $cert_file,
                key      => $key_file,
            );
            
            $app->get('/' => sub { return { status => 200, body => 'hello' } });
            
            eval { $app->compile() };
            ok(!$@, 'compile succeeds') or diag($@);
            ok($app->{http2}, 'http2 enabled');
            ok(!$app->{route_analysis}{needs_streaming}, 'no streaming detected');
        };
    }
    
    subtest 'Hypersonic without http2 still compiles streaming' => sub {
        plan tests => 3;
        
        my $app = Hypersonic->new(http2 => 0);
        
        $app->get('/stream' => sub {
            my ($req, $stream) = @_;
            $stream->write("chunk");
            $stream->end();
        }, { streaming => 1 });
        
        $app->get('/' => sub { return 'hello' });
        
        eval { $app->compile() };
        ok(!$@, 'compile succeeds') or diag($@);
        ok(!$app->{http2}, 'http2 disabled');
        ok($app->{route_analysis}{needs_streaming}, 'streaming detected');
    };
}

done_testing();
