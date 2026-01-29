use strict;
use warnings;
use Test::More;

# Phase 10: Async API with Hypersonic::Future integration tests

use_ok('Hypersonic::UA::Async');

# Test constants
is(Hypersonic::UA::Async->MAX_ASYNC_CONTEXTS, 1024, 'MAX_ASYNC_CONTEXTS constant');
is(Hypersonic::UA::Async->STATE_CONNECTING, 0, 'STATE_CONNECTING constant');
is(Hypersonic::UA::Async->STATE_TLS, 1, 'STATE_TLS constant');
is(Hypersonic::UA::Async->STATE_SENDING, 2, 'STATE_SENDING constant');
is(Hypersonic::UA::Async->STATE_RECEIVING, 3, 'STATE_RECEIVING constant');
is(Hypersonic::UA::Async->STATE_DONE, 4, 'STATE_DONE constant');
is(Hypersonic::UA::Async->STATE_ERROR, 5, 'STATE_ERROR constant');
is(Hypersonic::UA::Async->STATE_CANCELLED, 6, 'STATE_CANCELLED constant');

is(Hypersonic::UA::Async->WAIT_NONE, 0, 'WAIT_NONE constant');
is(Hypersonic::UA::Async->WAIT_READ, 1, 'WAIT_READ constant');
is(Hypersonic::UA::Async->WAIT_WRITE, 2, 'WAIT_WRITE constant');

# Test slot constants
is(Hypersonic::UA::Async->SLOT_ID, 0, 'SLOT_ID constant');
is(Hypersonic::UA::Async->SLOT_UA, 1, 'SLOT_UA constant');
is(Hypersonic::UA::Async->SLOT_FUTURE, 2, 'SLOT_FUTURE constant');

# Test XS function registry
my $xs_funcs = Hypersonic::UA::Async->get_xs_functions();
is(ref($xs_funcs), 'HASH', 'get_xs_functions returns hash');
ok(exists $xs_funcs->{'Hypersonic::UA::Async::start_request'}, 'has start_request');
ok(exists $xs_funcs->{'Hypersonic::UA::Async::poll'}, 'has poll');
ok(exists $xs_funcs->{'Hypersonic::UA::Async::get_fd'}, 'has get_fd');
ok(exists $xs_funcs->{'Hypersonic::UA::Async::get_events'}, 'has get_events');
ok(exists $xs_funcs->{'Hypersonic::UA::Async::cancel'}, 'has cancel');
ok(exists $xs_funcs->{'Hypersonic::UA::Async::cleanup'}, 'has cleanup');
ok(exists $xs_funcs->{'Hypersonic::UA::Async::get_future'}, 'has get_future');

# Test gen_* methods
can_ok('Hypersonic::UA::Async', 'generate_c_code');
can_ok('Hypersonic::UA::Async', 'gen_async_context_registry');
can_ok('Hypersonic::UA::Async', 'gen_async_poll_one');
can_ok('Hypersonic::UA::Async', 'gen_xs_start_request');
can_ok('Hypersonic::UA::Async', 'gen_xs_poll');
can_ok('Hypersonic::UA::Async', 'gen_xs_get_fd');
can_ok('Hypersonic::UA::Async', 'gen_xs_get_events');
can_ok('Hypersonic::UA::Async', 'gen_xs_cancel');
can_ok('Hypersonic::UA::Async', 'gen_xs_cleanup');
can_ok('Hypersonic::UA::Async', 'gen_xs_get_future');

# Test Hypersonic::UA module
use_ok('Hypersonic::UA');

# Test UA constants
is(Hypersonic::UA->MAX_CONNECTIONS, 65536, 'MAX_CONNECTIONS constant');
is(Hypersonic::UA->UA_MAX_INSTANCES, 256, 'UA_MAX_INSTANCES constant');
is(Hypersonic::UA->SLOT_ID, 0, 'UA SLOT_ID constant');
is(Hypersonic::UA->SLOT_TIMEOUT, 1, 'UA SLOT_TIMEOUT constant');
is(Hypersonic::UA->SLOT_CONNECT_TIMEOUT, 2, 'UA SLOT_CONNECT_TIMEOUT constant');
is(Hypersonic::UA->SLOT_HEADERS, 3, 'UA SLOT_HEADERS constant');
is(Hypersonic::UA->SLOT_BASE_URL, 4, 'UA SLOT_BASE_URL constant');
is(Hypersonic::UA->SLOT_MAX_REDIRECTS, 5, 'UA SLOT_MAX_REDIRECTS constant');
is(Hypersonic::UA->SLOT_KEEP_ALIVE, 6, 'UA SLOT_KEEP_ALIVE constant');

# Test UA XS function registry - minimal (blocking-only)
my $ua_xs_funcs_minimal = Hypersonic::UA->get_xs_functions({});
is(ref($ua_xs_funcs_minimal), 'HASH', 'UA get_xs_functions returns hash (minimal)');

# Constructor/destructor (always present)
ok(exists $ua_xs_funcs_minimal->{'Hypersonic::UA::new'}, 'has new');
ok(exists $ua_xs_funcs_minimal->{'Hypersonic::UA::DESTROY'}, 'has DESTROY');

# Existing
ok(exists $ua_xs_funcs_minimal->{'Hypersonic::UA::parse_url'}, 'has parse_url');
ok(exists $ua_xs_funcs_minimal->{'Hypersonic::UA::build_request'}, 'has build_request');

# Blocking methods (always present)
ok(exists $ua_xs_funcs_minimal->{'Hypersonic::UA::get'}, 'has get');
ok(exists $ua_xs_funcs_minimal->{'Hypersonic::UA::post'}, 'has post');
ok(exists $ua_xs_funcs_minimal->{'Hypersonic::UA::put'}, 'has put');
ok(exists $ua_xs_funcs_minimal->{'Hypersonic::UA::patch'}, 'has patch');
ok(exists $ua_xs_funcs_minimal->{'Hypersonic::UA::delete'}, 'has delete');
ok(exists $ua_xs_funcs_minimal->{'Hypersonic::UA::head'}, 'has head');
ok(exists $ua_xs_funcs_minimal->{'Hypersonic::UA::options'}, 'has options');
ok(exists $ua_xs_funcs_minimal->{'Hypersonic::UA::request'}, 'has request');

# Async methods NOT present in minimal build
ok(!exists $ua_xs_funcs_minimal->{'Hypersonic::UA::get_async'}, 'minimal: no get_async');
ok(!exists $ua_xs_funcs_minimal->{'Hypersonic::UA::tick'}, 'minimal: no tick');
ok(!exists $ua_xs_funcs_minimal->{'Hypersonic::UA::pending'}, 'minimal: no pending');
ok(!exists $ua_xs_funcs_minimal->{'Hypersonic::UA::parallel'}, 'minimal: no parallel');

# Test UA XS function registry - with async enabled
my $ua_xs_funcs = Hypersonic::UA->get_xs_functions({ needs_async => 1, needs_parallel => 1 });
is(ref($ua_xs_funcs), 'HASH', 'UA get_xs_functions returns hash (async)');

# Async methods (present when async enabled)
ok(exists $ua_xs_funcs->{'Hypersonic::UA::get_async'}, 'has get_async');
ok(exists $ua_xs_funcs->{'Hypersonic::UA::post_async'}, 'has post_async');
ok(exists $ua_xs_funcs->{'Hypersonic::UA::put_async'}, 'has put_async');
ok(exists $ua_xs_funcs->{'Hypersonic::UA::delete_async'}, 'has delete_async');
ok(exists $ua_xs_funcs->{'Hypersonic::UA::request_async'}, 'has request_async');

# Run/poll (present when async enabled)
ok(exists $ua_xs_funcs->{'Hypersonic::UA::run'}, 'has run');
ok(exists $ua_xs_funcs->{'Hypersonic::UA::run_one'}, 'has run_one');
ok(exists $ua_xs_funcs->{'Hypersonic::UA::tick'}, 'has tick');
ok(exists $ua_xs_funcs->{'Hypersonic::UA::pending'}, 'has pending');

# Helpers (present when parallel enabled)
ok(exists $ua_xs_funcs->{'Hypersonic::UA::parallel'}, 'has parallel');
ok(exists $ua_xs_funcs->{'Hypersonic::UA::race'}, 'has race');

# Test UA gen_* methods
can_ok('Hypersonic::UA', 'generate_c_code');
can_ok('Hypersonic::UA', 'gen_ua_registry');
can_ok('Hypersonic::UA', 'gen_xs_new');
can_ok('Hypersonic::UA', 'gen_xs_destroy');
can_ok('Hypersonic::UA', 'gen_xs_parse_url');
can_ok('Hypersonic::UA', 'gen_xs_build_request');
can_ok('Hypersonic::UA', 'gen_xs_get');
can_ok('Hypersonic::UA', 'gen_xs_post');
can_ok('Hypersonic::UA', 'gen_xs_put');
can_ok('Hypersonic::UA', 'gen_xs_patch');
can_ok('Hypersonic::UA', 'gen_xs_delete');
can_ok('Hypersonic::UA', 'gen_xs_head');
can_ok('Hypersonic::UA', 'gen_xs_options');
can_ok('Hypersonic::UA', 'gen_xs_request');
can_ok('Hypersonic::UA::Async', 'gen_xs_tick');  # tick moved to Async module
can_ok('Hypersonic::UA', 'gen_xs_pending');
can_ok('Hypersonic::UA', 'gen_xs_get_async');
can_ok('Hypersonic::UA', 'gen_xs_post_async');
can_ok('Hypersonic::UA', 'gen_xs_put_async');
can_ok('Hypersonic::UA', 'gen_xs_delete_async');
can_ok('Hypersonic::UA', 'gen_xs_request_async');
can_ok('Hypersonic::UA', 'gen_xs_run');
can_ok('Hypersonic::UA', 'gen_xs_run_one');
can_ok('Hypersonic::UA', 'gen_xs_parallel');
can_ok('Hypersonic::UA', 'gen_xs_race');

# Test XS builder integration for Async module
SKIP: {
    eval { require XS::JIT::Builder };
    skip "XS::JIT::Builder not available", 12 if $@;

    my $builder = XS::JIT::Builder->new();
    ok($builder, 'Created XS::JIT::Builder');

    eval { Hypersonic::UA::Async->generate_c_code($builder, {}) };
    ok(!$@, 'Async generate_c_code succeeded') or diag $@;

    my $code = $builder->code();
    ok(defined $code, 'Builder generated code');
    ok(length($code) > 0, 'Generated code is not empty');

    # Check key parts of generated code
    like($code, qr/AsyncContext/, 'Has AsyncContext struct');
    like($code, qr/async_registry/, 'Has registry array');
    like($code, qr/async_alloc_slot/, 'Has alloc_slot function');
    like($code, qr/async_free_slot/, 'Has free_slot function');
    like($code, qr/async_poll_one/, 'Has async_poll_one function');
    like($code, qr/future_sv/, 'Has future_sv field');
    like($code, qr/ASYNC_STATE_CONNECTING/, 'Has state constants');
    like($code, qr/ASYNC_WAIT_READ/, 'Has wait constants');
}

# Test XS builder integration for UA module (minimal)
SKIP: {
    eval { require XS::JIT::Builder };
    skip "XS::JIT::Builder not available", 10 if $@;

    my $builder = XS::JIT::Builder->new();
    ok($builder, 'Created XS::JIT::Builder for UA');

    eval { Hypersonic::UA->generate_c_code($builder, {}) };
    ok(!$@, 'UA generate_c_code succeeded') or diag $@;

    my $code = $builder->code();
    ok(defined $code, 'UA Builder generated code');
    ok(length($code) > 0, 'UA Generated code is not empty');

    # Check key parts of generated code
    like($code, qr/UAContext/, 'Has UAContext struct');
    like($code, qr/ua_registry/, 'Has UA registry array');
    like($code, qr/ua_alloc_slot/, 'Has ua_alloc_slot function');
    like($code, qr/ua_free_slot/, 'Has ua_free_slot function');
    like($code, qr/xs_ua_new/, 'Has xs_ua_new function');
    like($code, qr/xs_ua_request/, 'Has xs_ua_request function');
}

# Test XS builder integration for UA module (with async)
SKIP: {
    eval { require XS::JIT::Builder };
    skip "XS::JIT::Builder not available", 4 if $@;

    my $builder = XS::JIT::Builder->new();
    ok($builder, 'Created XS::JIT::Builder for UA (async)');

    # Note: generate_c_code takes ($builder, $opts, $analysis)
    my $analysis = { needs_async => 1, needs_parallel => 1 };
    eval { 
        Hypersonic::UA->generate_c_code($builder, {}, $analysis);
        # Async code (including tick) is in Async module
        Hypersonic::UA::Async->generate_c_code($builder, {});
    };
    ok(!$@, 'UA generate_c_code with async succeeded') or diag $@;

    my $code = $builder->code();

    # Check async-specific code is present
    like($code, qr/xs_ua_get_async/, 'Has async methods when enabled');
    like($code, qr/xs_ua_tick/, 'Has tick when async enabled');
}

done_testing();
