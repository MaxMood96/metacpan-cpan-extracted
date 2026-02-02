=pod

=head1 NAME

unit/array/none.t - tests the C<none> method

=cut

use Test2::V0;
use Sub::HandlesVia::XS;

subtest "Basic" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_none( "Local::test_1" => {
		arr_source  => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
	} );

	ok( Local::test_1( [1..9], sub { $_ >= 10 } ) );
	ok( !Local::test_1( [1..10], sub { $_ >= 10 } ) );
};

done_testing;
