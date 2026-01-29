#! perl

use strict;
use warnings;

use Test::More;

use Time::Spec;

sub round_to {
	my ($number, $offset) = @_;
	my $factor = 10 ** $offset;
	return $factor * int($number / $factor + 0.5);
}

my $spec0 = Time::Spec->new_from_pair(3, 600000000);
is $spec0->sec, 3;
is $spec0->nsec, 600000000;
is round_to($spec0->to_float, -1), 3.6;
is round_to($spec0 + 1, -1), 4.6;
my ($sec, $nsec) = $spec0->to_pair;
is $sec, 3;
is $nsec, 600000000;

my $spec1 = Time::Spec->new(3.6);
is $spec1->sec, 3;
is round_to($spec1->nsec, 2), 600000000;
is round_to($spec1->to_float, -1), 3.6;
is round_to($spec1 + 1, -1), 4.6;

my $spec2 = Time::Spec->new(3600);
is $spec2->sec, 3600;
is $spec2->nsec, 0;

done_testing;
