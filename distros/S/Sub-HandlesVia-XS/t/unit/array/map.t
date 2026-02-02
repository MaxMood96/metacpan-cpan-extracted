=pod

=head1 NAME

unit/array/map.t - tests the C<map> method

=cut

use Test2::V0;
use Sub::HandlesVia::XS;

subtest "Basic" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_map( "Local::test_1" => {
		arr_source  => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
	} );
	
	is( [Local::test_1( [1..3], sub { $_ + 1 } )], [2..4] );
	is( scalar Local::test_1( [1..3], sub { $_ + 1 } ), 3 );
	is( [Local::test_1( [1..3], sub { ( $_, $_ + 1 ) } )], [1,2,2,3,3,4] );
	is( scalar Local::test_1( [1..3], sub { ( $_, $_ + 1 ) } ), 6 );
};

subtest "Curried" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_map( "Local::test_2" => {
		arr_source  => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
		callback    => sub { $_ + 1 },
	} );

	is( [Local::test_2( [1..3] )], [2..4] );
};

done_testing;
