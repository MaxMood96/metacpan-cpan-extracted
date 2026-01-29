#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

sub lives_ok(&$) {
    my ($code, $msg) = @_;
    eval { $code->() };
    ok(!$@, $msg) or diag("Error: $@");
}

use_ok('Hypersonic::UA::TLS');

subtest 'OpenSSL detection' => sub {
    my $available = Hypersonic::UA::TLS::check_openssl();
    ok(defined $available, 'check_openssl returns defined value');
    diag("OpenSSL available: " . ($available ? "yes" : "no"));

    if ($available) {
        my $cflags = Hypersonic::UA::TLS::get_extra_cflags();
        ok(defined $cflags, 'get_extra_cflags returns value');
        diag("CFLAGS: $cflags") if $cflags;

        my $ldflags = Hypersonic::UA::TLS::get_extra_ldflags();
        ok(defined $ldflags, 'get_extra_ldflags returns value');
        like($ldflags, qr/ssl|crypto/i, 'ldflags contain ssl/crypto');
        diag("LDFLAGS: $ldflags");
    }
};

subtest 'XS function registry' => sub {
    my $funcs = Hypersonic::UA::TLS->get_xs_functions();
    
    ok($funcs, 'get_xs_functions returns hashref');
    
    my @expected = qw(
        Hypersonic::UA::TLS::init_context
        Hypersonic::UA::TLS::tls_connect
        Hypersonic::UA::TLS::tls_handshake
        Hypersonic::UA::TLS::tls_send
        Hypersonic::UA::TLS::tls_recv
        Hypersonic::UA::TLS::tls_recv_chunk
        Hypersonic::UA::TLS::tls_close
        Hypersonic::UA::TLS::get_ssl
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
        Hypersonic::UA::TLS->generate_c_code($builder, {});
    } 'generate_c_code runs without error';
    
    my $code = $builder->code;
    
    like($code, qr/UATLSClientConn/, 'Contains TLS connection struct');
    like($code, qr/g_ua_client_ssl_ctx/, 'Contains global SSL context');
    like($code, qr/ua_tls_find/, 'Contains registry find function');
    like($code, qr/ua_tls_alloc/, 'Contains registry alloc function');
    like($code, qr/ua_tls_free/, 'Contains registry free function');
    like($code, qr/SSL_set_tlsext_host_name/, 'Contains SNI support');
    like($code, qr/SSL_set1_host/, 'Contains hostname verification');
    like($code, qr/TLS_client_method/, 'Uses TLS client method');
    like($code, qr/SSL_set_connect_state/, 'Sets connect state');
};

done_testing;
