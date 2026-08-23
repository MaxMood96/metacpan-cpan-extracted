use strict;
use warnings;
use Test::More;
BEGIN { do './t/sibling.pl' }

BEGIN { use_ok('Punk::Mailer') }
ok defined $Punk::Mailer::VERSION, 'has a version';
cmp_ok(Punk::Mailer::_fetch_abi_version(), '>=', 2,
    'Fetch loaded and its ABI table was resolved at boot');

done_testing;
