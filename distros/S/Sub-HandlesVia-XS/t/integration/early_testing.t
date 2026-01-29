=pod

=head1 NAME

integration/early_testing.t - tests from very early development, proof of concept

=cut

use Test2::V0;
use Sub::HandlesVia::XS;
use Types::Common qw( Int );

subtest "Simple case" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_push(
		"Local::test_1",
		{
			arr_source         => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
		},
	);

	my $arr = [ 1, 2, 3 ];
	Local::test_1( $arr, 4, 5 );

	is( $arr, [ 1..5 ] );
};

subtest "Including type check" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_push(
		"Local::test_2",
		{
			arr_source         => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
			element_type       => Sub::HandlesVia::XS::TYPE_BASE_INT,
			element_type_cv    => Int->compiled_check,
		},
	);

	my $arr = [ 1, 2, 3 ];
	Local::test_2( $arr, 4, 5 );

	is( $arr, [ 1..5 ] );

	my $e = dies {
		Local::test_2( $arr, "Hello world" );
	};
	like $e, qr/did not pass type constraint/;

	is( $arr, [ 1..5 ] );

	my $e2 = dies {
		Local::test_2( $arr, 6, 7, undef, 9 );
	};
	like $e2, qr/did not pass type constraint/;

	is( $arr, [ 1..7 ] );
};

subtest "Hashref invocant" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_push(
		"Local::test_3",
		{
			arr_source         => Sub::HandlesVia::XS::ARRAY_SRC_DEREF_HASH,
			arr_source_string  => 'arr',
			element_type       => Sub::HandlesVia::XS::TYPE_BASE_INT,
			element_type_cv    => Int->compiled_check,
		},
	);

	Sub::HandlesVia::XS::INSTALL_shvxs_array_unshift(
		"Local::test_4",
		{
			arr_source         => Sub::HandlesVia::XS::ARRAY_SRC_DEREF_HASH,
			arr_source_string  => 'arr',
			element_type       => Sub::HandlesVia::XS::TYPE_BASE_INT,
			element_type_cv    => Int->compiled_check,
		},
	);

	Sub::HandlesVia::XS::INSTALL_shvxs_array_for_each(
		"Local::test_5",
		{
			arr_source         => Sub::HandlesVia::XS::ARRAY_SRC_DEREF_HASH,
			arr_source_string  => 'arr',
		},
	);

	Sub::HandlesVia::XS::INSTALL_shvxs_array_all(
		"Local::test_6",
		{
			arr_source         => Sub::HandlesVia::XS::ARRAY_SRC_DEREF_HASH,
			arr_source_string  => 'arr',
		},
	);

	Sub::HandlesVia::XS::INSTALL_shvxs_array_count(
		"Local::test_7",
		{
			arr_source         => Sub::HandlesVia::XS::ARRAY_SRC_DEREF_HASH,
			arr_source_string  => 'arr',
		},
	);

	my $arr = { arr => [ 1, 2, 3 ] };
	Local::test_3( $arr, 4, 5 );

	is( $arr, { arr => [ 1..5 ] } );

	my $e = dies {
		Local::test_3( $arr, "Hello world" );
	};
	like $e, qr/did not pass type constraint/;

	Local::test_4( $arr, -3, -2, -1, 0 );
	is( $arr, { arr => [ -3, -2, -1, 0, 1..5 ] } );
	
	my $str = '';
	Local::test_5( $arr, sub { $str .= $_; ++$_ } );
	is( $arr, { arr => [ -3, -2, -1, 0, 1..5 ] } );
	is( $str, join( q{}, -3, -2, -1, 0, 1..5 ) );

	is( [ Local::test_6($arr) ], [ -3, -2, -1, 0, 1..5 ] );
	
	is( [ Local::test_7($arr) ], [ 9 ] );

	my $str2 = '';
	my $str3 = '';
	Sub::HandlesVia::XS::INSTALL_shvxs_array_for_each(
		"Local::test_8",
		{
			arr_source         => Sub::HandlesVia::XS::ARRAY_SRC_DEREF_HASH,
			arr_source_string  => 'arr',
			callback           => sub { $str2 .= $_[0]; $str3 .= $_[1] },
		},
	);
	
	Local::test_8( $arr );
	is( $str2, join( q{}, -3, -2, -1, 0, 1..5 ) );
	is( $str3, join( q{}, 0..8 ) );
};

done_testing;
