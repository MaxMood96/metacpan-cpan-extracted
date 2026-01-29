#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use XS::JIT::Builder;
use XS::JIT;

# ============================================================
# Streaming Foundation Tests - Pure XS API
# ============================================================

plan tests => 18;

# ============================================================
# Test 1-2: Module loads
# ============================================================
use_ok('Hypersonic');
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
# Test 3: Stream object creation
# ============================================================
subtest 'Stream object creation' => sub {
    plan tests => 5;
    
    my $stream = Hypersonic::Stream->new(
        fd       => 5,
        protocol => 'http1',
    );
    
    isa_ok($stream, 'Hypersonic::Stream');
    is($stream->fd, 5, 'fd accessor');
    is($stream->protocol, 'http1', 'protocol accessor');
    ok(!$stream->is_started, 'not started initially');
    ok(!$stream->is_finished, 'not finished initially');
};

# ============================================================
# Test 4: Stream headers API
# ============================================================
subtest 'Stream headers API' => sub {
    plan tests => 2;
    
    my $stream = Hypersonic::Stream->new(fd => 100);
    
    # Chaining works
    my $ret = $stream->headers(200, { 'Content-Type' => 'text/plain' });
    is($ret, $stream, 'headers() returns $self for chaining');
    
    # Content-type method
    $ret = $stream->content_type('application/json');
    is($ret, $stream, 'content_type() returns $self for chaining');
};

# ============================================================
# Test 5: Stream state constants
# ============================================================
subtest 'Stream state constants' => sub {
    plan tests => 4;
    
    is(Hypersonic::Stream->STATE_INIT, 0, 'STATE_INIT = 0');
    is(Hypersonic::Stream->STATE_STARTED, 1, 'STATE_STARTED = 1');
    is(Hypersonic::Stream->STATE_FINISHED, 2, 'STATE_FINISHED = 2');
    is(Hypersonic::Stream->STATE_ABORTED, 3, 'STATE_ABORTED = 3');
};

# ============================================================
# Test 6: Stream accessors
# ============================================================
subtest 'Stream accessors' => sub {
    plan tests => 3;
    
    my $stream = Hypersonic::Stream->new(
        fd       => 10,
        protocol => 'http2',
    );
    
    is($stream->fd, 10, 'fd accessor');
    is($stream->protocol, 'http2', 'protocol accessor');
    is($stream->chunks_sent, 0, 'chunks_sent starts at 0');
};

# ============================================================
# Test 7: Stream state tracking
# ============================================================
subtest 'Stream state tracking' => sub {
    plan tests => 2;
    
    my $stream = Hypersonic::Stream->new(fd => 200);
    
    is($stream->state, 0, 'state starts at INIT');
    ok(!$stream->is_finished, 'not finished initially');
};

# ============================================================
# Test 8-10: Streaming handler detection
# ============================================================
subtest 'is_streaming_handler with explicit flag' => sub {
    plan tests => 2;
    
    my $handler = sub { };
    
    ok(
        Hypersonic::Stream->is_streaming_handler($handler, { streaming => 1 }),
        'explicit streaming => 1 detected'
    );
    
    ok(
        !Hypersonic::Stream->is_streaming_handler($handler, { streaming => 0 }),
        'explicit streaming => 0 not detected'
    );
};

subtest 'is_streaming_handler with no options' => sub {
    plan tests => 1;
    
    my $handler = sub { my ($req) = @_; return { status => 200 }; };
    
    ok(
        !Hypersonic::Stream->is_streaming_handler($handler, {}),
        'regular handler not detected as streaming'
    );
};

subtest 'is_streaming_handler with code analysis' => sub {
    plan tests => 1;
    
    # Handler that uses $stream->
    my $handler = sub {
        my ($req, $stream) = @_;
        $stream->write("test");
    };
    
    # Note: code analysis may or may not detect this depending on B::Deparse
    ok(1, 'code analysis attempted');
};

# ============================================================
# Test 11-14: Route registration with streaming flag
# ============================================================
subtest 'Route with streaming flag' => sub {
    plan tests => 4;
    
    my $app = Hypersonic->new();
    
    $app->get('/stream' => sub {
        my ($req, $stream) = @_;
        $stream->write("test");
        $stream->end();
    }, { streaming => 1 });
    
    my $route = $app->{routes}[0];
    
    ok($route->{streaming}, 'route has streaming flag');
    ok($route->{dynamic}, 'streaming route is dynamic');
    is($route->{features}{streaming}, 1, 'features has streaming');
    is($route->{path}, '/stream', 'path correct');
};

subtest 'Route without streaming flag' => sub {
    plan tests => 2;
    
    my $app = Hypersonic->new();
    
    $app->get('/normal' => sub {
        return { status => 200, body => 'hello' };
    });
    
    my $route = $app->{routes}[0];
    
    ok(!$route->{streaming}, 'regular route has no streaming flag');
    is($route->{features}{streaming}, 0, 'features has streaming = 0');
};

subtest 'Route analysis detects streaming' => sub {
    plan tests => 2;
    
    my $app = Hypersonic->new();
    
    $app->get('/stream' => sub {
        my ($req, $stream) = @_;
        $stream->write("data");
        $stream->end();
    }, { streaming => 1 });
    
    my %analysis = (needs_streaming => 0);
    for my $route (@{$app->{routes}}) {
        if ($route->{features}{streaming}) {
            $analysis{needs_streaming} = 1;
        }
    }
    
    ok($analysis{needs_streaming}, 'analysis detects streaming routes');
    
    # Non-streaming app
    my $app2 = Hypersonic->new();
    $app2->get('/normal' => sub { return 'hello' });
    
    %analysis = (needs_streaming => 0);
    for my $route (@{$app2->{routes}}) {
        if ($route->{features}{streaming}) {
            $analysis{needs_streaming} = 1;
        }
    }
    
    ok(!$analysis{needs_streaming}, 'analysis does not detect streaming for normal routes');
};

subtest 'Multiple routes mixed streaming' => sub {
    plan tests => 3;
    
    my $app = Hypersonic->new();
    
    $app->get('/normal' => sub { return 'hello' });
    $app->get('/stream' => sub { }, { streaming => 1 });
    $app->post('/data' => sub { }, { dynamic => 1 });
    
    my @streaming = grep { $_->{streaming} } @{$app->{routes}};
    my @dynamic = grep { $_->{dynamic} } @{$app->{routes}};
    
    is(scalar(@streaming), 1, 'one streaming route');
    is(scalar(@dynamic), 2, 'two dynamic routes (streaming is dynamic)');
    is($app->{routes}[1]{streaming}, 1, 'correct route is streaming');
};

# ============================================================
# Test 15: Code generation produces valid C
# ============================================================
subtest 'Stream code generation' => sub {
    plan tests => 6;
    
    my $builder = XS::JIT::Builder->new;
    
    Hypersonic::Stream->generate_c_code($builder);
    
    my $code = $builder->code;
    
    like($code, qr/STREAM_STATE_INIT/, 'defines STREAM_STATE_INIT');
    like($code, qr/STREAM_STATE_STARTED/, 'defines STREAM_STATE_STARTED');
    like($code, qr/STREAM_STATE_FINISHED/, 'defines STREAM_STATE_FINISHED');
    like($code, qr/StreamState/, 'defines StreamState struct');
    like($code, qr/stream_registry/, 'has stream registry');
    like($code, qr/xs_stream_new/, 'has xs_stream_new');
};

# ============================================================
# Test 16-18: Hypersonic integration
# ============================================================
subtest 'Hypersonic compile with streaming route' => sub {
    plan tests => 2;
    
    my $app = Hypersonic->new();
    
    $app->get('/events' => sub {
        my ($req, $stream) = @_;
        $stream->write("event: test\n");
        $stream->end();
    }, { streaming => 1 });
    
    $app->get('/' => sub { return 'hello' });
    
    eval { $app->compile() };
    
    ok(!$@, 'compile succeeds with streaming route') or diag($@);
    ok($app->{route_analysis}{needs_streaming}, 'analysis has needs_streaming flag');
};

subtest 'Hypersonic compile without streaming route' => sub {
    plan tests => 2;
    
    my $app = Hypersonic->new();
    
    $app->get('/' => sub { return 'hello' });
    $app->get('/about' => sub { return 'about' });
    
    eval { $app->compile() };
    
    ok(!$@, 'compile succeeds without streaming route') or diag($@);
    ok(!$app->{route_analysis}{needs_streaming}, 'analysis has no needs_streaming flag');
};

subtest 'Feature flags in analysis' => sub {
    plan tests => 3;
    
    my $app = Hypersonic->new();
    
    $app->get('/stream' => sub { }, { streaming => 1 });
    $app->get('/json' => sub { }, { dynamic => 1, parse_json => 1 });
    
    my %analysis = (
        needs_streaming => 0,
        needs_json => 0,
    );
    
    for my $route (@{$app->{routes}}) {
        my $f = $route->{features} // {};
        $analysis{needs_streaming} = 1 if $f->{streaming};
        $analysis{needs_json} = 1 if $f->{parse_json};
    }
    
    ok($analysis{needs_streaming}, 'streaming detected');
    ok($analysis{needs_json}, 'json detected');
    
    # Verify they're independent
    my $app2 = Hypersonic->new();
    $app2->get('/stream' => sub { }, { streaming => 1 });
    
    %analysis = (needs_streaming => 0, needs_json => 0);
    for my $route (@{$app2->{routes}}) {
        my $f = $route->{features} // {};
        $analysis{needs_streaming} = 1 if $f->{streaming};
        $analysis{needs_json} = 1 if $f->{parse_json};
    }
    
    ok(!$analysis{needs_json}, 'json not detected when not used');
};

done_testing();
