use 5.014;

use strict;
use warnings;

use Test::More;

# POD

=name

Data::Object::Array::Func::Head

=abstract

Data-Object Array Function (Head) Class

=synopsis

  use Data::Object::Array::Func::Head;

  my $func = Data::Object::Array::Func::Head->new(@args);

  $func->execute;

=inherits

Data::Object::Array::Func

=attributes

arg1(ArrayLike, req, ro)

=libraries

Data::Object::Library

=description

Data::Object::Array::Func::Head is a function object for Data::Object::Array.

=cut

# TESTING

use_ok 'Data::Object::Array::Func::Head';

ok 1 and done_testing;
