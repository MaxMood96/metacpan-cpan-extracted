use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";

use Test::More;
use Test::Exception;
use Uniform::Utils qw(normalize_http_headers);

# 1. Test manual direct throwing capability
throws_ok {
    Uniform::Exceptions->throw(
        type    => 'CustomError',
        message => 'Direct execution failure payload test',
    );
} 'Uniform::Exceptions', 'Throws a valid structured exception object instance';

# 2. Test implicit deep utility integration tracking
eval {
    normalize_http_headers("Invalid plain string input context");
};
my $error = $@; # Catches the thrown exception object

isa_ok($error, 'Uniform::Exceptions', 'Intercepted failure data reference');
is($error->type, 'TypeError', 'Exception retains its correct category signature');
like($error->to_string, qr/\[Uniform::Exception::TypeError\]/, 'Object converts cleanly to a detailed tracking string');

done_testing();
