use strict;
use warnings;
use Test::More;
use MyNote;
use Benchmark qw(:hireswallclock countit);

unless ( $ENV{TEST_VERBOSE} ) {
    plan skip_all => 'not verbose';
}

use_ok 'UUID', 'uuid4';

note '';
note 'testing version 4 string speed';

my $t = countit(1, 'uuid4()');
my $cnt = $t->iters;

note 'rate = ', $cnt, ' UUID strings per second';
note '';

ok 1, 'done';

done_testing;
