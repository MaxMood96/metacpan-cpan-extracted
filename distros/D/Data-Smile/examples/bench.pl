#!/usr/bin/env perl

use strict;
use warnings;
use feature qw( say );

use Benchmark qw( cmpthese );
use FindBin qw( $Bin );
use lib "$Bin/../lib";

my $data = build_data();
my %codecs;

if ( eval 'require Data::Smile::PP; 1' ) {
	$codecs{'Data::Smile::PP'} = {
		encode => sub {
			return Data::Smile::PP::encode_smile( $data );
		},
		decode => sub {
			my ( $blob ) = @_;
			return Data::Smile::PP::decode_smile( $blob );
		},
	};
}

if ( eval 'require Data::Smile::XS; 1' ) {
	$codecs{'Data::Smile::XS'} = {
		encode => sub {
			return Data::Smile::XS::encode_smile( $data );
		},
		decode => sub {
			my ( $blob ) = @_;
			return Data::Smile::XS::decode_smile( $blob );
		},
	};
}

if ( eval 'require JSON::PP; 1' ) {
	$codecs{'JSON::PP'} = {
		encode => sub {
			return JSON::PP::encode_json( $data );
		},
		decode => sub {
			my ( $blob ) = @_;
			return JSON::PP::decode_json( $blob );
		},
	};
}

if ( eval 'require JSON::XS; 1' ) {
	$codecs{'JSON::XS'} = {
		encode => sub {
			return JSON::XS::encode_json( $data );
		},
		decode => sub {
			my ( $blob ) = @_;
			return JSON::XS::decode_json( $blob );
		},
	};
}

if ( eval 'require Cpanel::JSON::XS; 1' ) {
	$codecs{'Cpanel::JSON::XS'} = {
		encode => sub {
			return Cpanel::JSON::XS::encode_json( $data );
		},
		decode => sub {
			my ( $blob ) = @_;
			return Cpanel::JSON::XS::decode_json( $blob );
		},
	};
}

if ( eval 'require YAML::PP; 1' ) {
	$codecs{'YAML::PP'} = {
		encode => sub {
			return YAML::PP::Dump( $data );
		},
		decode => sub {
			my ( $blob ) = @_;
			return YAML::PP::Load( $blob );
		},
	};
}

if ( eval 'require YAML::XS; 1' ) {
	$codecs{'YAML::XS'} = {
		encode => sub {
			return YAML::XS::Dump( $data );
		},
		decode => sub {
			my ( $blob ) = @_;
			return YAML::XS::Load( $blob );
		},
	};
}

my %encoded = map {
	my $name = $_;
	$name => $codecs{ $name }->{encode}->();
} keys %codecs;

say "Encoded size comparison (bytes):";
for my $name ( sort { length( $encoded{$a} ) <=> length( $encoded{$b} ) } keys %encoded ) {
	say sprintf "%20s : %10d", $name, length( $encoded{ $name } );
}

say "\nEncoding benchmark:";
cmpthese(
	-3,
	{
		map {
			my $name = $_;
			$name => sub {
				return $codecs{ $name }->{encode}->();
			};
		} sort keys %codecs
	}
);

say "\nDecoding benchmark:";
cmpthese(
	-3,
	{
		map {
			my $name = $_;
			$name => sub {
				return $codecs{ $name }->{decode}->( $encoded{ $name } );
			};
		} sort keys %codecs
	}
);

say "\nRoundtrip benchmark (encode + decode):";
cmpthese(
	-3,
	{
		map {
			my $name = $_;
			$name => sub {
				my $blob = $codecs{ $name }->{encode}->();
				return $codecs{ $name }->{decode}->( $blob );
			};
		} sort keys %codecs
	}
);

sub build_data {
	my @records;
	for my $i ( 1 .. 500 ) {
		my @measurements = map {
			{
				index => $_,
				value => ( $i * $_ ) % 97,
				flags => [
					( $_ % 2 == 0 ? 'even' : 'odd' ),
					( $_ % 3 == 0 ? 'mod3' : 'nomod3' ),
				],
			}
		} 1 .. 15;

		push @records, {
			id => $i,
			name => sprintf( 'record-%05d', $i ),
			tags => [ map { "tag$_" } 1 .. 8 ],
			metrics => {
				average => ( $i % 100 ) / 3,
				max => $i + 10,
				min => $i - 10,
				history => [ map { ( $i + $_ ) % 1000 } 1 .. 30 ],
			},
			measurements => \@measurements,
			nested => {
				alpha => {
					beta => {
						gamma => [
							map {
								{
									seq => $_,
									text => "value-$i-$_",
								}
							} 1 .. 12
						],
					},
				},
			},
		};
	}

	return {
		generated_at => scalar gmtime,
		note => 'Benchmark payload with nested arrays and hashes',
		records => \@records,
		lookup => {
			map {
				my $n = $_;
				"key$n" => {
					active => ( $n % 2 ? 1 : 0 ),
					parts => [ map { "p$n-$_" } 1 .. 6 ],
				}
			} 1 .. 250
		},
	};
}

