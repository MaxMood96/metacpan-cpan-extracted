=pod

=head1 NAME

unit/array/pop.t - tests the C<pop> method

=cut

use Test2::V0;
use Sub::HandlesVia::XS;

subtest "Basic" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_pop( "Local::test_1" => {
		arr_source  => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
	} );

	my $arr = [ 10..13 ];
	is( Local::test_1( $arr ), 13 );
	is( $arr, [ 10..12 ] );
	is( Local::test_1( $arr ), 12 );
	is( $arr, [ 10..11 ] );
	is( Local::test_1( $arr ), 11 );
	is( $arr, [ 10 ] );
	is( Local::test_1( $arr ), 10 );
	is( $arr, [] );
	is( Local::test_1( $arr ), undef );
	is( $arr, [] );
	is( Local::test_1( $arr ), undef );
	is( $arr, [] );
};

done_testing;
