use strict;
use warnings;

use Acme::CPANAuthors;
use Test::More 'tests' => 2;
use Test::NoWarnings;

# Test.
my $obj = Acme::CPANAuthors->new('Czech');
my @ret = $obj->id;
my @right_ret = ('ATG', 'BULB', 'CHOROBA', 'CONTYK', 'DANIELR', 'DANPEDER',
	'DOUGLISH', 'DPOKORNY', 'HIHIK', 'HOLCAPEK', 'HPA', 'JANPAZ', 'JANPOM',
	'JENDA', 'JIRA', 'JSPICAK', 'KLE', 'KOLCON', 'MAJLIS', 'MICHALS', 'MIK',
	'MILSO', 'MJFO', 'PAJAS', 'PAJOUT', 'PASKY', 'PCIMPRICH', 'PEK',
	'PETRIS', 'PKUBANEK', 'POPEL', 'PSME', 'RADIUSCZ', 'RUR', 'RVASICEK',
	'SARFY', 'SEIDLJAN', 'SKIM', 'SMRZ', 'STRAKA', 'TKR', 'TPODER', 'TRIPIE',
	'TYNOVSKY', 'VARISD', 'VASEKD', 'YENYA', 'ZABA', 'ZEMAN', 'ZOUL');
is_deeply(\@ret, \@right_ret, 'CPAN authors ids.');
