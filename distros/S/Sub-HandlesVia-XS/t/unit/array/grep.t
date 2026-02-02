=pod

=head1 NAME

unit/array/grep.t - tests the C<grep> method

=cut

use Test2::V0;
use Sub::HandlesVia::XS;

subtest "Basic" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_grep( "Local::test_1" => {
		arr_source  => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
	} );
	
	is( [ Local::test_1( [10..13], sub { $_ > 11 } ) ], [12,13] );
	is( [ Local::test_1( [2..5], sub { $_ > 11 } ) ], [] );
	is( scalar Local::test_1( [10..13], sub { $_ > 11 } ), 2 );
	is( scalar Local::test_1( [2..5], sub { $_ > 11 } ), 0 );
};

subtest "Curried" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_grep( "Local::test_2" => {
		arr_source  => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
		callback    => sub { $_ > 11 },
	} );

	is( [ Local::test_2( [10..13] ) ], [12,13] );
	is( [ Local::test_2( [2..5] ) ], [] );
	is( scalar Local::test_2( [10..13] ), 2 );
	is( scalar Local::test_2( [2..5] ), 0 );
};

done_testing;
