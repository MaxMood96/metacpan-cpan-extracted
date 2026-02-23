use strict;
use warnings;

use App::MARC::Record::Stats;
use English;
use Error::Pure::Utils qw(clean);
use Test::More 'tests' => 3;
use Test::NoWarnings;

# Test.
my $obj = App::MARC::Record::Stats->new;
isa_ok($obj, 'App::MARC::Record::Stats');

# Test.
eval {
	App::MARC::Record::Stats->new(
		'foo' => 'bar',
	);
};
is($EVAL_ERROR, "Unknown parameter 'foo'.\n", "Unknown parameter 'foo'.");
clean();
