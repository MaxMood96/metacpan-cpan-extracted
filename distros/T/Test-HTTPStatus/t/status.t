use strict;
use warnings;

use Test::More 1;
use Test::RequiresInternet ('www.perl6.org' => 'http');

BEGIN { use_ok('Test::HTTPStatus') }

http_ok('http://www.perl6.org/', HTTP_OK) or diag('Live servers can be tricky. If this fails, you may want to inspect it');

done_testing();
