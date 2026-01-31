=pod

=head1 NAME

unit/string/nei.t - tests the C<nei> method

=cut

use Test2::V0;
use Sub::HandlesVia::XS;

subtest "Basic" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_string_nei( "Local::test_1" => {
		str_source  => Sub::HandlesVia::XS::STR_SRC_INVOCANT,
	} );

	ok( !Local::test_1( 'foo', 'foo' ) );
	ok( !Local::test_1( 'foo', 'FOO' ) );
	ok( Local::test_1( 'foo', 'bar' ) );
};

subtest "Curried SV" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_string_nei( "Local::test_2" => {
		str_source  => Sub::HandlesVia::XS::STR_SRC_INVOCANT,
		curried_sv  => 'foo',
	} );

	ok( !Local::test_2( 'foo' ) );
	ok( !Local::test_2( 'FOO' ) );
	ok( Local::test_2( 'bar' ) );
};

done_testing;
