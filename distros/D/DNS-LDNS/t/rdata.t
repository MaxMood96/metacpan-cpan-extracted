use Test::More tests => 20;

use DNS::LDNS ':all';

BEGIN { use_ok('DNS::LDNS') };

# Integer data
my $i = DNS::LDNS::RData->new(LDNS_RDF_TYPE_INT32, '1237654');
is($i->to_string, '1237654', 'Integer value rdata');

my $ii = DNS::LDNS::RData->new(LDNS_RDF_TYPE_INT32, '1237654X');
is($ii, undef, '1237654X is invalid');

# Period data
my $p1 = DNS::LDNS::RData->new(LDNS_RDF_TYPE_PERIOD, '3h3m3s');
is($p1->to_string, sprintf("%d", 3600*3 + 60*3 + 3), 'Normalizing period');

my $pi = DNS::LDNS::RData->new(LDNS_RDF_TYPE_PERIOD, '3h3X3s');
is($pi, undef, 'Invalid period value 3h3X3s');

# DNames
my $dn1 = DNS::LDNS::RData->new(LDNS_RDF_TYPE_DNAME, 'azone.org');
my $dn2 = DNS::LDNS::RData->new(LDNS_RDF_TYPE_DNAME, 'other.org');
my $dn3 = DNS::LDNS::RData->new(LDNS_RDF_TYPE_DNAME, 'sub.other.org');
my $dn4 = DNS::LDNS::RData->new(LDNS_RDF_TYPE_DNAME, 'adder.org');

$dn1->cat($dn2);
is($dn1->to_string, 'azone.org.other.org.', 'Concatenating two domain names');
my $chopped = $dn1->left_chop;
is($chopped->to_string, 'org.other.org.', 'Chop off left domain name label');
ok($dn3->is_subdomain($dn2), 'sub.other.org is subdomain of other.org');
ok(!$dn2->is_subdomain($dn3), 'other.org is not subdomain of sub.other.org');
is($dn3->label_count, 3, 'sub.other.org has 3 labels');
is($dn3->label(1)->to_string, 'other.', 'label 1 of sub.other.org is other.');

is($dn1->data(), "\5azone\3org\5other\3org\0", 'data()');

$dn1->set_data("\5foo\3com\5bar\3net\0");
is($dn1->data(), "\5foo\3com\5bar\3net\0", 'set_data()');

my $dni = DNS::LDNS::RData->new(
    LDNS_RDF_TYPE_DNAME, 'not..valid.org');
is($dni, undef, 'Invalid dname not_valid.org');

my $wc = DNS::LDNS::RData->new(LDNS_RDF_TYPE_DNAME, '*.other.org');
ok($wc->is_wildcard, '*.other.org is a wildcard');
ok(!$dn3->is_wildcard, 'sub.other.org is not a wildcard');
ok($dn3->matches_wildcard($wc), 'sub.other.org matches *.other.org');
ok(!$dn4->matches_wildcard($wc), 'adder.org does not match *.other.org');

is($dn3->compare($dn4), 1, 'sub.other.org > adder.org');
is($dn4->compare($dn3), -1, 'adder.org < sub.other.org');
