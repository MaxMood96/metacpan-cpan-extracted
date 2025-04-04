use 5.014;

use strict;
use warnings;

use Test::More;

# POD

=name

prematched

=usage

  my $prematched = $result->prematched();

=description

The prematched method returns the portion of the string before the regular
expression matched from the result object which contains information about the
results of the regular expression operation.

=signature

prematched() : StrObject | UndefObject

=type

method

=cut

# TESTING

use_ok 'Data::Object::Replace';

my $data = Data::Object::Replace->new(['(?^:(test))', 'best case', 1, [ '0', '0' ], [ '4', '4' ], {}, 'test case']);

is_deeply $data->prematched(), '';

ok 1 and done_testing;
