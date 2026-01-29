#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 27;
use File::Basename;
use lib dirname(__FILE__) . '/../lib';
use XS::JIT::Builder;

# ============================================================
# Test 1-2: Module loading
# ============================================================
use_ok('Hypersonic::Protocol::WebSocket::Frame');

my $Frame = 'Hypersonic::Protocol::WebSocket::Frame';

# ============================================================
# Test 3-6: Constants
# ============================================================
subtest 'Opcodes' => sub {
    plan tests => 6;
    
    my $ops = $Frame->opcodes;
    is($ops->{text}, 0x1, 'text opcode');
    is($ops->{binary}, 0x2, 'binary opcode');
    is($ops->{close}, 0x8, 'close opcode');
    is($ops->{ping}, 0x9, 'ping opcode');
    is($ops->{pong}, 0xA, 'pong opcode');
    is($ops->{continuation}, 0x0, 'continuation opcode');
};

subtest 'Close codes' => sub {
    plan tests => 5;
    
    my $codes = $Frame->close_codes;
    is($codes->{normal}, 1000, 'normal close');
    is($codes->{going_away}, 1001, 'going away');
    is($codes->{protocol_error}, 1002, 'protocol error');
    is($codes->{message_too_big}, 1009, 'message too big');
    is($codes->{internal_error}, 1011, 'internal error');
};

# ============================================================
# Test 5-10: Perl Frame Encoding
# ============================================================
subtest 'Encode small text frame' => sub {
    plan tests => 4;
    
    my $frame = $Frame->encode_frame(
        opcode => 0x1,
        fin    => 1,
        data   => 'Hello',
    );
    
    my @bytes = unpack('C*', $frame);
    is($bytes[0], 0x81, 'FIN + text opcode');
    is($bytes[1], 5, 'payload length 5');
    is(length($frame), 7, 'total frame size');
    is(substr($frame, 2), 'Hello', 'payload matches');
};

subtest 'Encode masked frame (client mode)' => sub {
    plan tests => 3;
    
    my $frame = $Frame->encode_frame(
        opcode => 0x1,
        fin    => 1,
        data   => 'Test',
        mask   => [0x37, 0xfa, 0x21, 0x3d],
    );
    
    my @bytes = unpack('C*', $frame);
    is($bytes[1] & 0x80, 0x80, 'mask bit set');
    is($bytes[1] & 0x7F, 4, 'payload length');
    is(length($frame), 10, 'header(2) + mask(4) + payload(4)');
};

subtest 'Encode medium payload (126)' => sub {
    plan tests => 3;
    
    my $data = 'x' x 200;
    my $frame = $Frame->encode_frame(
        opcode => 0x1,
        fin    => 1,
        data   => $data,
    );
    
    my @bytes = unpack('C*', $frame);
    is($bytes[1], 126, 'length marker 126');
    is(($bytes[2] << 8) | $bytes[3], 200, 'extended length correct');
    is(length($frame), 4 + 200, 'total size correct');
};

subtest 'Encode large payload (127)' => sub {
    plan tests => 2;
    
    my $data = 'x' x 70000;
    my $frame = $Frame->encode_frame(
        opcode => 0x1,
        fin    => 1,
        data   => $data,
    );
    
    my @bytes = unpack('C*', $frame);
    is($bytes[1], 127, 'length marker 127');
    is(length($frame), 10 + 70000, 'total size correct');
};

subtest 'Encode fragmented frame' => sub {
    plan tests => 2;
    
    # First fragment (not FIN)
    my $frame1 = $Frame->encode_frame(
        opcode => 0x1,  # text
        fin    => 0,
        data   => 'Hello',
    );
    
    my @bytes = unpack('C*', $frame1);
    is($bytes[0], 0x01, 'no FIN bit, text opcode');
    
    # Continuation (with FIN)
    my $frame2 = $Frame->encode_frame(
        opcode => 0x0,  # continuation
        fin    => 1,
        data   => ' World',
    );
    
    @bytes = unpack('C*', $frame2);
    is($bytes[0], 0x80, 'FIN + continuation opcode');
};

subtest 'Encode binary frame' => sub {
    plan tests => 2;
    
    my $frame = $Frame->encode_frame(
        opcode => 0x2,
        fin    => 1,
        data   => "\x00\x01\x02\x03",
    );
    
    my @bytes = unpack('C*', $frame);
    is($bytes[0], 0x82, 'FIN + binary opcode');
    is($bytes[1], 4, 'payload length');
};

# ============================================================
# Test 11-16: Perl Frame Decoding
# ============================================================
subtest 'Decode small text frame' => sub {
    plan tests => 6;
    
    my $raw = pack('C*', 0x81, 5) . 'Hello';
    my $frame = $Frame->decode_frame($raw);
    
    ok($frame, 'frame decoded');
    is($frame->{fin}, 1, 'FIN bit');
    is($frame->{opcode}, 0x1, 'text opcode');
    is($frame->{masked}, 0, 'not masked');
    is($frame->{payload_length}, 5, 'payload length');
    is($frame->{payload}, 'Hello', 'payload data');
};

subtest 'Decode masked frame' => sub {
    plan tests => 3;
    
    # Masked "Test" with mask [0x37, 0xfa, 0x21, 0x3d]
    my $mask = [0x37, 0xfa, 0x21, 0x3d];
    my @masked_payload;
    my @text = unpack('C*', 'Test');
    for my $i (0..3) {
        push @masked_payload, $text[$i] ^ $mask->[$i];
    }
    
    my $raw = pack('C*', 0x81, 0x84, @$mask, @masked_payload);
    my $frame = $Frame->decode_frame($raw);
    
    ok($frame, 'frame decoded');
    is($frame->{masked}, 1, 'masked flag');
    is($frame->{payload}, 'Test', 'payload unmasked correctly');
};

subtest 'Decode medium payload frame' => sub {
    plan tests => 2;
    
    my $data = 'x' x 200;
    my $raw = pack('C*', 0x81, 126, 0, 200) . $data;
    my $frame = $Frame->decode_frame($raw);
    
    is($frame->{payload_length}, 200, 'extended length');
    is(length($frame->{payload}), 200, 'payload size');
};

subtest 'Decode large payload frame' => sub {
    plan tests => 2;
    
    my $data = 'x' x 70000;
    my @len_bytes;
    my $len = 70000;
    for my $i (0..7) {
        unshift @len_bytes, ($len >> (8*$i)) & 0xFF;
    }
    
    my $raw = pack('C*', 0x81, 127, @len_bytes) . $data;
    my $frame = $Frame->decode_frame($raw);
    
    is($frame->{payload_length}, 70000, '64-bit length');
    is(length($frame->{payload}), 70000, 'payload size');
};

subtest 'Decode incomplete frame' => sub {
    plan tests => 3;
    
    # Only header, missing payload
    my $raw = pack('C*', 0x81, 10);
    my $frame = $Frame->decode_frame($raw);
    is($frame, undef, 'incomplete returns undef');
    
    # Just one byte
    $frame = $Frame->decode_frame(pack('C', 0x81));
    is($frame, undef, 'single byte returns undef');
    
    # Empty
    $frame = $Frame->decode_frame('');
    is($frame, undef, 'empty returns undef');
};

subtest 'Decode control frames' => sub {
    plan tests => 4;
    
    # Ping
    my $ping = pack('C*', 0x89, 0);
    my $frame = $Frame->decode_frame($ping);
    is($frame->{opcode}, 0x9, 'ping opcode');
    
    # Pong
    my $pong = pack('C*', 0x8A, 4) . 'data';
    $frame = $Frame->decode_frame($pong);
    is($frame->{opcode}, 0xA, 'pong opcode');
    is($frame->{payload}, 'data', 'pong payload');
    
    # Close
    my $close = pack('C*', 0x88, 2, 0x03, 0xE8);  # code 1000
    $frame = $Frame->decode_frame($close);
    is($frame->{opcode}, 0x8, 'close opcode');
};

# ============================================================
# Test 17-18: Close Frame Helpers
# ============================================================
subtest 'Encode close frame' => sub {
    plan tests => 3;
    
    my $frame = $Frame->encode_close(1000, 'Normal');
    my @bytes = unpack('C*', $frame);
    
    is($bytes[0], 0x88, 'FIN + close opcode');
    is($bytes[2], 0x03, 'code high byte');
    is($bytes[3], 0xE8, 'code low byte (1000)');
};

subtest 'Parse close payload' => sub {
    plan tests => 4;
    
    # Code only
    my ($code, $reason) = $Frame->parse_close(pack('C*', 0x03, 0xE9));
    is($code, 1001, 'code 1001');
    is($reason, '', 'no reason');
    
    # Code + reason
    ($code, $reason) = $Frame->parse_close(pack('C*', 0x03, 0xEA) . 'bye');
    is($code, 1002, 'code 1002');
    is($reason, 'bye', 'reason extracted');
};

# ============================================================
# Test 19-24: C Code Generation
# ============================================================
subtest 'gen_frame_constants C code' => sub {
    plan tests => 6;
    
    my $builder = XS::JIT::Builder->new;
    $Frame->gen_frame_constants($builder);
    my $code = $builder->code;
    
    like($code, qr/WS_OP_TEXT\s+0x1/, 'text opcode');
    like($code, qr/WS_OP_BINARY\s+0x2/, 'binary opcode');
    like($code, qr/WS_OP_CLOSE\s+0x8/, 'close opcode');
    like($code, qr/WS_FIN\s+0x80/, 'FIN flag');
    like($code, qr/WS_CLOSE_NORMAL\s+1000/, 'close normal');
    like($code, qr/typedef struct.*WSFrame/s, 'WSFrame struct');
};

subtest 'gen_frame_decoder C code' => sub {
    plan tests => 5;
    
    my $builder = XS::JIT::Builder->new;
    $Frame->gen_frame_decoder($builder);
    my $code = $builder->code;
    
    like($code, qr/ws_decode_frame/, 'function defined');
    like($code, qr/frame->fin.*0x80/s, 'FIN extraction');
    like($code, qr/mask_key\[i & 3\]/, 'XOR unmasking');
    like($code, qr/len7 == 126/, 'medium length check');
    like($code, qr/64-bit extended length/, 'large length check');
};

subtest 'gen_frame_encoder C code' => sub {
    plan tests => 5;
    
    my $builder = XS::JIT::Builder->new;
    $Frame->gen_frame_encoder($builder);
    my $code = $builder->code;
    
    like($code, qr/ws_encode_frame/, 'main function');
    like($code, qr/ws_encode_text/, 'text helper');
    like($code, qr/ws_encode_binary/, 'binary helper');
    like($code, qr/ws_encode_close/, 'close helper');
    like($code, qr/ws_encode_ping.*ws_encode_pong/s, 'ping/pong helpers');
};

subtest 'gen_control_handler C code' => sub {
    plan tests => 4;
    
    my $builder = XS::JIT::Builder->new;
    $Frame->gen_control_handler($builder);
    my $code = $builder->code;
    
    like($code, qr/ws_handle_control/, 'function defined');
    like($code, qr/WS_OP_PING.*ws_encode_pong/s, 'ping response');
    like($code, qr/WS_OP_PONG/, 'pong handling');
    like($code, qr/WS_OP_CLOSE.*return -1/s, 'close handling');
};

subtest 'gen_fragment_handler C code' => sub {
    plan tests => 4;
    
    my $builder = XS::JIT::Builder->new;
    $Frame->gen_fragment_handler($builder);
    my $code = $builder->code;
    
    like($code, qr/WSFragmentBuffer/, 'struct defined');
    like($code, qr/ws_fragment_init/, 'init function');
    like($code, qr/ws_fragment_append/, 'append function');
    like($code, qr/realloc/, 'buffer growth');
};

subtest 'gen_frame_processor C code' => sub {
    plan tests => 4;
    
    my $builder = XS::JIT::Builder->new;
    $Frame->gen_frame_processor($builder);
    my $code = $builder->code;
    
    like($code, qr/ws_process_data/, 'function defined');
    like($code, qr/ws_decode_frame/, 'uses decoder');
    like($code, qr/ws_handle_control/, 'uses control handler');
    like($code, qr/on_message/, 'message callback');
};

# ============================================================
# Test 25-28: Round-trip and Edge Cases
# ============================================================
subtest 'Round-trip text message' => sub {
    plan tests => 2;
    
    my $original = "Hello, WebSocket!";
    my $encoded = $Frame->encode_frame(
        opcode => 0x1,
        fin    => 1,
        data   => $original,
    );
    
    my $decoded = $Frame->decode_frame($encoded);
    is($decoded->{payload}, $original, 'payload matches');
    is($decoded->{opcode}, 0x1, 'opcode preserved');
};

subtest 'Round-trip masked message' => sub {
    plan tests => 2;
    
    my $original = "Masked data";
    my $encoded = $Frame->encode_frame(
        opcode => 0x1,
        fin    => 1,
        data   => $original,
        mask   => [0xAB, 0xCD, 0xEF, 0x12],
    );
    
    my $decoded = $Frame->decode_frame($encoded);
    is($decoded->{payload}, $original, 'unmasked correctly');
    is($decoded->{masked}, 1, 'was masked');
};

subtest 'Empty payload' => sub {
    plan tests => 3;
    
    my $frame = $Frame->encode_frame(
        opcode => 0x1,
        fin    => 1,
        data   => '',
    );
    
    my @bytes = unpack('C*', $frame);
    is($bytes[1], 0, 'zero length');
    is(length($frame), 2, 'just header');
    
    my $decoded = $Frame->decode_frame($frame);
    is($decoded->{payload}, '', 'empty payload decoded');
};

subtest 'Binary data with nulls' => sub {
    plan tests => 2;
    
    my $binary = "\x00\x01\x00\xFF\x00";
    my $frame = $Frame->encode_frame(
        opcode => 0x2,
        fin    => 1,
        data   => $binary,
    );
    
    my $decoded = $Frame->decode_frame($frame);
    is($decoded->{opcode}, 0x2, 'binary opcode');
    is($decoded->{payload}, $binary, 'binary data preserved');
};
