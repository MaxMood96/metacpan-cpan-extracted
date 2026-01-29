#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

sub lives_ok(&$) {
    my ($code, $msg) = @_;
    eval { $code->() };
    ok(!$@, $msg) or diag("Error: $@");
}

use_ok('Hypersonic::UA::Pool');

subtest 'Constants' => sub {
    is(Hypersonic::UA::Pool->MAX_PER_HOST, 6, 'MAX_PER_HOST default');
    is(Hypersonic::UA::Pool->MAX_TOTAL, 100, 'MAX_TOTAL default');
    is(Hypersonic::UA::Pool->MAX_HOSTS, 256, 'MAX_HOSTS default');
    is(Hypersonic::UA::Pool->IDLE_TIMEOUT, 60, 'IDLE_TIMEOUT default');
};

subtest 'XS function registry' => sub {
    my $funcs = Hypersonic::UA::Pool->get_xs_functions();
    
    ok($funcs, 'get_xs_functions returns hashref');
    
    my @expected = qw(
        Hypersonic::UA::Pool::init
        Hypersonic::UA::Pool::get
        Hypersonic::UA::Pool::put
        Hypersonic::UA::Pool::remove
        Hypersonic::UA::Pool::clear
        Hypersonic::UA::Pool::prune
        Hypersonic::UA::Pool::stats
        Hypersonic::UA::Pool::is_alive
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
        Hypersonic::UA::Pool->generate_c_code($builder, {});
    } 'generate_c_code runs without error';
    
    my $code = $builder->code;
    
    like($code, qr/PoolConn/, 'Contains PoolConn struct');
    like($code, qr/PoolBucket/, 'Contains PoolBucket struct');
    like($code, qr/ConnectionPool/, 'Contains ConnectionPool struct');
    like($code, qr/g_pool/, 'Contains global pool');
    like($code, qr/pool_find_bucket/, 'Contains find_bucket helper');
    like($code, qr/pool_get_bucket/, 'Contains get_bucket helper');
    like($code, qr/pool_check_alive/, 'Contains check_alive helper');
    like($code, qr/pool_close_conn/, 'Contains close_conn helper');
    like($code, qr/xs_pool_init/, 'Contains init XS function');
    like($code, qr/xs_pool_get/, 'Contains get XS function');
    like($code, qr/xs_pool_put/, 'Contains put XS function');
    like($code, qr/xs_pool_stats/, 'Contains stats XS function');
    like($code, qr/hit_rate/, 'Stats include hit_rate');
};

done_testing;
