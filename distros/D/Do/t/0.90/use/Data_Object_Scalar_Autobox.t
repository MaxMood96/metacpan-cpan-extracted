use 5.014;

use strict;
use warnings;

use Test::More;

=name

Data::Object::Scalar::Autobox

=abstract

Data-Object Scalar Class Autoboxing

=synopsis

  use Data::Object::Scalar::Autobox;

=libraries

Data::Object::Library

=description

This package implements autoboxing via L<Data::Object::Autobox> for
L<Data::Object::Scalar> objects.

+=head1 ROLES

This package assumes all behavior from the follow roles:

L<Data::Object::Role::Proxyable>

=cut

use_ok "Data::Object::Scalar::Autobox";

ok 1 and done_testing;
