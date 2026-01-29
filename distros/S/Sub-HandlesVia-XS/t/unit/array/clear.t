=pod

=head1 NAME

unit/array/clear.t - tests the C<clear> method

=cut

use Test2::V0;
use Sub::HandlesVia::XS;

subtest "Basic" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_clear( "Local::test_1" => {
		arr_source  => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
	} );

	my $arr = [ 1..9 ];
	isnt( $arr, [] );
	Local::test_1( $arr );
	is( $arr, [] );
};

done_testing;
