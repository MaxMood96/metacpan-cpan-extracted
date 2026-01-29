=pod

=head1 NAME

unit/array/push.t - tests the C<push> method

=cut

use Test2::V0;
use Sub::HandlesVia::XS;
use Types::Common -types;

subtest "Basic" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_push( "Local::test_1" => {
		arr_source  => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
	} );

	my $arr = [ 999 ];
	is( Local::test_1( $arr, 1 ), 2 );
	is( $arr, [ 999, 1 ] );
	is( Local::test_1( $arr, undef ), 3 );
	is( $arr, [ 999, 1, undef ] );
	is( Local::test_1( $arr, 2, 3, 4 ), 6 );
	is( $arr, [ 999, 1, undef, 2, 3, 4 ] );
	is( Local::test_1( $arr ), 6 );
	is( $arr, [ 999, 1, undef, 2, 3, 4 ] );
	is( Local::test_1( $arr, 5 ), 7 );
	is( $arr, [ 999, 1, undef, 2, 3, 4, 5 ] );
};

subtest "SHOULD_RETURN_VAL" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_push( "Local::test_2" => {
		arr_source             => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
		method_return_pattern  => Sub::HandlesVia::XS::SHOULD_RETURN_VAL,
	} );

	my $arr = [ 999 ];
	is( Local::test_2( $arr, 1 ), 1 );
	is( $arr, [ 999, 1 ] );
	is( Local::test_2( $arr, undef ), undef );
	is( $arr, [ 999, 1, undef ] );
	is( Local::test_2( $arr, 2, 3, 4 ), 4 );
	is( $arr, [ 999, 1, undef, 2, 3, 4 ] );
	is( Local::test_2( $arr ), undef );
	is( $arr, [ 999, 1, undef, 2, 3, 4 ] );
	is( Local::test_2( $arr, 5 ), 5 );
	is( $arr, [ 999, 1, undef, 2, 3, 4, 5 ] );
};

subtest "Typed" => sub {
	my $type = Int;
	my ( $coderef, $flags ) = Sub::HandlesVia::XS->TypeInfo( $type );
	is($flags, Sub::HandlesVia::XS::TYPE_BASE_INT);
	
	Sub::HandlesVia::XS::INSTALL_shvxs_array_push( "Local::test_3" => {
		arr_source             => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
		element_type           => $flags,
		element_type_cv        => $coderef,
		method_return_pattern  => Sub::HandlesVia::XS::SHOULD_RETURN_UNDEF,
	} );

	my $arr = [ 999 ];
	is( Local::test_3( $arr, 1 ), undef );
	is( $arr, [ 999, 1 ] );
	my $e = dies {
		Local::test_3( $arr, undef );
	};
	like $e, qr/^Undef did not pass type constraint "Int" \(in ._.1.\)/;
	is( $arr, [ 999, 1 ] );
	is( Local::test_3( $arr, 2, 3, 4 ), undef );
	is( $arr, [ 999, 1, 2, 3, 4 ] );
	is( Local::test_3( $arr ), undef );
	is( $arr, [ 999, 1, 2, 3, 4 ] );
	is( Local::test_3( $arr, 5 ), undef );
	is( $arr, [ 999, 1, 2, 3, 4, 5 ] );
};

subtest "Typed with coercion" => sub {
	my $type = Int->plus_coercions( Num, q{int $_} );
	my ( $coderef, $flags ) = Sub::HandlesVia::XS->TypeInfo( $type );
	is($flags, Sub::HandlesVia::XS::TYPE_BASE_INT);
	
	Sub::HandlesVia::XS::INSTALL_shvxs_array_push( "Local::test_4" => {
		arr_source             => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
		element_type           => $flags,
		element_type_cv        => $coderef,
		element_coercion_cv    => $type->coercion->compiled_coercion,
		method_return_pattern  => Sub::HandlesVia::XS::SHOULD_RETURN_VAL,
	} );

	my $arr = [ 999 ];
	is( Local::test_4( $arr, 1.1 ), 1 );
	is( $arr, [ 999, 1 ] );
	my $e = dies {
		Local::test_4( $arr, [] );
	};
	like $e, qr/^Reference \[\] did not pass type constraint "Int" \(in ._.1.\)/;
	is( $arr, [ 999, 1 ] );
	is( Local::test_4( $arr, 2.1, 3.1, 4.1 ), 4 );
	is( $arr, [ 999, 1, 2, 3, 4 ] );
	is( Local::test_4( $arr ), undef );
	is( $arr, [ 999, 1, 2, 3, 4 ] );
	is( Local::test_4( $arr, 5.1 ), 5 );
	is( $arr, [ 999, 1, 2, 3, 4, 5 ] );
};

done_testing;
