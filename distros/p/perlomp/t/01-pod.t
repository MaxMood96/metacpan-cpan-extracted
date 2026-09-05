use strict;
use warnings;
use Test::More;
use Pod::Simple::Checker;

my $errors = 0;
my $parser = Pod::Simple::Checker->new;
$parser->output_string(\my $output);
$parser->parse_file('lib/perlomp.pod');
$errors = $parser->any_errata_seen ? 1 : 0;

ok(!$errors, 'lib/perlomp.pod has valid POD');

done_testing;
