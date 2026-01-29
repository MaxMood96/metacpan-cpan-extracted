=pod

=head1 NAME

unit/array/peekend.t - tests the C<peekend> method

=cut

use Test2::V0;
use Sub::HandlesVia::XS;

subtest "Basic" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_peekend( "Local::test_1" => {
		arr_source  => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
	} );

	my $arr = [ 10..13 ];
	is( Local::test_1( $arr ), 13 );
};

done_testing;
