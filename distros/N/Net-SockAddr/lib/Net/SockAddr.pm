package Net::SockAddr;
use 5.012;
use XS::Framework;
use Export::XS();

our $VERSION = '1.1.4';

XS::Loader::bootstrap();

use overload
    '""'     => \&_to_string,
    '=='     => \&_eq,
    '!='     => \&_ne,
    fallback => 1,
;

1;
