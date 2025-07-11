# vim: set ft=perl ts=8 sts=2 sw=2 tw=100 et :
use strictures 2;
use 5.020;
use stable 0.031 'postderef';
use experimental 'signatures';
no autovivification warn => qw(fetch store exists delete);
use if "$]" >= 5.022, experimental => 're_strict';
no if "$]" >= 5.031009, feature => 'indirect';
no if "$]" >= 5.033001, feature => 'multidimensional';
no if "$]" >= 5.033006, feature => 'bareword_filehandles';
no if "$]" >= 5.041009, feature => 'smartmatch';
no feature 'switch';
use open ':std', ':encoding(UTF-8)'; # force stdin, stdout, stderr into utf8

use Test::Fatal;
use lib 't/lib';
use Helper;

my $js = JSON::Schema::Modern->new;

my @tests = (
  { schema => false, valid => false, exception => 0 },
  { schema => true, valid => true, exception => 0 },
  { schema => JSON::PP::false, valid => false, exception => 0 },
  { schema => JSON::PP::true, valid => true, exception => 0 },
  { schema => {}, valid => true, exception => 0 },
  { schema => 0, valid => false, exception => 1 },
  { schema => 1, valid => false, exception => 1 },
  { schema => \0, valid => false, exception => 1 },
  { schema => \1, valid => false, exception => 1 },
);

foreach my $test (@tests) {
  my $data = 'hello';
  is(
    exception {
      my $result = $js->evaluate($data, $test->{schema});
      ok(!($result->exception xor $test->{exception}), json_sprintf('%s is not a schema', $test->{schema}));
      ok(!($result->valid xor $test->{valid}), json_sprintf('schema: %s evaluates to: %s', $test->{schema}, $test->{valid}));

      cmp_result(
        $result->TO_JSON,
        {
          valid => $test->{valid},
          $test->{valid} ? () : (errors => supersetof()),
        },
        'invalid result structure looks correct',
      );
    },
    undef,
    'no exceptions in evaluate',
  );
}

cmp_result(
  $js->evaluate('hello', [])->TO_JSON,
  {
    valid => false,
    errors => [
      {
        instanceLocation => '',
        keywordLocation => '',
        error => 'invalid schema type: array',
      },
    ],
  },
  'invalid schema type results in error',
);

$js = JSON::Schema::Modern->new(scalarref_booleans => 1);

cmp_result(
  $js->evaluate('hello', \0)->TO_JSON,
  {
    valid => false,
    errors => [
      {
        instanceLocation => '',
        keywordLocation => '',
        error => 'invalid schema type: reference to SCALAR',
      },
    ],
  },
  'scalarref for schema results in error, even when scalarref_booleans is true',
);

done_testing;
