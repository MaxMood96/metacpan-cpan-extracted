=pod

=head1 NAME

unit/array/count.t - tests the C<count> method

=cut

use Test2::V0;
use Sub::HandlesVia::XS;

subtest "Basic" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_count( "Local::test_1" => {
		arr_source  => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
	} );

	my $arr = [ 10..13 ];
	is( Local::test_1( $arr ), 4 );
	push @$arr, 99;
	is( Local::test_1( $arr ), 5 );
};

done_testing;
