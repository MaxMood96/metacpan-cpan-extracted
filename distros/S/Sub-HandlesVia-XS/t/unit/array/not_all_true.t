=pod

=head1 NAME

unit/array/not_all_true.t - tests the C<not_all_true> method

=cut

use Test2::V0;
use Sub::HandlesVia::XS;

subtest "Basic" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_not_all_true( "Local::test_1" => {
		arr_source  => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
	} );

	ok( !Local::test_1( [1..9], sub { $_ < 10 } ) );
	ok( Local::test_1( [1..10], sub { $_ < 10 } ) );
	ok( Local::test_1( [11..15], sub { $_ < 10 } ) );
};

done_testing;
