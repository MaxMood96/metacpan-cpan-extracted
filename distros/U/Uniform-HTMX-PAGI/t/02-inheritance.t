use strict;
use warnings;
use Test::More;
use Uniform::HTMX::PAGI;

my %env  = ( HTTP_HX_REQUEST => 'true' );
my $htmx = Uniform::HTMX::PAGI->new(\%env);

isa_ok($htmx, 'Uniform::HTMX::PAGI');
isa_ok($htmx, 'Uniform::HTMX');

# Verify access to internal _out accumulator
ok($htmx->can('_out'), 'inherits _out accumulator method from base');

done_testing();
