#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use XS::JIT::Builder;
use XS::JIT;

# ============================================================
# Phase 4: Server-Sent Events (SSE) Tests
# ============================================================

plan tests => 20;

# ============================================================
# Test 1-3: Module loads
# ============================================================
use_ok('Hypersonic::Protocol::SSE');
use_ok('Hypersonic::SSE');
use_ok('Hypersonic::Stream');

# ============================================================
# Compile Stream and SSE XS for testing
# ============================================================
{
    my $builder = XS::JIT::Builder->new;

    # Platform-specific includes for socket operations
    $builder->line('#include <string.h>')
      ->line('#include <sys/types.h>')   # Required before sys/socket.h on BSD
      ->line('#include <sys/socket.h>')
      ->line('#include <unistd.h>')      # For write/close
      ->blank;

    # Handle MSG_NOSIGNAL which doesn't exist on BSD/macOS
    $builder->line('#ifndef MSG_NOSIGNAL')
      ->line('#define MSG_NOSIGNAL 0')
      ->line('#endif')
      ->blank;

    Hypersonic::Stream->generate_c_code($builder);

    XS::JIT->compile(
        code      => $builder->code,
        name      => 'Hypersonic::Stream',
        functions => Hypersonic::Stream->get_xs_functions,
    );
}

{
    my $builder = XS::JIT::Builder->new;

    $builder->line('#include <string.h>')
      ->blank;

    Hypersonic::SSE->generate_c_code($builder);

    XS::JIT->compile(
        code      => $builder->code,
        name      => 'Hypersonic::SSE',
        functions => Hypersonic::SSE->get_xs_functions,
    );
}

# ============================================================
# Test 4-7: Protocol::SSE Perl-side formatting
# ============================================================
subtest 'format_event basic' => sub {
    plan tests => 4;
    
    my $event = Hypersonic::Protocol::SSE->format_event(
        type => 'message',
        data => 'Hello World',
    );
    
    like($event, qr/^event: message\n/, 'has event type');
    like($event, qr/data: Hello World\n/, 'has data');
    like($event, qr/\n\n$/, 'ends with blank line');
    unlike($event, qr/id:/, 'no id when not specified');
};

subtest 'format_event with id' => sub {
    plan tests => 2;
    
    my $event = Hypersonic::Protocol::SSE->format_event(
        type => 'update',
        data => 'test',
        id   => '123',
    );
    
    like($event, qr/id: 123\n/, 'has id');
    like($event, qr/event: update\n/, 'has event type');
};

subtest 'format_event multiline data' => sub {
    plan tests => 3;
    
    my $event = Hypersonic::Protocol::SSE->format_event(
        data => "line1\nline2\nline3",
    );
    
    like($event, qr/data: line1\n/, 'first line');
    like($event, qr/data: line2\n/, 'second line');
    like($event, qr/data: line3\n/, 'third line');
};

subtest 'format helpers' => sub {
    plan tests => 3;
    
    my $keepalive = Hypersonic::Protocol::SSE->format_keepalive();
    like($keepalive, qr/^: keepalive\n\n$/, 'keepalive format');
    
    my $retry = Hypersonic::Protocol::SSE->format_retry(3000);
    like($retry, qr/^retry: 3000\n\n$/, 'retry format');
    
    my $comment = Hypersonic::Protocol::SSE->format_comment('test');
    like($comment, qr/^: test\n\n$/, 'comment format');
};

# ============================================================
# Test 8-11: Protocol::SSE C code generation
# ============================================================
subtest 'gen_event_formatter C code' => sub {
    plan tests => 5;
    
    require XS::JIT::Builder;
    my $builder = XS::JIT::Builder->new;
    
    Hypersonic::Protocol::SSE->gen_event_formatter($builder);
    my $code = $builder->code;
    
    like($code, qr/format_sse_event/, 'function defined');
    like($code, qr/event: %s/, 'event type format');
    like($code, qr/data: /, 'data format');
    like($code, qr/id: %s/, 'id format');
    like($code, qr/while \(\*p\)/, 'multiline loop');
};

subtest 'gen_keepalive C code' => sub {
    plan tests => 2;
    
    require XS::JIT::Builder;
    my $builder = XS::JIT::Builder->new;
    
    Hypersonic::Protocol::SSE->gen_keepalive($builder);
    my $code = $builder->code;
    
    like($code, qr/format_sse_keepalive/, 'function defined');
    like($code, qr/: keepalive/, 'keepalive comment');
};

subtest 'gen_retry C code' => sub {
    plan tests => 2;
    
    require XS::JIT::Builder;
    my $builder = XS::JIT::Builder->new;
    
    Hypersonic::Protocol::SSE->gen_retry($builder);
    my $code = $builder->code;
    
    like($code, qr/format_sse_retry/, 'function defined');
    like($code, qr/retry: %d/, 'retry format');
};

subtest 'generate_c_code C code' => sub {
    plan tests => 4;
    
    require XS::JIT::Builder;
    my $builder = XS::JIT::Builder->new;
    
    Hypersonic::Protocol::SSE->generate_c_code($builder);
    my $code = $builder->code;
    
    like($code, qr/format_sse_event/, 'has event formatter');
    like($code, qr/format_sse_keepalive/, 'has keepalive');
    like($code, qr/format_sse_retry/, 'has retry');
    like($code, qr/format_sse_comment/, 'has comment');
};

# ============================================================
# Test 12-15: Hypersonic::SSE wrapper
# ============================================================
subtest 'SSE object creation' => sub {
    plan tests => 4;
    
    my $stream = Hypersonic::Stream->new(fd => 5);
    my $sse = Hypersonic::SSE->new($stream);
    
    isa_ok($sse, 'Hypersonic::SSE');
    is($sse->stream, $stream, 'stream accessor');
    ok(!$sse->is_started, 'not started initially');
    is($sse->event_count, 0, 'no events sent');
};

# Define mock stream packages to avoid "used only once" warnings
{
    package MockStream;
    sub new { bless { state => 0, writes => [] }, shift }
    sub is_finished { 0 }
    sub write { push @{$_[0]->{writes}}, $_[1]; $_[0] }
    sub headers { $_[0]->{started} = 1; $_[0] }
}
{
    package MockStream2;
    sub new { bless { state => 0, writes => [] }, shift }
    sub is_finished { 0 }
    sub write { push @{$_[0]->{writes}}, $_[1]; $_[0] }
    sub headers { $_[0] }
}
{
    package MockStream3;
    sub new { bless { state => 0, writes => [] }, shift }
    sub is_finished { 0 }
    sub write { push @{$_[0]->{writes}}, $_[1]; $_[0] }
    sub headers { $_[0] }
}
{
    package MockStream4;
    our $headers_set;
    sub new { bless { state => 0 }, shift }
    sub is_finished { 0 }
    sub write { $_[0] }
    sub headers { $headers_set = $_[2]; $_[0] }
}
{
    package MockStream5;
    sub new { bless { state => 0 }, shift }
    sub is_finished { 0 }
}

subtest 'SSE event sends correctly' => sub {
    plan tests => 2;
    
    my $mock_stream = MockStream->new;
    
    my $sse = Hypersonic::SSE->new($mock_stream);
    $sse->event(type => 'test', data => 'hello');
    
    is($sse->event_count, 1, 'event count incremented');
    like($mock_stream->{writes}[0], qr/event: test/, 'event was written');
};

subtest 'SSE data shorthand' => sub {
    plan tests => 1;
    
    my $mock_stream = MockStream2->new;
    
    my $sse = Hypersonic::SSE->new($mock_stream);
    $sse->data('simple message');
    
    like($mock_stream->{writes}[0], qr/data: simple message/, 'data was written');
};

subtest 'SSE keepalive' => sub {
    plan tests => 1;
    
    my $mock_stream = MockStream3->new;
    
    my $sse = Hypersonic::SSE->new($mock_stream);
    $sse->keepalive();
    
    like($mock_stream->{writes}[0], qr/^: keepalive\n\n$/, 'keepalive sent');
};

# ============================================================
# Test 16-17: SSE content type
# ============================================================
subtest 'SSE content type' => sub {
    plan tests => 1;
    
    is(Hypersonic::Protocol::SSE->content_type, 'text/event-stream', 'correct MIME type');
};

subtest 'SSE headers set on start' => sub {
    plan tests => 2;
    
    my $mock_stream = MockStream4->new;
    
    my $sse = Hypersonic::SSE->new($mock_stream);
    $sse->event(data => 'test');
    
    is($MockStream4::headers_set->{'Content-Type'}, 'text/event-stream', 'content-type set');
    is($MockStream4::headers_set->{'Cache-Control'}, 'no-cache', 'cache-control set');
};

# ============================================================
# Test 18-20: RFC compliance edge cases
# ============================================================
subtest 'Event with empty data' => sub {
    plan tests => 2;
    
    my $event = Hypersonic::Protocol::SSE->format_event(data => '');
    
    like($event, qr/data: \n/, 'empty data line');
    like($event, qr/\n\n$/, 'ends with blank line');
};

subtest 'Event data-only (no type)' => sub {
    plan tests => 2;
    
    my $event = Hypersonic::Protocol::SSE->format_event(data => 'test');
    
    unlike($event, qr/event:/, 'no event line when type not specified');
    like($event, qr/data: test\n/, 'has data');
};

subtest 'needs_keepalive timing' => sub {
    plan tests => 2;

    my $mock_stream = MockStream5->new;

    # Use a very short keepalive interval (1 second)
    my $sse = Hypersonic::SSE->new($mock_stream, keepalive => 1);

    ok(!$sse->needs_keepalive, 'no keepalive needed immediately');

    # Wait for the keepalive interval to elapse
    sleep(2);
    ok($sse->needs_keepalive, 'keepalive needed after interval');
};

done_testing();
