use Test::More;

use Bored qw/bored_one/;

is(bored_one(), 1, 'very easy');

my $bored = Bored->new();
is($bored->pointless(), 'invisible');

done_testing();
