=pod

=head1 NAME

unit/array/is_empty.t - tests the C<is_empty> method

=cut

use Test2::V0;
use Sub::HandlesVia::XS;

subtest "Basic" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_is_empty( "Local::test_1" => {
		arr_source  => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
	} );

	my $arr = [ 10..13 ];
	ok( !Local::test_1( $arr ) );
	push @$arr, 99;
	ok( !Local::test_1( $arr ) );
	@$arr = ();
	ok( Local::test_1( $arr ) );
	push @$arr, 99;
	ok( !Local::test_1( $arr ) );
};

done_testing;
