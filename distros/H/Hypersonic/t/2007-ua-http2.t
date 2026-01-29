#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

sub lives_ok(&$) {
    my ($code, $msg) = @_;
    eval { $code->() };
    ok(!$@, $msg) or diag("Error: $@");
}

use_ok('Hypersonic::UA::HTTP2');

subtest 'Constants' => sub {
    is(Hypersonic::UA::HTTP2->MAX_H2_SESSIONS, 100, 'MAX_H2_SESSIONS default');
    is(Hypersonic::UA::HTTP2->MAX_STREAMS_PER_SESSION, 100, 'MAX_STREAMS_PER_SESSION default');
};

subtest 'nghttp2 detection' => sub {
    my $available = Hypersonic::UA::HTTP2::check_nghttp2();
    ok(defined $available, 'check_nghttp2 returns defined value');
    diag("nghttp2 available: " . ($available ? "yes" : "no"));

    if ($available) {
        my $cflags = Hypersonic::UA::HTTP2::get_extra_cflags();
        ok(defined $cflags, 'get_extra_cflags returns value');

        my $ldflags = Hypersonic::UA::HTTP2::get_extra_ldflags();
        ok(defined $ldflags, 'get_extra_ldflags returns value');
        like($ldflags, qr/nghttp2/i, 'ldflags contain nghttp2');
        diag("LDFLAGS: $ldflags");
    }
};

subtest 'XS function registry' => sub {
    my $funcs = Hypersonic::UA::HTTP2->get_xs_functions();
    
    ok($funcs, 'get_xs_functions returns hashref');
    
    my @expected = qw(
        Hypersonic::UA::HTTP2::session_new
        Hypersonic::UA::HTTP2::submit_request
        Hypersonic::UA::HTTP2::receive
        Hypersonic::UA::HTTP2::session_close
        Hypersonic::UA::HTTP2::is_complete
    );
    
    for my $func (@expected) {
        ok(exists $funcs->{$func}, "Function $func registered");
        ok($funcs->{$func}{source}, "Function $func has source");
        ok($funcs->{$func}{is_xs_native}, "Function $func is XS native");
    }
};

subtest 'C code generation' => sub {
    plan skip_all => 'XS::JIT::Builder required' 
        unless eval { require XS::JIT::Builder; 1 };
    
    my $builder = XS::JIT::Builder->new;
    
    lives_ok {
        Hypersonic::UA::HTTP2->generate_c_code($builder, {});
    } 'generate_c_code runs without error';
    
    my $code = $builder->code;
    
    like($code, qr/H2Stream/, 'Contains H2Stream struct');
    like($code, qr/H2Session/, 'Contains H2Session struct');
    like($code, qr/h2_registry/, 'Contains registry');
    like($code, qr/h2_find_session/, 'Contains find_session helper');
    like($code, qr/h2_alloc_session/, 'Contains alloc_session helper');
    like($code, qr/h2_find_stream/, 'Contains find_stream helper');
    like($code, qr/h2_send_cb/, 'Contains send callback');
    like($code, qr/h2_recv_cb/, 'Contains recv callback');
    like($code, qr/h2_on_header_cb/, 'Contains header callback');
    like($code, qr/h2_on_data_chunk_cb/, 'Contains data chunk callback');
    like($code, qr/h2_on_stream_close_cb/, 'Contains stream close callback');
    like($code, qr/nghttp2_session_client_new/, 'Uses client session');
    like($code, qr/nghttp2_submit_request/, 'Contains submit_request');
};

done_testing;
