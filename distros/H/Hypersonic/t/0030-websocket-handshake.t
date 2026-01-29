#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 22;
use File::Basename;
use lib dirname(__FILE__) . '/../lib';
use XS::JIT::Builder;
use XS::JIT;

# ============================================================
# Test 1-3: Module loading
# ============================================================
use_ok('Hypersonic::Protocol::WebSocket');
use_ok('Hypersonic::WebSocket');
use_ok('Digest::SHA');

# ============================================================
# Compile WebSocket XS for testing (needed for WebSocket->new)
# ============================================================
{
    my $builder = XS::JIT::Builder->new;

    $builder->line('#include <string.h>')
      ->line('#include <sys/socket.h>')
      ->line('#include <ctype.h>')
      ->blank;

    require Hypersonic::Protocol::WebSocket::Frame;
    Hypersonic::Protocol::WebSocket::Frame->generate_c_code($builder);
    Hypersonic::WebSocket->generate_c_code($builder);

    XS::JIT->compile(
        code      => $builder->code,
        name      => 'Hypersonic::WebSocket',
        functions => Hypersonic::WebSocket->get_xs_functions(),
    );
}

# ============================================================
# Test 4-7: RFC 6455 Accept Key Calculation
# ============================================================
subtest 'RFC 6455 test vector' => sub {
    plan tests => 2;
    
    # From RFC 6455 Section 4.2.2
    my $client_key = 'dGhlIHNhbXBsZSBub25jZQ==';
    my $expected   = 's3pPLMBiTxaQ9kYGzzhZRbK+xOo=';
    
    my $accept = Hypersonic::Protocol::WebSocket->calc_accept_key($client_key);
    
    is($accept, $expected, 'accept key matches RFC example');
    is(length($accept), 28, 'accept key is 28 chars (SHA1 base64)');
};

subtest 'Accept key with various inputs' => sub {
    plan tests => 3;
    
    # Random valid keys (24 chars base64)
    my $key1 = 'x3JJHMbDL1EzLkh9GBhXDw==';
    my $accept1 = Hypersonic::Protocol::WebSocket->calc_accept_key($key1);
    like($accept1, qr/^[A-Za-z0-9+\/]+=*$/, 'accept is valid base64');
    
    my $key2 = 'HSmrc0sMlYUkAGmm5OPpG2==';
    my $accept2 = Hypersonic::Protocol::WebSocket->calc_accept_key($key2);
    isnt($accept1, $accept2, 'different keys give different accepts');
    
    # Empty key still produces output
    my $accept_empty = Hypersonic::Protocol::WebSocket->calc_accept_key('');
    ok($accept_empty, 'empty key produces some output');
};

subtest 'GUID constant' => sub {
    plan tests => 1;
    
    no warnings 'once';
    is($Hypersonic::Protocol::WebSocket::WS_GUID, 
       '258EAFA5-E914-47DA-95CA-C5AB0DC85B11',
       'GUID matches RFC 6455');
};

# ============================================================
# Test 8-12: Handshake Parsing (Perl side)
# ============================================================
subtest 'Parse valid handshake' => sub {
    plan tests => 5;
    
    my $request = <<'HTTP';
GET /chat HTTP/1.1
Host: server.example.com
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
Sec-WebSocket-Version: 13
HTTP
    
    my $hs = Hypersonic::Protocol::WebSocket->parse_handshake($request);
    
    ok($hs->{is_websocket}, 'detected as websocket');
    is($hs->{ws_key}, 'dGhlIHNhbXBsZSBub25jZQ==', 'extracted key');
    is($hs->{ws_version}, 13, 'extracted version');
    ok(!$hs->{ws_protocol}, 'no protocol');
    is(ref($hs), 'HASH', 'returns hashref');
};

subtest 'Parse handshake with protocol' => sub {
    plan tests => 2;
    
    my $request = <<'HTTP';
GET /chat HTTP/1.1
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
Sec-WebSocket-Version: 13
Sec-WebSocket-Protocol: chat, superchat
HTTP
    
    my $hs = Hypersonic::Protocol::WebSocket->parse_handshake($request);
    
    ok($hs->{is_websocket}, 'valid websocket');
    is($hs->{ws_protocol}, 'chat, superchat', 'extracted protocols');
};

subtest 'Reject non-websocket request' => sub {
    plan tests => 3;
    
    my $normal_get = "GET / HTTP/1.1\r\nHost: example.com\r\n\r\n";
    my $hs = Hypersonic::Protocol::WebSocket->parse_handshake($normal_get);
    ok(!$hs->{is_websocket}, 'normal GET rejected');
    
    # Missing Connection header
    my $no_conn = <<'HTTP';
GET /chat HTTP/1.1
Upgrade: websocket
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
Sec-WebSocket-Version: 13
HTTP
    $hs = Hypersonic::Protocol::WebSocket->parse_handshake($no_conn);
    ok(!$hs->{is_websocket}, 'missing Connection rejected');
    
    # Wrong version
    my $wrong_ver = <<'HTTP';
GET /chat HTTP/1.1
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
Sec-WebSocket-Version: 8
HTTP
    $hs = Hypersonic::Protocol::WebSocket->parse_handshake($wrong_ver);
    ok(!$hs->{is_websocket}, 'version 8 rejected');
};

subtest 'Case insensitive headers' => sub {
    plan tests => 1;
    
    my $request = <<'HTTP';
GET /chat HTTP/1.1
upgrade: WEBSOCKET
connection: upgrade
sec-websocket-key: dGhlIHNhbXBsZSBub25jZQ==
sec-websocket-version: 13
HTTP
    
    my $hs = Hypersonic::Protocol::WebSocket->parse_handshake($request);
    ok($hs->{is_websocket}, 'case-insensitive parsing works');
};

# ============================================================
# Test 13-15: Key Validation
# ============================================================
subtest 'Valid key format' => sub {
    plan tests => 3;
    
    ok(Hypersonic::Protocol::WebSocket->validate_key('dGhlIHNhbXBsZSBub25jZQ=='),
       'RFC example key valid');
    ok(Hypersonic::Protocol::WebSocket->validate_key('x3JJHMbDL1EzLkh9GBhXDw=='),
       'random valid key');
    ok(Hypersonic::Protocol::WebSocket->validate_key('AAAAAAAAAAAAAAAAAAAAAA=='),
       'all A key valid');
};

subtest 'Invalid key formats' => sub {
    plan tests => 4;
    
    ok(!Hypersonic::Protocol::WebSocket->validate_key(''),
       'empty key invalid');
    ok(!Hypersonic::Protocol::WebSocket->validate_key('tooshort=='),
       'short key invalid');
    ok(!Hypersonic::Protocol::WebSocket->validate_key('dGhlIHNhbXBsZSBub25jZQ'),
       'missing padding invalid');
    ok(!Hypersonic::Protocol::WebSocket->validate_key('dGhlIHNhbXBsZSBub25jZQ==extra'),
       'too long invalid');
};

# ============================================================
# Test 16-18: Response Building
# ============================================================
subtest 'Build handshake response' => sub {
    plan tests => 5;
    
    my $response = Hypersonic::Protocol::WebSocket->build_response(
        key => 'dGhlIHNhbXBsZSBub25jZQ=='
    );
    
    like($response, qr/^HTTP\/1\.1 101 Switching Protocols/, 'correct status');
    like($response, qr/Upgrade: websocket/i, 'upgrade header');
    like($response, qr/Connection: Upgrade/i, 'connection header');
    like($response, qr/Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK\+xOo=/, 'correct accept');
    like($response, qr/\r\n\r\n$/, 'ends with blank line');
};

subtest 'Response with protocol' => sub {
    plan tests => 1;
    
    my $response = Hypersonic::Protocol::WebSocket->build_response(
        key      => 'dGhlIHNhbXBsZSBub25jZQ==',
        protocol => 'chat'
    );
    
    like($response, qr/Sec-WebSocket-Protocol: chat/, 'includes protocol');
};

subtest 'Response without key fails' => sub {
    plan tests => 1;
    
    my $response = Hypersonic::Protocol::WebSocket->build_response();
    is($response, '', 'empty response without key');
};

# ============================================================
# Test 19-22: C Code Generation
# ============================================================
subtest 'gen_accept_key C code' => sub {
    plan tests => 4;
    
    my $builder = XS::JIT::Builder->new;
    Hypersonic::Protocol::WebSocket->gen_accept_key($builder);
    my $code = $builder->code;
    
    like($code, qr/calc_websocket_accept/, 'function defined');
    like($code, qr/SHA1/, 'uses SHA1');
    like($code, qr/258EAFA5-E914-47DA-95CA-C5AB0DC85B11/, 'includes GUID');
    like($code, qr/BIO_f_base64/, 'uses OpenSSL base64');
};

subtest 'gen_handshake_parser C code' => sub {
    plan tests => 5;
    
    my $builder = XS::JIT::Builder->new;
    Hypersonic::Protocol::WebSocket->gen_handshake_parser($builder);
    my $code = $builder->code;
    
    like($code, qr/parse_ws_handshake/, 'function defined');
    like($code, qr/Sec-WebSocket-Key/, 'extracts key');
    like($code, qr/Sec-WebSocket-Version/, 'extracts version');
    like($code, qr/ws_version == 13/, 'checks version 13');
    like($code, qr/WSHandshake/, 'uses struct type');
};

subtest 'gen_handshake_response C code' => sub {
    plan tests => 4;
    
    my $builder = XS::JIT::Builder->new;
    Hypersonic::Protocol::WebSocket->gen_handshake_response($builder);
    my $code = $builder->code;
    
    like($code, qr/send_ws_handshake_response/, 'function defined');
    like($code, qr/101 Switching Protocols/, 'correct status');
    like($code, qr/Sec-WebSocket-Accept/, 'accept header');
    like($code, qr/Sec-WebSocket-Protocol/, 'protocol header');
};

subtest 'gen_error_responses C code' => sub {
    plan tests => 3;
    
    my $builder = XS::JIT::Builder->new;
    Hypersonic::Protocol::WebSocket->gen_error_responses($builder);
    my $code = $builder->code;
    
    like($code, qr/send_ws_bad_request.*400 Bad Request/s, '400 response');
    like($code, qr/send_ws_upgrade_required.*426 Upgrade Required/s, '426 response');
    like($code, qr/send_ws_forbidden.*403 Forbidden/s, '403 response');
};

# ============================================================
# Test 23-25: WebSocket Object
# ============================================================

# Mock stream for testing
{
    package MockWSStream;
    sub new { bless { writes => [], fd => $_[1] // 100 }, shift }
    sub is_finished { 0 }
    sub fd { $_[0]->{fd} }
    sub _raw_write { push @{$_[0]->{writes}}, $_[1]; $_[0] }
}

subtest 'WebSocket object creation' => sub {
    plan tests => 5;

    my $stream = MockWSStream->new(101);
    my $ws = Hypersonic::WebSocket->new($stream, fd => 101, protocol => 'chat');

    isa_ok($ws, 'Hypersonic::WebSocket');
    is($ws->state, Hypersonic::WebSocket->CONNECTING, 'starts connecting');
    is($ws->protocol, 'chat', 'protocol set');
    ok(!$ws->is_open, 'not open yet');
    is($ws->stream, $stream, 'stream accessible');
};

subtest 'WebSocket event handlers' => sub {
    plan tests => 3;

    my $stream = MockWSStream->new(102);
    my $ws = Hypersonic::WebSocket->new($stream, fd => 102);

    my $opened = 0;
    my $message_received;

    $ws->on(open => sub { $opened = 1 });
    $ws->on(message => sub { $message_received = shift });

    # Simulate accepting handshake
    my $hs = {
        is_websocket => 1,
        ws_key       => 'dGhlIHNhbXBsZSBub25jZQ==',
        ws_version   => 13,
    };

    $ws->accept($hs);

    ok($opened, 'open event fired');
    ok($ws->is_open, 'connection now open');

    # Simulate receiving message
    $ws->emit('message', 'hello');
    is($message_received, 'hello', 'message handler called');
};

subtest 'WebSocket close handling' => sub {
    plan tests => 4;

    my $stream = MockWSStream->new(103);
    my $ws = Hypersonic::WebSocket->new($stream, fd => 103);

    my ($close_code, $close_reason);
    $ws->on(close => sub { ($close_code, $close_reason) = @_ });

    # Accept and open
    $ws->accept({
        is_websocket => 1,
        ws_key       => 'dGhlIHNhbXBsZSBub25jZQ==',
        ws_version   => 13,
    });

    # Initiate close
    $ws->close(1000, 'Normal closure');

    ok($ws->is_closing, 'connection is closing');
    ok($ws->state == Hypersonic::WebSocket->CLOSING, 'state is CLOSING (close code stored in registry)');

    # Handle close response
    $ws->handle_close(1000, 'Normal closure');

    ok($ws->is_closed, 'connection now closed');
    is($close_code, 1000, 'close event received code');
};
