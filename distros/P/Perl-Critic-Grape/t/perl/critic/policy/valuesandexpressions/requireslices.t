#!/usr/bin/perl

use strict;
use warnings;
use Perl::Critic;

use Test::More tests=>6;

my $failure=qr/chains.*as slices/;

subtest 'Valid hashes'=>sub {
	plan tests=>39;
	my $critic=Perl::Critic->new(-profile=>'NONE',-only=>1,-severity=>1);
	$critic->add_policy(-policy=>'Perl::Critic::Policy::ValuesAndExpressions::RequireSlices');
	#
	foreach my $code (
		q|$h{one}|,
		q|$h{one},other(),$h{two}|,
		q|$h{$one}|,
		q|$array[$h{one}]|,
		q|$hash{$h{one}}|,
		q|func($h{one})|,
		q|func($h{one}),func($h{two})|,
		q|int $h{one},int $h{two}|,
		#
		q|$h->{one}|,
		q|$h->{one},other(),$h->{two}|,
		q|$h->{$one}|,
		q|$array[$h->{one}]|,
		q|$hash{$h->{one}}|,
		q|func($h->{one})|,
		#
		q|$$h{one}|,
		q|$$h{one},other(),$$h{two}|,
		q|$$h{$one}|,
		q|$array[$$h{one}]|,
		q|$hash{$$h{one}}|,
		q|func($$h{one})|,
		#
		q|$h{one}{one}|,
		q|$h{one}{one},$h{two}{one}|,
		q|$h{one}{one},5,$h{one}{two}|,
		q|$h{one}{one},5,$h{one}{one},$h{two}{one}|,
		q|$array[$h{one}{one}]|,
		q|$hash{$h{one}{one}}|,
		q|func($h{one}{one})|,
		q|$h->{one}{one}|,
		q|$h->{one}{one},$h->{two}{one}|,
		q|$h->{one}->{one}|,
		q|$h->{one}->{one},$h->{two}->{one}|,
		#
		q|$h{one},$x,$h{two}|,
		q|$h{one},$h,$h{two}|,
		q|$h{one},$x+$h{two},$h{three}|,
		#
		q|one=>$hash{one},four=>4,two=>$hash{two}|,
		q|one=>$h{one},two=>$h{two}|, # not currently supported
		#
		q|@h{one}|,
		q|$h{one},@{$h{two}}|,
		q|$h{one},@{$h{two}},$h{three}|,
		#
	) {
		is_deeply([$critic->critique(\$code)],[],$code);
	}
};

subtest 'Invalid hashes'=>sub {
	plan tests=>39;
	my $critic=Perl::Critic->new(-profile=>'NONE',-only=>1,-severity=>1);
	$critic->add_policy(-policy=>'Perl::Critic::Policy::ValuesAndExpressions::RequireSlices');
	#
	foreach my $code (
		q|$h{one},$h{two}|,
		q|$h{one},$h{two},$h{three}|,
		q|$h{one},$h{two},other()|,
		q|$h{one},other(),$h{two},$h{three}|,
		q|$h{$one},$h{$two}|,
		q|$array[$h{one},$h{two},$h{three}]|,
		q|$hash{$h{one},$h{two},$h{three}}|,
		q|func($h{one},$h{two})|,
		#
		q|$h->{one},$h{two}|,
		q|$h->{one},$h{two},$h{three}|,
		q|$h->{one},$h{two},other()|,
		q|$h->{one},other(),$h->{two},$h->{three}|,
		q|$h->{$one},$h{$two}|,
		q|$array->[$h->{one},$h->{two},$h->{three}]|,
		q|$hash->{$h->{one},$h->{two},$h->{three}}|,
		q|func($h->{one},$h->{two})|,
		#
		q|$$h{one},$h{two}|,
		q|$$h{one},$h{two},$h{three}|,
		q|$$h{one},$h{two},other()|,
		q|$$h{one},other(),$$h{two},$$h{three}|,
		q|$$h{$one},$h{$two}|,
		q|$array->[$$h{one},$$h{two},$$h{three}]|,
		q|$hash->{$$h{one},$$h{two},$$h{three}}|,
		q|func($$h{one},$$h{two})|,
		#
		q|$h{one}{one},$h{one}{two}|,
		q|$array[$h{one}{one},$h{one}{two}]|,
		q|$hash{$h{one}{one},$h{one}{two}}|,
		q|$h{one}{one},5,$h{one}{one},$h{one}{two}|,
		q|$h->{one}{one},$h->{one}{two}|,
		q|$array[$h->{one}{one},$h->{one}{two}]|,
		q|$hash{$h->{one}{one},$h->{one}{two}}|,
		q|$h->{one}{one},5,$h->{one}{one},$h->{one}{two}|,
		q|$h->{one}->{one},$h->{one}->{two}|,
		q|$h->{one}->{one},5,$h->{one}->{one},$h->{one}->{two}|,
		#
		q|@h{one},@h{two}|,
		q|@h{one},$h{two}|,
		q|$h{one},@h{two}|,
		q|@h{qw/one two/},$h{three}|,
		q|$h{one},@{$h{two}},$h{three},$h{four}|,
		#
		# q|one=>$h{one},two=>$h{two}|, # not currently supported
		#
	) {
		like(($critic->critique(\$code))[0],$failure,$code);
	}
};

subtest 'Valid arrays'=>sub {
	plan tests=>32;
	my $critic=Perl::Critic->new(-profile=>'NONE',-only=>1,-severity=>1);
	$critic->add_policy(-policy=>'Perl::Critic::Policy::ValuesAndExpressions::RequireSlices');
	#
	foreach my $code (
		q|$a[1]|,
		q|$a[1],other(),$a[2]|,
		q|$a[$one]|,
		q|$hash{$a[1]}|,
		q|func($a[1])|,
		#
		q|$a->[1]|,
		q|$a->[1],other(),$a->[2]|,
		q|$a->[$one]|,
		q|$array[$a->[1]]|,
		q|$hash{$a->[1]}|,
		q|func($a->[1])|,
		#
		q|$$a[1]|,
		q|$$a[1],other(),$$a[2]|,
		q|$$a[$one]|,
		q|$array[$$a[1]]|,
		q|$hash{$$a[1]}|,
		q|func($$a[1])|,
		#
		q|$a[1][1]|,
		q|$a[1][1],$a[2][1]|,
		q|$a[1][1],5,$a[1][2]|,
		q|$a[1][1],5,$a[1][1],$a[2][1]|,
		q|$array[$a[1][1]]|,
		q|$hash{$a[1][1]}|,
		q|func($a[1][1])|,
		q|$a->[1][1]|,
		q|$a->[1][1],$a->[2][1]|,
		q|$a->[1]->[1]|,
		q|$a->[1]->[1],$a->[2]->[1]|,
		#
		q|$a[1],$x,$a[2]|,
		q|$a[1],$a,$a[2]|,
		q|$a[1],$x+$a[2],$a[3]|,
		#
		q|@a[1]|,
		#
	) {
		is_deeply([$critic->critique(\$code)],[],$code);
	}
};

subtest 'Invalid arrays'=>sub {
	plan tests=>38;
	my $critic=Perl::Critic->new(-profile=>'NONE',-only=>1,-severity=>1);
	$critic->add_policy(-policy=>'Perl::Critic::Policy::ValuesAndExpressions::RequireSlices');
	#
	foreach my $code (
		q|$a[1],$a[2]|,
		q|$a[1],$a[2],$a[3]|,
		q|$a[1],$a[2],other()|,
		q|$a[1],other(),$a[2],$a[3]|,
		q|$a{$one},$a{$two}|,
		q|$array[$a[1],$a[2],$a[3]]|,
		q|$hash{$a[1],$a[2],$a[3]}|,
		q|func($a[1],$a[2])|,
		#
		q|$a->[1],$a[2]|,
		q|$a->[1],$a[2],$a[3]|,
		q|$a->[1],$a[2],other()|,
		q|$a->[1],other(),$a->[2],$a->[3]|,
		q|$a->{$one},$a{$two}|,
		q|$array->[$a->[1],$a->[2],$a->[3]]|,
		q|$hash->{$a->[1],$a->[2],$a->[3]}|,
		q|func($a->[1],$a->[2])|,
		#
		q|$$a[1],$a[2]|,
		q|$$a[1],$a[2],$a[3]|,
		q|$$a[1],$a[2],other()|,
		q|$$a[1],other(),$$a[2],$$a[3]|,
		q|$$a{$one},$a{$two}|,
		q|$array->[$$a[1],$$a[2],$$a[3]]|,
		q|$hash->{$$a[1],$$a[2],$$a[3]}|,
		q|func($$a[1],$$a[2])|,
		#
		q|$a[1][1],$a[1][2]|,
		q|$array[$a[1][1],$a[1][2]]|,
		q|$hash{$a[1][1],$a[1][2]}|,
		q|$a[1][1],5,$a[1][1],$a[1][2]|,
		q|$a->[1][1],$a->[1][2]|,
		q|$array[$a->[1][1],$a->[1][2]]|,
		q|$hash{$a->[1][1],$a->[1][2]}|,
		q|$a->[1][1],5,$a->[1][1],$a->[1][2]|,
		q|$a->[1]->[1],$a->[1]->[2]|,
		q|$a->[1]->[1],5,$a->[1]->[1],$a->[1]->[2]|,
		#
		q|@a[1],@a[2]|,
		q|@a[1],$a[2]|,
		q|$a[1],@a[2]|,
		q|@a[1,2],$a[3]|,
		#
	) {
		like(($critic->critique(\$code))[0],$failure,$code);
	}
};

subtest 'Minimum settings'=>sub {
	plan tests=>14;
	my $critic=Perl::Critic->new(-profile=>'NONE',-only=>1,-severity=>1);
	$critic->add_policy(-policy=>'Perl::Critic::Policy::ValuesAndExpressions::RequireSlices',-params=>{minimum=>3});
	foreach my $code (
		q|$h{one},$h{two},$h{three}|,
		q|$a[0],$a[1],$a[2]|,
		q|@h{qw/one two/},@h{qw/three four/},@h{qw/five six/}|,
	) {
		like(($critic->critique(\$code))[0],$failure,$code);
	}
	foreach my $code (
		q|$h{one},$h{two}|,
		q|$a[0],$a[1]|,
		q|@h{qw/one two/},@h{qw/three four/}|,
	) {
		is_deeply([$critic->critique(\$code)],[],$code);
	}
	#
	$critic=Perl::Critic->new(-profile=>'NONE',-only=>1,-severity=>1);
	$critic->add_policy(-policy=>'Perl::Critic::Policy::ValuesAndExpressions::RequireSlices',-params=>{minimum=>4});
	foreach my $code (
		q|$h{one},$h{two},$h{three},$h{four}|,
		q|$a[0],$a[1],$a[2],$a[3]|,
	) {
		like(($critic->critique(\$code))[0],$failure,$code);
	}
	foreach my $code (
		q|$h{one},$h{two},$h{three}|,
		q|$a[0],$a[1],$a[2]|,
	) {
		is_deeply([$critic->critique(\$code)],[],$code);
	}
	#
	# These violate ProhibitSingleArgArraySlice but are a reasonable interpretation of minimum==1
	$critic=Perl::Critic->new(-profile=>'NONE',-only=>1,-severity=>1);
	$critic->add_policy(-policy=>'Perl::Critic::Policy::ValuesAndExpressions::RequireSlices',-params=>{minimum=>1});
	foreach my $code (
		q|$h{one}|,
		q|$a[0]|,
		q|@h{one}|,
		q|@a[0]|,
	) {
		like(($critic->critique(\$code))[0],$failure,$code);
	}
};

subtest 'Other'=>sub {
	plan tests=>5;
	my $critic=Perl::Critic->new(-profile=>'NONE',-only=>1,-severity=>1);
	$critic->add_policy(-policy=>'Perl::Critic::Policy::ValuesAndExpressions::RequireSlices');
	#
	foreach my $code (
		q|$var{one},$var[2]|,
		q|$var[2],$var{one}|,
		q|@var[2,3],$var{four}|,
	) {
		is_deeply([$critic->critique(\$code)],[],$code);
	}
	foreach my $code (
		q|$var{one},$var{two},$var[2]|,
		q|$var[2],$var[3],$var{one}|,
	) {
		like(($critic->critique(\$code))[0],$failure,$code);
	}
};

# Note:  If prepare_to_scan_document does NOT clear the cache,
# many of the above tests will fail, thus an effective test that
# the caching mechanism works as intended, since most ->location()
# will be the same in the above examples (eg 1,1,1,1,U)
