use strict;
use warnings;

use Test2::Bundle::More;

plan tests => 1;

use lib 't/apps/Foo/lib';

use Foo;
use Dancer::Test appdir => 't/apps/Foo/yadah';  # ... this ain't right

response_content_like [GET => '/'], qr/&lt;escape&gt;/, 
    "escape config was passed";

