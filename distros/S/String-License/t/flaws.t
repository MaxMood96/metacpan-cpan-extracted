use v5.20;
use feature qw(signatures);
no warnings qw(experimental::signatures);

use Test2::V0;

use Path::Tiny;

use lib 't/lib';
use Uncruft;

use String::License;
use String::License::Naming::Custom;

plan 20;

my $naming = String::License::Naming::Custom->new;

sub parse ($path_string)
{
	my ( $path, $string, $license );

	$path   = path($path_string);
	$string = uncruft( $path->slurp_utf8 );

	$license = String::License->new(
		string => $string,
		naming => $naming,
	)->as_text;

	return $license;
}

path('t/flaws/fsf_address')->visit(
	sub {
		note $_;
		like parse($_), qr/ \[(?:mis-spelled|obsolete) FSF postal address /;
	}
);

path('t/flaws/no_fsf_address')->visit(
	sub {
		note $_;
		unlike parse($_), qr/ \[(?:mis-spelled|obsolete) FSF postal address /;
	}
);

path('t/flaws/generated')->visit(
	sub {
		note $_;
		like parse($_), qr/\Q [generated file]/;
	}
);

unlike parse('t/SPDX/BSL-1.0.txt'), qr/\Q [generated file]/,
	'false positive: BSL-1.0 license fulltext';

done_testing;
