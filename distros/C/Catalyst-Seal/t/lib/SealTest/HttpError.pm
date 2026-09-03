package SealTest::HttpError;

use strict;
use warnings;

# An exception object of the shape Plack::Middleware::HTTPExceptions handles,
# deliberately overloading boolean to false. Code that decides an eval failed by
# testing the truth of $@ rather than the eval's own return value drops this one
# silently, which is why it is in the suite.

use overload
    'bool' => sub { 0 },
    '""'   => sub { 'gone' },
    fallback => 1;

sub new   { bless {}, shift }
sub code  { 410 }
sub throw { die __PACKAGE__->new }

1;
