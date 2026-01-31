=pod

=head1 NAME

unit/string/gti.t - tests the C<gti> method

=cut

use Test2::V0;
use Sub::HandlesVia::XS;

subtest "Basic" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_string_gti( "Local::test_1" => {
		str_source  => Sub::HandlesVia::XS::STR_SRC_INVOCANT,
	} );

	ok( !Local::test_1( 'a', 'b' ) );
	ok( Local::test_1( 'b', 'a' ) );
	ok( !Local::test_1( 'a', 'a' ) );
	ok( !Local::test_1( 'a', 'B' ) );
	ok( Local::test_1( 'B', 'a' ) );
	ok( !Local::test_1( 'a', 'A' ) );
	ok( !Local::test_1( 'A', 'a' ) );
};

done_testing;
