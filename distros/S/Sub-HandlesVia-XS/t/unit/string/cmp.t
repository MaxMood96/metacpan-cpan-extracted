=pod

=head1 NAME

unit/string/cmp.t - tests the C<cmp> method

=cut

use Test2::V0;
use Sub::HandlesVia::XS;

subtest "Basic" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_string_cmp( "Local::test_1" => {
		str_source  => Sub::HandlesVia::XS::STR_SRC_INVOCANT,
	} );

	ok( Local::test_1( 'a', 'a' ) == 0 );
	ok( Local::test_1( 'a', 'b' ) < 0 );
	ok( Local::test_1( 'b', 'a' ) > 0 );
	ok( Local::test_1( 'A', 'a' ) < 0 );
	ok( Local::test_1( 'B', 'a' ) < 0 );
};

done_testing;
