=pod

=head1 NAME

unit/array/join.t - tests the C<join> method

=cut

use Test2::V0;
use Sub::HandlesVia::XS;

subtest "Basic" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_join( "Local::test_1" => {
		arr_source  => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
	} );

	my $arr = [ 10..13 ];
	is( Local::test_1( $arr ), '10,11,12,13' );
	is( Local::test_1( $arr, 'x' ), '10x11x12x13' );
};

subtest "Curried SV" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_join( "Local::test_2" => {
		arr_source  => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
		curried_sv  => ':',
	} );

	my $arr = [ 10..13 ];
	is( Local::test_2( $arr ), '10:11:12:13' );
};

done_testing;
