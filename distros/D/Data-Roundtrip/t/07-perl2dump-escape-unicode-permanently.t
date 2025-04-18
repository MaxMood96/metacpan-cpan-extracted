#!perl -T

use 5.008;
use strict;
use warnings;

use utf8;

our $VERSION='0.29';

use Test::More;
use Test2::Plugin::UTF8;
#use Test::Deep;

my $num_tests = 0;

# always escape unicode (default Dump and Dumper behaviour)
# this is as efficient as no-unicode-escape-permanently
use Data::Roundtrip qw/:all dump2perl unicode-escape-permanently/;

my $abc = "abc-αβγ";
my $xyz = "χψζ-xyz";

my $json_string = <<EOS;
{"$abc":"$xyz"}
EOS
$json_string =~ s/\s*$//;

my $yaml_string = <<EOS;
---
$abc: $xyz
EOS
#$yaml_string =~ s/\s*$//;

my $perl_var = {$abc => $xyz};

# without escaping, no \x{3b1} !
my $adump_p1 = perl2dump($perl_var,
	{
		'terse'=> 1,
		'dont-bloody-escape-unicode'=> 1,
	}
);
ok(defined $adump_p1, "perl2dump() called."); $num_tests++;
ok($adump_p1=~/\\x\{3b1\}/i, "perl2dump() unicode escaped."); $num_tests++;

my $adump_p2 = perl2dump_filtered($perl_var,
	{
		'terse'=> 1,
		'dont-bloody-escape-unicode'=> 1,
	}
);
ok(defined $adump_p2, "perl2dump_filtered() called."); $num_tests++;
ok($adump_p2=~/(\\x\{3b1\})/i, "perl2dump_filtered() unicode escaped."); $num_tests++;

# dump2perl
my $result_p1 = dump2perl($adump_p1);
ok(defined $result_p1, "dump2perl() called."); $num_tests++;
for my $k (keys %$result_p1){
	ok(exists $perl_var->{$k}, "perl2dump_filtered() and dump2perl() key exists."); $num_tests++;
	ok($perl_var->{$k} eq $result_p1->{$k}, "perl2dump_filtered() and dump2perl() values are the same."); $num_tests++;
}
for my $k (keys %$perl_var){
	ok(exists $result_p1->{$k}, "perl2dump_filtered() and dump2perl() key exists (other way round)."); $num_tests++;
}
my $result_p2 = dump2perl($adump_p2);
ok(defined $result_p2, "dump2perl() called."); $num_tests++;
for my $k (keys %$result_p2){
	ok(exists $perl_var->{$k}, "perl2dump_filtered() and dump2perl() key exists."); $num_tests++;
	ok($perl_var->{$k} eq $result_p2->{$k}, "perl2dump_filtered() and dump2perl() values are the same."); $num_tests++;
}
for my $k (keys %$perl_var){
	ok(exists $result_p2->{$k}, "perl2dump_filtered() and dump2perl() key exists (other way round)."); $num_tests++;
}

### now with escaping but because it is permanent,
# it will not be escaped,
# 'dont-bloody-escape-unicode'=>0 will have no effect
$adump_p1 = perl2dump_filtered($perl_var,
	{
		'terse'=> 1,
		'dont-bloody-escape-unicode'=> 0,
	}
);
ok(defined $adump_p1, "perl2dump_filtered() called."); $num_tests++;
ok($adump_p1=~/\\x\{3b1\}/i, "perl2dump_filtered() unicode escaped."); $num_tests++;

$adump_p2 = perl2dump_filtered($perl_var,
	{
		'terse'=> 1,
		'dont-bloody-escape-unicode'=> 0,
	}
);
ok(defined $adump_p2, "perl2dump_filtered() called."); $num_tests++;
ok($adump_p2=~/\\x\{3b1\}/i, "perl2dump_filtered() unicode escaped."); $num_tests++;

# dump2perl
$result_p1 = dump2perl($adump_p1);
ok(defined $result_p1, "dump2perl() called."); $num_tests++;
for my $k (keys %$result_p1){
	ok(exists $perl_var->{$k}, "perl2dump_filtered() and dump2perl() key exists."); $num_tests++;
	ok($perl_var->{$k} eq $result_p1->{$k}, "perl2dump_filtered() and dump2perl() values are the same."); $num_tests++;
}
for my $k (keys %$perl_var){
	ok(exists $result_p1->{$k}, "perl2dump_filtered() and dump2perl() key exists (other way round)."); $num_tests++;
}
$result_p2 = dump2perl($adump_p2);
ok(defined $result_p2, "dump2perl() called."); $num_tests++;
for my $k (keys %$result_p2){
	ok(exists $perl_var->{$k}, "perl2dump_filtered() and dump2perl() key exists."); $num_tests++;
	ok($perl_var->{$k} eq $result_p2->{$k}, "perl2dump_filtered() and dump2perl() values are the same."); $num_tests++;
}
for my $k (keys %$perl_var){
	ok(exists $result_p2->{$k}, "perl2dump_filtered() and dump2perl() key exists (other way round)."); $num_tests++;
}

done_testing($num_tests);
