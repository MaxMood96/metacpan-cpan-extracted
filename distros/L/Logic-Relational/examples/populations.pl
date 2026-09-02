#!/usr/bin/env perl

use v5.38;
use lib ( '../lib', 'lib' );
use Logic::Relational::Syntax;

logic CountryPopulations {

	# Country facts from "Worldometer"
    facts {

        # country population
        population( 'India',         1_476_625_576 );
        population( 'China',         1_412_914_089 );
        population( 'United States', 349_035_494 );
        population( 'Indonesia',     287_886_782 );
        population( 'Pakistan',      259_299_791 );
        population( 'Nigeria',       242_431_832 );
        population( 'Brazil',        213_562_666 );
        population( 'Bangladesh',    177_818_044 );
        population( 'Russia',        143_394_458 );
        population( 'Ethiopia',      138_902_185 );

        # area in square kilometres
        area( 'India',         2_973_190 );
        area( 'China',         9_388_211 );
        area( 'United States', 9_147_420 );
        area( 'Indonesia',     1_811_570 );
        area( 'Pakistan',      770_880 );
        area( 'Nigeria',       910_770 );
        area( 'Brazil',        8_358_140 );
        area( 'Bangladesh',    130_170 );
        area( 'Russia',        16_376_870 );
        area( 'Ethiopia',      1_000_000 );
    }

	# state that the population is $p, area is $q, and density is $p/$q
    rule density( $country, $density ) {
        fresh my ( $p, $q );
        population( $country, $p );
        area( $country, $q );
        $density is $p / $q;
    }

}

say "What is the population density of China?";
query CountryPopulations::density( 'China', fresh my $d1 )->my $q1;
my $ans1 = $q1->first_value($d1);
say "\t", sprintf("%.1f", $ans1), " people per square kilometre.\n";

say "Country population densities in order:";
query CountryPopulations::density( fresh my $c, fresh my $d2 )->my $q2;
my @records;
while (my $res = $q2->next) {
	push @records, [$res->value($c), $res->value($d2)];
}
my @sorted = sort { $b->[1] <=> $a->[1] } @records;

foreach my $r (@sorted) {
	say $r->[0], ": ", sprintf("%.1f", $r->[1]), " people per square kilometre.";
}


