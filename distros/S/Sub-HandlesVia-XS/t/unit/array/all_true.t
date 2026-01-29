=pod

=head1 NAME

unit/array/all_true.t - tests the C<all_true> method

=cut

use Test2::V0;
use Sub::HandlesVia::XS;

subtest "Basic" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_all_true( "Local::test_1" => {
		arr_source  => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
	} );

	ok( Local::test_1( [10..13], sub { $_ >= 10 } ) );
	ok( Local::test_1( [10..13], sub { $_[0] >= 10 } ) );
	ok( !Local::test_1( [9..13], sub { $_ >= 10 } ) );
	ok( !Local::test_1( [9..13], sub { $_[0] >= 10 } ) );
};

subtest "Curried" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_all_true( "Local::test_2" => {
		arr_source  => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
		callback    => sub { $_[0] >= 10 },
	} );

	ok( Local::test_2( [10..13] ) );
	ok( Local::test_2( [10..13] ) );
	ok( !Local::test_2( [9..13] ) );
	ok( !Local::test_2( [9..13] ) );
};

done_testing;
