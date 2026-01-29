#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);

# Test HTTP/2 support in Hypersonic

# Check nghttp2 availability
BEGIN {
    eval { require Hypersonic::Protocol::HTTP2 };
    if ($@ || !Hypersonic::Protocol::HTTP2::check_nghttp2()) {
        plan skip_all => 'nghttp2 not available';
    }
}

use Hypersonic::Protocol::HTTP2;

# Test 1: nghttp2 detection
subtest 'nghttp2 detection' => sub {
    my $info = Hypersonic::Protocol::HTTP2::check_nghttp2();
    ok($info, 'nghttp2 detected');
    ok(exists $info->{cflags}, 'cflags provided');
    ok(exists $info->{ldflags}, 'ldflags provided');
    like($info->{ldflags}, qr/-lnghttp2/, 'ldflags contains nghttp2');
};

# Test 2: Extra flags methods
subtest 'compiler flags' => sub {
    my $cflags = Hypersonic::Protocol::HTTP2::get_extra_cflags();
    my $ldflags = Hypersonic::Protocol::HTTP2::get_extra_ldflags();
    
    ok(defined $cflags, 'get_extra_cflags returns value');
    ok(defined $ldflags, 'get_extra_ldflags returns value');
    like($ldflags, qr/-lnghttp2/, 'ldflags contains library');
};

# Test 3: Protocol identifiers
subtest 'protocol info' => sub {
    is(Hypersonic::Protocol::HTTP2->protocol_id(), 'h2', 'protocol_id is h2');
    is(Hypersonic::Protocol::HTTP2->version_string(), 'HTTP/2', 'version string correct');
};

# Test 4: Code generation (with XS::JIT::Builder)
subtest 'code generation' => sub {
    eval { require XS::JIT::Builder };
    SKIP: {
        skip 'XS::JIT::Builder not available', 5 if $@;
        
        my $builder = XS::JIT::Builder->new;
        
        # Test includes
        Hypersonic::Protocol::HTTP2->gen_includes($builder);
        my $code = $builder->code;
        like($code, qr/#include <nghttp2\/nghttp2.h>/, 'includes nghttp2 header');
        like($code, qr/HYPERSONIC_HTTP2/, 'defines HTTP2 macro');
        
        # Test connection struct
        $builder = XS::JIT::Builder->new;
        Hypersonic::Protocol::HTTP2->gen_connection_struct($builder);
        $code = $builder->code;
        like($code, qr/H2Connection/, 'generates H2Connection struct');
        like($code, qr/nghttp2_session\*/, 'includes nghttp2_session pointer');
        like($code, qr/PROTO_HTTP2/, 'defines protocol constants');
    }
};

# Test 5: Preface check generation
subtest 'preface check code' => sub {
    eval { require XS::JIT::Builder };
    SKIP: {
        skip 'XS::JIT::Builder not available', 2 if $@;
        
        my $builder = XS::JIT::Builder->new;
        Hypersonic::Protocol::HTTP2->gen_connection_preface_check($builder);
        my $code = $builder->code;
        
        like($code, qr/PRI \* HTTP\/2\.0/, 'contains HTTP/2 preface');
        like($code, qr/is_h2_preface/, 'generates preface check function');
    }
};

# Test 6: Callbacks generation
subtest 'callbacks code' => sub {
    eval { require XS::JIT::Builder };
    SKIP: {
        skip 'XS::JIT::Builder not available', 4 if $@;
        
        my $builder = XS::JIT::Builder->new;
        Hypersonic::Protocol::HTTP2->gen_callbacks($builder);
        my $code = $builder->code;
        
        like($code, qr/h2_send_cb/, 'generates send callback');
        like($code, qr/h2_on_header_cb/, 'generates header callback');
        like($code, qr/h2_on_frame_recv_cb/, 'generates frame recv callback');
        like($code, qr/:method|:path/, 'handles pseudo-headers');
    }
};

# Test 7: Session init generation
subtest 'session init code' => sub {
    eval { require XS::JIT::Builder };
    SKIP: {
        skip 'XS::JIT::Builder not available', 3 if $@;
        
        my $builder = XS::JIT::Builder->new;
        Hypersonic::Protocol::HTTP2->gen_session_init($builder);
        my $code = $builder->code;
        
        like($code, qr/init_h2_callbacks/, 'generates callback init');
        like($code, qr/nghttp2_session_server_new/, 'creates server session');
        like($code, qr/NGHTTP2_SETTINGS/, 'submits settings');
    }
};

# Test 8: Response generation
subtest 'response code' => sub {
    eval { require XS::JIT::Builder };
    SKIP: {
        skip 'XS::JIT::Builder not available', 3 if $@;
        
        my $builder = XS::JIT::Builder->new;
        Hypersonic::Protocol::HTTP2->gen_response_sender($builder);
        my $code = $builder->code;
        
        like($code, qr/h2_send_static_response/, 'generates response sender');
        like($code, qr/nghttp2_submit_response/, 'uses submit_response');
        like($code, qr/:status/, 'sets status pseudo-header');
    }
};

# Test 9: Input processor
subtest 'input processor code' => sub {
    eval { require XS::JIT::Builder };
    SKIP: {
        skip 'XS::JIT::Builder not available', 2 if $@;
        
        my $builder = XS::JIT::Builder->new;
        Hypersonic::Protocol::HTTP2->gen_input_processor($builder);
        my $code = $builder->code;
        
        like($code, qr/h2_process_input/, 'generates input processor');
        like($code, qr/nghttp2_session_mem_recv/, 'uses mem_recv');
    }
};

# Test 10: HTTP/2 option in Hypersonic->new
subtest 'Hypersonic http2 option' => sub {
    eval { require Hypersonic };
    SKIP: {
        skip 'Hypersonic not loadable', 2 if $@;
        
        # HTTP/2 requires TLS
        eval {
            my $app = Hypersonic->new(http2 => 1);
        };
        like($@, qr/requires TLS/, 'HTTP/2 requires TLS option');
        
        # Can't test full compilation without valid cert/key
        ok(1, 'HTTP/2 option check passed');
    }
};

done_testing;
