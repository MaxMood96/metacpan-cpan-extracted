use 5.014;

use strict;
use warnings;

use Test::More;

# POD

=name

execute

=usage

  my $data = Data::Object::Array->new([1..4]);

  my $func = Data::Object::Array::Func::One->new(
    arg1 => $data,
    arg2 => sub { $_[0] == 1 }
  );

  my $result = $func->execute;

=description

Executes the function logic and returns the result.

=signature

execute() : Object

=type

method

=cut

# TESTING

use Data::Object::Array;
use Data::Object::Array::Func::One;

can_ok "Data::Object::Array::Func::One", "execute";

my $data;
my $func;

$data = Data::Object::Array->new([1..4]);
$func = Data::Object::Array::Func::One->new(
  arg1 => $data,
  arg2 => sub { $_[0] == 1 }
);

my $result = $func->execute;

is_deeply $result, 1;

ok 1 and done_testing;
