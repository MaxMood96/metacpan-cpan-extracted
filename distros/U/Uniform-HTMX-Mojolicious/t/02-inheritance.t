use strict;
use warnings;
use Test::More;
use Mojolicious::Controller;
use Mojo::Transaction::HTTP;
use Uniform::HTMX::Mojolicious;

my $tx = Mojo::Transaction::HTTP->new;
my $c  = Mojolicious::Controller->new(tx => $tx);

$c->req->headers->header('HX-Request' => 'true');

my $htmx = Uniform::HTMX::Mojolicious->new($c);

isa_ok($htmx, 'Uniform::HTMX::Mojolicious');
isa_ok($htmx, 'Uniform::HTMX');

ok($htmx->can('_out'), 'inherits _out accumulator method from base');

done_testing();
