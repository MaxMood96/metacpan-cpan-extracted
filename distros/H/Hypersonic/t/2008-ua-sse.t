#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

sub lives_ok(&$) {
    my ($code, $msg) = @_;
    eval { $code->() };
    ok(!$@, $msg) or diag("Error: $@");
}

use_ok('Hypersonic::UA::SSE');

subtest 'Constants' => sub {
    is(Hypersonic::UA::SSE->MAX_SSE_CONNS, 256, 'MAX_SSE_CONNS default');
    is(Hypersonic::UA::SSE->SLOT_FD, 0, 'SLOT_FD');
    is(Hypersonic::UA::SSE->SLOT_CALLBACKS, 2, 'SLOT_CALLBACKS');
};

subtest 'XS function registry' => sub {
    my $funcs = Hypersonic::UA::SSE->get_xs_functions();
    
    ok($funcs, 'get_xs_functions returns hashref');
    
    my @expected = qw(
        Hypersonic::UA::SSE::new
        Hypersonic::UA::SSE::connect
        Hypersonic::UA::SSE::parse_events
        Hypersonic::UA::SSE::recv_chunk
        Hypersonic::UA::SSE::get_last_id
        Hypersonic::UA::SSE::set_retry
        Hypersonic::UA::SSE::close
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
        Hypersonic::UA::SSE->generate_c_code($builder, {});
    } 'generate_c_code runs without error';
    
    my $code = $builder->code;
    
    like($code, qr/SSEConnection/, 'Contains SSEConnection struct');
    like($code, qr/sse_registry/, 'Contains registry');
    like($code, qr/sse_find/, 'Contains find helper');
    like($code, qr/sse_alloc/, 'Contains alloc helper');
    like($code, qr/sse_free/, 'Contains free helper');
    like($code, qr/sse_buffer_append/, 'Contains buffer_append helper');
    like($code, qr/sse_parse_events/, 'Contains parse_events function');
    like($code, qr/last_id/, 'Contains last_id field');
    like($code, qr/event_type/, 'Contains event_type field');
    like($code, qr/retry_ms/, 'Contains retry_ms field');
    like($code, qr/xs_sse_new/, 'Contains new XS function');
    like($code, qr/xs_sse_parse_events/, 'Contains parse_events XS function');
    like($code, qr/xs_sse_recv_chunk/, 'Contains recv_chunk XS function');
};

done_testing;
