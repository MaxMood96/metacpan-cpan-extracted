use Test::More;

use Bored qw/bored_one/;

is(bored_one(), 1, 'very easy when you know everything right?');

my $bored = Bored->new();
is($bored->pointless(), 'leadership');
is($bored->tortured(), 'souls');
is($bored->topdown(), 'bottom up');


done_testing();
