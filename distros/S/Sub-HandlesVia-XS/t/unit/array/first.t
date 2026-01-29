=pod

=head1 NAME

unit/array/first.t - tests the C<first> method

=cut

use Test2::V0;
use Sub::HandlesVia::XS;

subtest "Basic" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_first( "Local::test_1" => {
		arr_source  => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
	} );
	
	is( Local::test_1( [10..13], sub { $_ > 11 } ), 12 );
	is( Local::test_1( [10..13], sub { $_[0] > 11 } ), 12 );
	is( Local::test_1( [2..5], sub { $_ > 11 } ), undef );
	is( Local::test_1( [2..5], sub { $_[0] > 11 } ), undef );
};

subtest "Curried" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_first( "Local::test_2" => {
		arr_source  => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
		callback    => sub { $_[0] > 11 },
	} );

	is( Local::test_2( [10..13] ), 12 );
	is( Local::test_2( [10..13] ), 12 );
	is( Local::test_2( [2..5] ), undef );
	is( Local::test_2( [2..5] ), undef );
};

done_testing;
