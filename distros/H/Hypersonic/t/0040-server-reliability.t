#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 10;

# Test Phase 1: Server Reliability features

use_ok('Hypersonic');
use_ok('Hypersonic::Middleware::RequestId');

# Test 1: health_check method exists and works
{
    my $server = Hypersonic->new(port => 18080);
    can_ok($server, 'health_check');
    
    # Add health check route
    $server->health_check();
    
    # Check route was added
    my @routes = @{$server->{routes}};
    my ($health_route) = grep { $_->{path} eq '/health' } @routes;
    ok($health_route, 'health_check adds /health route');
}

# Test 2: ready_check method exists and works
{
    my $server = Hypersonic->new(port => 18081);
    can_ok($server, 'ready_check');
    
    # Add ready check route
    $server->ready_check();
    
    # Check route was added
    my @routes = @{$server->{routes}};
    my ($ready_route) = grep { $_->{path} eq '/ready' } @routes;
    ok($ready_route, 'ready_check adds /ready route');
}

# Test 3: RequestId builder pattern
{
    # RequestId returns builder objects, not coderefs
    my $before_mw = Hypersonic::Middleware::RequestId::middleware();
    ok(ref($before_mw) eq 'Hypersonic::Middleware::RequestId', 'middleware() returns builder object');
    
    # Builder has required interface
    ok($before_mw->can('slot_requirements') && $before_mw->can('build_before'),
       'builder has slot_requirements and build_before methods');
}

# Test 4: enable_request_id method exists
{
    my $server = Hypersonic->new(port => 18082);
    can_ok($server, 'enable_request_id');
    
    # Enable request ID
    $server->enable_request_id();
    
    # Check middleware was added (should be builder objects)
    ok(scalar(@{$server->{before_middleware}}) > 0, 'enable_request_id adds before middleware');
}

done_testing();
