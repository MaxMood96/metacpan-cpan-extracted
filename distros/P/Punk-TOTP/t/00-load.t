use strict;
use warnings;
use Test::More;
BEGIN { do './t/sibling.pl' }

BEGIN { use_ok('Punk::TOTP') }
ok defined $Punk::TOTP::VERSION, 'has a version';

done_testing;
