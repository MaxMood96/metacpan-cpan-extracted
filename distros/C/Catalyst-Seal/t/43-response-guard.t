#!/usr/bin/env perl
use strict;
use warnings;

use FindBin ();
use lib "$FindBin::Bin/lib";

use Test::More;
use Scalar::Util ();

# Catalyst::Response warns when a header is set after the headers were
# finalised. The condition ends in "&& @_", so on a read it cannot fire, but the
# three accessor calls before that term are made anyway, forty times a request.
#
# The warning is captured rather than asserted by absence. A guard that never
# fires because the path is broken looks exactly like a guard that correctly
# stayed quiet, and only the setter case can tell them apart.

BEGIN { $ENV{CATALYST_DEBUG} = 0 }

require Class::MOP;
require Catalyst::Response;

# Taken before the application is loaded, because loading it seals, and this is
# the only chance to hold the subroutine the patch replaces.
my $meta = Class::MOP::class_of('Catalyst::Response');
my %STOCK = map {
    $_ => $meta->get_method($_)->{modifier_table}{before}[0]
} qw(status headers content_encoding content_length content_type header);

require Catalyst::Seal;
require TestApp;

my %FAST = map {
    $_ => $meta->get_method($_)->{modifier_table}{before}[0]
} keys %STOCK;

for my $name (sort keys %STOCK) {
    isnt(
        Scalar::Util::refaddr($FAST{$name}),
        Scalar::Util::refaddr($STOCK{$name}),
        "the guard on $name was replaced",
    );
}

is(
    scalar(keys %{{ map { Scalar::Util::refaddr($STOCK{$_}) => 1 }
        qw(status headers content_encoding content_length content_type) }}),
    1,
    'the five setter guards really were one shared subroutine',
);

# A context whose log records rather than prints. _context is a weak reference,
# so the test holds it for as long as the response does.
{
    package Seal::Guard::Log;
    sub new  { bless { warned => [] }, shift }
    sub warn { my $self = shift; push @{ $self->{warned} }, join '', @_; return }
    package Seal::Guard::Context;
    sub new { bless { log => Seal::Guard::Log->new }, shift }
    sub log { $_[0]{log} }
}

my $ctx = Seal::Guard::Context->new;

sub finalised_response {
    my $res = TestApp->response_class->new;
    $res->_context($ctx);
    $res->finalized_headers(1);
    @{ $ctx->log->{warned} } = ();
    return $res;
}

sub warnings_from {
    my ($code) = @_;
    my $res = finalised_response();
    $code->($res);
    return @{ $ctx->log->{warned} };
}

# The positive control first. Everything below it is only meaningful because
# this one fires.
my @warned = warnings_from(sub { $_[0]->status(503) });
is(scalar @warned, 1, 'setting status after finalize_headers still warns');
like($warned[0], qr/Useless setting a header value after finalize_headers/,
    'with the warning Catalyst wrote');

for my $set (
    ['headers',          sub { $_[0]->headers(HTTP::Headers->new) }],
    ['content_type',     sub { $_[0]->content_type('text/plain') }],
    ['content_length',   sub { $_[0]->content_length(3) }],
    ['content_encoding', sub { $_[0]->content_encoding('gzip') }],
    ['header',           sub { $_[0]->header('X-Thing' => 'yes') }],
) {
    my ($name, $code) = @$set;
    is(scalar warnings_from($code), 1, "setting $name after finalize_headers warns");
}

for my $read (
    ['status',           sub { my $x = $_[0]->status }],
    ['headers',          sub { my $x = $_[0]->headers }],
    ['content_type',     sub { my $x = $_[0]->content_type }],
    ['content_length',   sub { my $x = $_[0]->content_length }],
    ['content_encoding', sub { my $x = $_[0]->content_encoding }],
    ['header',           sub { my $x = $_[0]->header('X-Thing') }],
) {
    my ($name, $code) = @$read;
    is(scalar warnings_from($code), 0, "reading $name does not warn");
}

# A response that has not been finalised is the ordinary case, and it must stay
# quiet whether it was read or written.
{
    my $res = TestApp->response_class->new;
    $res->_context($ctx);
    @{ $ctx->log->{warned} } = ();
    $res->status(201);
    $res->header('X-Thing' => 'yes');
    is(scalar @{ $ctx->log->{warned} }, 0,
        'setting headers before finalize_headers does not warn');
    is($res->status, 201, 'and the setter did what it was asked');
    is($res->header('X-Thing'), 'yes', 'for header too');
}

# What the patch is actually for. The stock guard reads three attributes before
# it reaches the "@_" that decides the answer; the replacement reads none.
{
    my $calls = 0;
    my $stock_reader = Catalyst::Response->can('finalized_headers');
    {
        no warnings 'redefine';
        *Catalyst::Response::finalized_headers = sub { $calls++; goto &$stock_reader };
    }

    my $res = TestApp->response_class->new;
    $res->_context($ctx);
    $res->finalized_headers(1);

    $calls = 0;
    $STOCK{status}->($res);
    cmp_ok($calls, '>', 0, 'the stock guard reads finalized_headers on a plain read');

    $calls = 0;
    $FAST{status}->($res);
    is($calls, 0, 'the replacement reads nothing at all');

    $calls = 0;
    $FAST{status}->($res, 503);
    cmp_ok($calls, '>', 0, 'and reads it again as soon as it is a setter');

    no warnings 'redefine';
    *Catalyst::Response::finalized_headers = $stock_reader;
}

# The application still serves the requests the parity table drives, with the
# patched guard in place.
{
    require SealTest;
    my $res = SealTest::response(TestApp->psgi_app);
    is($res->[0], 200, 'the application answers');
    is(join('', @{ $res->[2] }), 'hello', 'with the right body');
}

done_testing;
