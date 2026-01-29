=pod

=head1 NAME

unit/array/all.t - tests the C<all> method

=head1 DESCRIPTION

Also exercises the different C<method_return_pattern> options fairly thoroughly.

=cut

use Test2::V0;
use Sub::HandlesVia::XS;

subtest "Basic" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_all( "Local::test_1" => {
		arr_source  => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
	} );

	is( [ Local::test_1( [10..13] ) ], [10..13] );
	is( scalar Local::test_1( [10..13] ), 4 );
};

{
	package Local::Test2;
	sub xxx { 1 }
}

subtest "SHOULD_RETURN_OUTBLESS" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_all( "Local::test_2" => {
		arr_source              => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
		method_return_pattern   => Sub::HandlesVia::XS::SHOULD_RETURN_OUTBLESS,
		method_return_class     => "Local::Test2",
	} );

	is( [ Local::test_2( [10..13] ) ], [10..13] );
	is( scalar Local::test_2( [10..13] ), bless([10..13], "Local::Test2") );
};

{
	package Local::Test3;
	sub xxx { bless { foo => pop }, shift }
}

subtest "SHOULD_RETURN_OUTBLESS with constructor" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_all( "Local::test_3" => {
		arr_source                 => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
		method_return_pattern      => Sub::HandlesVia::XS::SHOULD_RETURN_OUTBLESS,
		method_return_class        => "Local::Test3",
		method_return_constructor  => "xxx",
	} );

	is( [ Local::test_3( [10..13] ) ], [10..13] );
	is( scalar Local::test_3( [10..13] ), bless( { foo => [10..13] }, "Local::Test3") );
};

{
	package Local::Test4;
	sub xxx { 1 }
}

subtest "SHOULD_RETURN_OUTBLESS with arrayref behind scalaref" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_all( "Local::test_4" => {
		arr_source              => Sub::HandlesVia::XS::ARRAY_SRC_DEREF_SCALAR,
		method_return_pattern   => Sub::HandlesVia::XS::SHOULD_RETURN_OUTBLESS,
		method_return_class     => "Local::Test4",
	} );

	is( [ Local::test_4( \[10..13] ) ], [10..13] );
	is( scalar Local::test_4( \[10..13] ), bless(\[10..13], "Local::Test4") );
};

{
	package Local::Test5;
	sub xxx { 1 }
}

subtest "SHOULD_RETURN_OUTBLESS with arrayref in hashref" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_all( "Local::test_5" => {
		arr_source              => Sub::HandlesVia::XS::ARRAY_SRC_DEREF_HASH,
		arr_source_string       => "foo",
		method_return_pattern   => Sub::HandlesVia::XS::SHOULD_RETURN_OUTBLESS,
		method_return_class     => "Local::Test5",
	} );

	is( [ Local::test_5( { foo => [10..13] } ) ], [10..13] );
	is( scalar Local::test_5( { foo => [10..13] } ), bless({ foo => [10..13] }, "Local::Test5") );
};

{
	package Local::Test6;
	sub xxx { 1 }
}

subtest "SHOULD_RETURN_OUTBLESS with arrayref in arrayref" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_all( "Local::test_6" => {
		arr_source              => Sub::HandlesVia::XS::ARRAY_SRC_DEREF_ARRAY,
		arr_source_index        => 0,
		method_return_pattern   => Sub::HandlesVia::XS::SHOULD_RETURN_OUTBLESS,
		method_return_class     => "Local::Test6",
	} );

	is( [ Local::test_6( [ [10..13] ] ) ], [10..13] );
	is( scalar Local::test_6( [ [10..13] ] ), bless( [ [10..13] ], "Local::Test6") );
};

subtest "SHOULD_RETURN_TRUE" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_all( "Local::test_7" => {
		arr_source             => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
		method_return_pattern  => Sub::HandlesVia::XS::SHOULD_RETURN_TRUE,
	} );

	is( [ Local::test_7( [10..13] ) ], [!!1] );
	is( scalar Local::test_7( [10..13] ), !!1 );
};

subtest "SHOULD_RETURN_FALSE" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_all( "Local::test_8" => {
		arr_source             => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
		method_return_pattern  => Sub::HandlesVia::XS::SHOULD_RETURN_FALSE,
	} );

	is( [ Local::test_8( [10..13] ) ], [!!0] );
	is( scalar Local::test_8( [10..13] ), !!0 );
};

subtest "SHOULD_RETURN_UNDEF" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_all( "Local::test_9" => {
		arr_source             => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
		method_return_pattern  => Sub::HandlesVia::XS::SHOULD_RETURN_UNDEF,
	} );

	is( [ Local::test_9( [10..13] ) ], [undef] );
	is( scalar Local::test_9( [10..13] ), undef );
};

subtest "SHOULD_RETURN_NOTHING" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_all( "Local::test_10" => {
		arr_source             => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
		method_return_pattern  => Sub::HandlesVia::XS::SHOULD_RETURN_NOTHING,
	} );

	is( [ Local::test_10( [10..13] ) ], [] );
	is( scalar Local::test_10( [10..13] ), undef );
};

subtest "SHOULD_RETURN_INVOCANT" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_all( "Local::test_11" => {
		arr_source             => Sub::HandlesVia::XS::ARRAY_SRC_DEREF_SCALAR,
		method_return_pattern  => Sub::HandlesVia::XS::SHOULD_RETURN_INVOCANT,
	} );

	is( [ Local::test_11( \[10..13] ) ], [\[10..13]] );
	is( scalar Local::test_11( \[10..13] ), \[10..13] );
};

done_testing;
