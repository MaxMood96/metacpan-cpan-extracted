=pod

=head1 NAME

unit/array/get.t - tests the C<get> method

=head1 DESCRIPTION

Also exercises the different C<arr_source> options fairly thoroughly.

=cut

use Test2::V0;
use Sub::HandlesVia::XS;
use Types::Common qw( Int Num );

my $BASIC_TESTS = sub {
	my $f = shift;
	my $arr = shift;

	is( $f->($arr, 0), 10 );
	is( $f->($arr, 1), 11 );
	is( $f->($arr, 2), 12 );
	is( $f->($arr, 3), 13 );
	is( $f->($arr, 4), 14 );
	is( $f->($arr, -1), 14 );
	is( $f->($arr, -2), 13 );
	is( $f->($arr, -3), 12 );
	is( $f->($arr, -4), 11 );
	is( $f->($arr, -5), 10 );
};

subtest 'Get operating directly on array, no curried arguments' => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_get( "Local::test_1" => {
		arr_source         => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
	} );

	subtest "Plain invocant" => sub { $BASIC_TESTS->( \&Local::test_1, [ 10 .. 14 ] ) };
	subtest "Blessed invocant" => sub { $BASIC_TESTS->( \&Local::test_1, bless( [ 10 .. 14 ], 'Local' ) ) };
};

subtest 'Get operating directly on array, curried index' => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_get( "Local::test_2" => {
		arr_source         => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
		index              => 2,
	} );

	my $arr = [ 10 .. 14 ];
	is( Local::test_2($arr), 12 );
};

subtest 'Get operating on array in an array, no curried arguments' => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_get( "Local::test_6" => {
		arr_source         => Sub::HandlesVia::XS::ARRAY_SRC_DEREF_ARRAY,
		arr_source_index   => 2,
	} );

	subtest "Plain invocant" => sub { $BASIC_TESTS->( \&Local::test_6, [ foo => bar => [ 10 .. 14 ] ], sub { shift->[2] } ) };
	subtest "Blessed invocant" => sub { $BASIC_TESTS->( \&Local::test_6, bless( [ foo => bar => [ 10 .. 14 ] ], 'Local' ), sub { shift->[2] } ) };
};

subtest 'Get operating on array in a hash, no curried arguments' => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_get( "Local::test_7" => {
		arr_source         => Sub::HandlesVia::XS::ARRAY_SRC_DEREF_HASH,
		arr_source_string  => 'foo',
	} );

	subtest "Plain invocant" => sub { $BASIC_TESTS->( \&Local::test_7, { foo => [ 10 .. 14 ] }, sub { shift->{foo} } ) };
	subtest "Blessed invocant" => sub { $BASIC_TESTS->( \&Local::test_7, bless( { foo => [ 10 .. 14 ] }, 'Local' ), sub { shift->{foo} } ) };
};

subtest 'Get operating on array behind a scalarref, no curried arguments' => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_get( "Local::test_8" => {
		arr_source         => Sub::HandlesVia::XS::ARRAY_SRC_DEREF_SCALAR,
	} );

	subtest "Plain invocant" => sub { $BASIC_TESTS->( \&Local::test_8, \[ 10 .. 14 ], sub { ${+shift} } ) };
	subtest "Blessed invocant" => sub { $BASIC_TESTS->( \&Local::test_8, bless( \[ 10 .. 14 ], 'Local' ), sub { ${+shift} } ) };
};

subtest 'Get operating on array returned by an object, no curried arguments' => sub {
	
	{
		package Local::Thing;
		our $zzz = 0;
		sub zzz {
			$zzz++;
			shift->{foo};
		}
	}
	
	Sub::HandlesVia::XS::INSTALL_shvxs_array_get( "Local::test_9" => {
		arr_source         => Sub::HandlesVia::XS::ARRAY_SRC_CALL_METHOD,
		arr_source_string  => 'zzz',
	} );
	
	subtest "Blessed invocant" => sub { $BASIC_TESTS->( \&Local::test_9, bless( { foo => [ 10 .. 14 ] }, 'Local::Thing' ), sub { shift->{foo} } ) };
	ok( $Local::Thing::zzz > 0, 'method was called' );
};

subtest 'Accessor operating on array returned by an object, bypassing accessor if hash key exists, no curried arguments' => sub {
	
	{
		package Local::Thing2;
		our $zzz = 0;
		sub zzz {
			$zzz++;
			shift->{foo} ||= [ 10 .. 14 ];
		}
	}
	
	Sub::HandlesVia::XS::INSTALL_shvxs_array_accessor( "Local::test_10" => {
		arr_source         => Sub::HandlesVia::XS::ARRAY_SRC_DEREF_HASH,
		arr_source_string  => 'foo',
		arr_source_fallback=> 'zzz',
	} );
	
	subtest "Blessed invocant" => sub { $BASIC_TESTS->( \&Local::test_10, bless( {}, 'Local::Thing2' ), sub { shift->{foo} } ) };
	ok( $Local::Thing2::zzz == 1, 'method was called only once' );
};

done_testing;
