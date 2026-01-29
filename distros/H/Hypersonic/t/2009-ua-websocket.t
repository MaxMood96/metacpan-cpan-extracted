#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

# Phase 9: WebSocket Client tests

use_ok('Hypersonic::UA::WebSocket');

# Test constants
is(Hypersonic::UA::WebSocket->MAX_WS_CLIENT_CONNS, 1024, 'MAX_WS_CLIENT_CONNS constant');
is(Hypersonic::UA::WebSocket->STATE_CONNECTING, 0, 'STATE_CONNECTING constant');
is(Hypersonic::UA::WebSocket->STATE_OPEN, 1, 'STATE_OPEN constant');
is(Hypersonic::UA::WebSocket->STATE_CLOSING, 2, 'STATE_CLOSING constant');
is(Hypersonic::UA::WebSocket->STATE_CLOSED, 3, 'STATE_CLOSED constant');
is(Hypersonic::UA::WebSocket->OP_CONTINUATION, 0x00, 'OP_CONTINUATION constant');
is(Hypersonic::UA::WebSocket->OP_TEXT, 0x01, 'OP_TEXT constant');
is(Hypersonic::UA::WebSocket->OP_BINARY, 0x02, 'OP_BINARY constant');
is(Hypersonic::UA::WebSocket->OP_CLOSE, 0x08, 'OP_CLOSE constant');
is(Hypersonic::UA::WebSocket->OP_PING, 0x09, 'OP_PING constant');
is(Hypersonic::UA::WebSocket->OP_PONG, 0x0A, 'OP_PONG constant');

# Test slot constants
is(Hypersonic::UA::WebSocket->SLOT_FD, 0, 'SLOT_FD constant');
is(Hypersonic::UA::WebSocket->SLOT_UA, 1, 'SLOT_UA constant');
is(Hypersonic::UA::WebSocket->SLOT_URL, 2, 'SLOT_URL constant');
is(Hypersonic::UA::WebSocket->SLOT_CALLBACKS, 3, 'SLOT_CALLBACKS constant');
is(Hypersonic::UA::WebSocket->SLOT_PROTOCOLS, 4, 'SLOT_PROTOCOLS constant');

# Test code generation
can_ok('Hypersonic::UA::WebSocket', 'generate_c_code');
can_ok('Hypersonic::UA::WebSocket', 'get_xs_functions');

my $xs_funcs = Hypersonic::UA::WebSocket->get_xs_functions();
is(ref($xs_funcs), 'HASH', 'get_xs_functions returns hash');
ok(exists $xs_funcs->{'Hypersonic::UA::WebSocket::new'}, 'has new function');
ok(exists $xs_funcs->{'Hypersonic::UA::WebSocket::connect'}, 'has connect function');
ok(exists $xs_funcs->{'Hypersonic::UA::WebSocket::send'}, 'has send function');
ok(exists $xs_funcs->{'Hypersonic::UA::WebSocket::send_binary'}, 'has send_binary function');
ok(exists $xs_funcs->{'Hypersonic::UA::WebSocket::ping'}, 'has ping function');
ok(exists $xs_funcs->{'Hypersonic::UA::WebSocket::pong'}, 'has pong function');
ok(exists $xs_funcs->{'Hypersonic::UA::WebSocket::close'}, 'has close function');
ok(exists $xs_funcs->{'Hypersonic::UA::WebSocket::recv_frame'}, 'has recv_frame function');
ok(exists $xs_funcs->{'Hypersonic::UA::WebSocket::state'}, 'has state function');
ok(exists $xs_funcs->{'Hypersonic::UA::WebSocket::is_open'}, 'has is_open function');
ok(exists $xs_funcs->{'Hypersonic::UA::WebSocket::fd'}, 'has fd function');
ok(exists $xs_funcs->{'Hypersonic::UA::WebSocket::cleanup'}, 'has cleanup function');

# Test gen_* methods
can_ok('Hypersonic::UA::WebSocket', 'gen_websocket_registry');
can_ok('Hypersonic::UA::WebSocket', 'gen_base64_codec');
can_ok('Hypersonic::UA::WebSocket', 'gen_frame_encoder');
can_ok('Hypersonic::UA::WebSocket', 'gen_frame_decoder');
can_ok('Hypersonic::UA::WebSocket', 'gen_xs_new');
can_ok('Hypersonic::UA::WebSocket', 'gen_xs_connect');
can_ok('Hypersonic::UA::WebSocket', 'gen_xs_send');
can_ok('Hypersonic::UA::WebSocket', 'gen_xs_send_binary');
can_ok('Hypersonic::UA::WebSocket', 'gen_xs_ping');
can_ok('Hypersonic::UA::WebSocket', 'gen_xs_pong');
can_ok('Hypersonic::UA::WebSocket', 'gen_xs_close');
can_ok('Hypersonic::UA::WebSocket', 'gen_xs_recv_frame');
can_ok('Hypersonic::UA::WebSocket', 'gen_xs_state');
can_ok('Hypersonic::UA::WebSocket', 'gen_xs_is_open');
can_ok('Hypersonic::UA::WebSocket', 'gen_xs_fd');
can_ok('Hypersonic::UA::WebSocket', 'gen_xs_cleanup');

# Test Perl callback methods
can_ok('Hypersonic::UA::WebSocket', 'on');
can_ok('Hypersonic::UA::WebSocket', '_get_callbacks');

# Test XS builder integration
SKIP: {
    eval { require XS::JIT::Builder };
    skip "XS::JIT::Builder not available", 5 if $@;

    my $builder = XS::JIT::Builder->new();
    ok($builder, 'Created XS::JIT::Builder');

    eval { Hypersonic::UA::WebSocket->generate_c_code($builder, {}) };
    ok(!$@, 'generate_c_code succeeded') or diag $@;

    my $code = $builder->code();
    ok(defined $code, 'Builder generated code');
    ok(length($code) > 0, 'Generated code is not empty');

    # Check key parts of generated code
    like($code, qr/WSClientConnection/, 'Has WSClientConnection struct');
    like($code, qr/ws_client_registry/, 'Has registry array');
    like($code, qr/ws_client_alloc_slot/, 'Has alloc_slot function');
    like($code, qr/ws_client_free_slot/, 'Has free_slot function');
    like($code, qr/ws_base64_encode/, 'Has base64 encoder');
    like($code, qr/ws_client_encode_frame/, 'Has frame encoder');
    like($code, qr/ws_client_decode_frame/, 'Has frame decoder');
    like($code, qr/WS_STATE_CONNECTING/, 'Has state constants');
    like($code, qr/WS_OP_TEXT/, 'Has opcode constants');
    like($code, qr/WS_GUID/, 'Has WebSocket GUID');
    like($code, qr/RAND_bytes/, 'Uses RAND_bytes for masking');
    like($code, qr/0x80/, 'Has mask bit');
}

done_testing();
