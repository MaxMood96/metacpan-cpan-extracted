=pod

=head1 NAME

unit/array/accessor.t - tests the C<accessor> method

=head1 DESCRIPTION

Also exercises the different C<arr_source> options fairly thoroughly.

=cut

use Test2::V0;
use Sub::HandlesVia::XS;
use Types::Common qw( Int Num );

my $BASIC_TESTS = sub {
	my $f = shift;
	my $arr = shift;
	my $getter = shift || sub { shift; };

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

	my $e = dies {
		$f->($arr);
	};
	like $e, qr/^Wrong number of parameters/, 'Type fail';

	$f->($arr,  0, 66);
	$f->($arr, -1, 99);
	is( $getter->($arr), [ 66, 11..13, 99 ] );
	
	$f->($arr, 9, 100);
	is( $getter->($arr)->[9], 100 );
};

subtest 'Accessor operating directly on array, no curried arguments' => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_accessor( "Local::test_1" => {
		arr_source         => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
	} );

	subtest "Plain invocant" => sub { $BASIC_TESTS->( \&Local::test_1, [ 10 .. 14 ] ) };
	subtest "Blessed invocant" => sub { $BASIC_TESTS->( \&Local::test_1, bless( [ 10 .. 14 ], 'Local' ) ) };
};

subtest 'Accessor operating directly on array, curried index' => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_accessor( "Local::test_2" => {
		arr_source         => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
		index              => 2,
	} );

	my $arr = [ 10 .. 14 ];
	is( Local::test_2($arr), 12 );

	Local::test_2($arr, 'XX');
	is( $arr, [ 10, 11, 'XX', 13, 14 ] );
};

subtest 'Accessor operating directly on array, curried index and value' => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_accessor( "Local::test_3" => {
		arr_source         => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
		index              => 2,
		curried_sv         => 'xx',
	} );

	my $arr = [ 10 .. 14 ];
	is( Local::test_3($arr), 'xx' );
	is( $arr, [ 10, 11, 'xx', 13, 14 ] );
};

subtest 'Accessor operating directly on array, no curried arguments, type check, no coercion' => sub {
	my $type = Int;
	my ( $coderef, $flags ) = Sub::HandlesVia::XS->TypeInfo( $type );
	is($flags, Sub::HandlesVia::XS::TYPE_BASE_INT);
	
	Sub::HandlesVia::XS::INSTALL_shvxs_array_accessor( "Local::test_4" => {
		arr_source         => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
		element_type       => $flags,
		element_type_cv    => $coderef,
	} );

	subtest "Plain invocant" => sub { $BASIC_TESTS->( \&Local::test_4, [ 10 .. 14 ] ) };
	subtest "Blessed invocant" => sub { $BASIC_TESTS->( \&Local::test_4, bless( [ 10 .. 14 ], 'Local' ) ) };

	my $arr = [ 10 .. 14 ];
	my $e = dies {
		Local::test_4($arr, 0, 31.1);
	};
	like $e, qr/^Value "31.1" did not pass type constraint "Int" \(in ._.2.\)/, 'Type fail';
};

subtest 'Accessor operating directly on array, no curried arguments, type check and coercion' => sub {
	my $type = Int->plus_coercions( Num, sub { int $_ } );
	my ( $coderef, $flags ) = Sub::HandlesVia::XS->TypeInfo( $type );
	is($flags, Sub::HandlesVia::XS::TYPE_BASE_INT);
	
	Sub::HandlesVia::XS::INSTALL_shvxs_array_accessor( "Local::test_5" => {
		arr_source         => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
		element_type       => $flags,
		element_type_cv    => $coderef,
		element_coercion_cv=> $type->coercion->compiled_coercion,
	} );

	subtest "Plain invocant" => sub { $BASIC_TESTS->( \&Local::test_5, [ 10 .. 14 ] ) };
	subtest "Blessed invocant" => sub { $BASIC_TESTS->( \&Local::test_5, bless( [ 10 .. 14 ], 'Local' ) ) };
	
	my $arr = [ 10 .. 14 ];
	Local::test_5($arr, 0, 31.1);
	is( $arr, [ 31, 11..13, 14 ], 'Type coercion' );
	
	my $e = dies {
		Local::test_4($arr, 0, 'Hello world');
	};
	like $e, qr/^Value "Hello world" did not pass type constraint "Int" \(in ._.2.\)/, 'Type fail';
};

subtest 'Accessor operating on array in an array, no curried arguments' => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_accessor( "Local::test_6" => {
		arr_source         => Sub::HandlesVia::XS::ARRAY_SRC_DEREF_ARRAY,
		arr_source_index   => 2,
	} );

	subtest "Plain invocant" => sub { $BASIC_TESTS->( \&Local::test_6, [ foo => bar => [ 10 .. 14 ] ], sub { shift->[2] } ) };
	subtest "Blessed invocant" => sub { $BASIC_TESTS->( \&Local::test_6, bless( [ foo => bar => [ 10 .. 14 ] ], 'Local' ), sub { shift->[2] } ) };
};

subtest 'Accessor operating on array in a hash, no curried arguments' => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_accessor( "Local::test_7" => {
		arr_source         => Sub::HandlesVia::XS::ARRAY_SRC_DEREF_HASH,
		arr_source_string  => 'foo',
	} );

	subtest "Plain invocant" => sub { $BASIC_TESTS->( \&Local::test_7, { foo => [ 10 .. 14 ] }, sub { shift->{foo} } ) };
	subtest "Blessed invocant" => sub { $BASIC_TESTS->( \&Local::test_7, bless( { foo => [ 10 .. 14 ] }, 'Local' ), sub { shift->{foo} } ) };
};

subtest 'Accessor operating on array behind a scalarref, no curried arguments' => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_accessor( "Local::test_8" => {
		arr_source         => Sub::HandlesVia::XS::ARRAY_SRC_DEREF_SCALAR,
	} );

	subtest "Plain invocant" => sub { $BASIC_TESTS->( \&Local::test_8, \[ 10 .. 14 ], sub { ${+shift} } ) };
	subtest "Blessed invocant" => sub { $BASIC_TESTS->( \&Local::test_8, bless( \[ 10 .. 14 ], 'Local' ), sub { ${+shift} } ) };
};

subtest 'Accessor operating on array returned by an object, no curried arguments' => sub {
	
	{
		package Local::Thing;
		our $zzz = 0;
		sub zzz {
			$zzz++;
			shift->{foo};
		}
	}
	
	Sub::HandlesVia::XS::INSTALL_shvxs_array_accessor( "Local::test_9" => {
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
