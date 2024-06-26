use strict;
use warnings;
use Test::More;

use_ok 'Data::Object::String';
# deprecated
# can_ok 'Data::Object::String', 'lowercase';

use Scalar::Util 'refaddr';

subtest 'test the lowercase method' => sub {
  my $string     = Data::Object::String->new('EXCITING');
  my $lowercased = $string->lowercase;

  isnt refaddr($string), refaddr($lowercased);
  is "$lowercased", 'exciting';    # exciting

  isa_ok $string,     'Data::Object::String';
  isa_ok $lowercased, 'Data::Object::String';
};

ok 1 and done_testing;
