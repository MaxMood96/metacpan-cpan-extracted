=pod

=head1 NAME

unit/string/prepend.t - tests the C<prepend> method

=cut

use Test2::V0;
use Scalar::Util 'blessed';
use Sub::HandlesVia::XS;

subtest "Basic" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_string_prepend( "Local::test_1" => {
		str_source  => Sub::HandlesVia::XS::STR_SRC_INVOCANT,
	} );

	my $x = "foo";
	is( Local::test_1($x, "bar"), "barfoo" );
	is( $x, "barfoo" );
	
	my $y = "baz";
	is( Local::test_1($x, $y), "bazbarfoo" );
	is( $x, "bazbarfoo" );
	is( $y, "baz" );
};

subtest "Scalarref invocant" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_string_prepend( "Local::test_2" => {
		str_source  => Sub::HandlesVia::XS::STR_SRC_DEREF_SCALAR,
	} );

	my $x = "foo";
	my $x_ref = \$x;
	is( Local::test_2($x_ref, "bar"), "barfoo" );
	is( $x, "barfoo" );
	
	my $y = "baz";
	is( Local::test_2($x_ref, $y), "bazbarfoo" );
	is( $x, "bazbarfoo" );
	ok !blessed $x_ref;
};

subtest "Blessed scalarref invocant" => sub {
	my $x = "foo";
	my $x_ref = bless( \$x, "Local::Test2" );
	is( Local::test_2($x_ref, "bar"), "barfoo" );
	is( $x, "barfoo" );
	isa_ok( $x_ref, 'Local::Test2' );
	
	my $y = "baz";
	is( Local::test_2($x_ref, $y), "bazbarfoo" );
	is( $x, "bazbarfoo" );
	isa_ok( $x_ref, 'Local::Test2' );
};

subtest "Arrayref invocant" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_string_prepend( "Local::test_3" => {
		str_source         => Sub::HandlesVia::XS::STR_SRC_DEREF_ARRAY,
		str_source_index   => 2,
	} );

	my $x = [undef, undef, "foo"];
	is( Local::test_3($x, "bar"), "barfoo" );
	is( $x, [undef, undef, "barfoo"] );
	
	my $y = "baz";
	is( Local::test_3($x, $y), "bazbarfoo" );
	is( $x, [undef, undef, "bazbarfoo"] );
	ok !blessed $x;
};

subtest "Blessed arrayref invocant" => sub {
	my $x = bless( [undef, undef, "foo"], 'Local::Test3' );
	is( Local::test_3($x, "bar"), "barfoo" );
	is( $x, bless( [undef, undef, "barfoo"], 'Local::Test3' ) );
	isa_ok( $x, 'Local::Test3' );
	
	my $y = "baz";
	is( Local::test_3($x, $y), "bazbarfoo" );
	is( $x, [undef, undef, "bazbarfoo"] );
	isa_ok( $x, 'Local::Test3' );
};

subtest "Hashref invocant" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_string_prepend( "Local::test_4" => {
		str_source         => Sub::HandlesVia::XS::STR_SRC_DEREF_HASH,
		str_source_string  => "xyz",
	} );

	my $x = { xyz => "foo" };
	is( Local::test_4($x, "bar"), "barfoo" );
	is( $x, { xyz => "barfoo" } );
	
	my $y = "baz";
	is( Local::test_4($x, $y), "bazbarfoo" );
	is( $x, { xyz => "bazbarfoo" } );
	ok !blessed $x;
};

subtest "Hashref invocant, initially missing key" => sub {
	my $x = {};
	my $w = warning {
		is( Local::test_4($x, "bar"), "bar" );
	};
	is( $x, { xyz => "bar" } );
	
	like $w, qr/uninitialized value/;
	
	my $y = "baz";
	is( Local::test_4($x, $y), "bazbar" );
	is( $x, { xyz => "bazbar" } );
	ok !blessed $x;
};

subtest "Blessed hashref invocant" => sub {
	my $x = bless( { xyz => "foo" }, 'Local::Test4' );
	is( Local::test_4($x, "bar"), "barfoo" );
	is( $x, bless( { xyz => "barfoo" }, 'Local::Test4' ) );
	
	my $y = "baz";
	is( Local::test_4($x, $y), "bazbarfoo" );
	is( $x, bless( { xyz => "bazbarfoo" }, 'Local::Test4' ) );
	isa_ok( $x, 'Local::Test4' );
};

my ( $GETS, $SETS );

{
	package Local::Test5;
	# Avoid storing $self->xyz as $self->{xyz}
	sub new {
		my ( $class, %arg ) = @_;
		return bless [ whatever => $arg{xyz} ], $class;
	}
	sub xyz {
		( @_ == 1 ) ? ( $GETS++  ) : ( $SETS++ );
		( @_ == 1 ) ? ( $_[0][1] ) : ( $_[0][1] = $_[1] );
	}
}

subtest "Object invocant" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_string_prepend( "Local::test_5" => {
		str_source         => Sub::HandlesVia::XS::STR_SRC_CALL_METHOD,
		str_source_string  => "xyz",
	} );

	my $x = Local::Test5->new( xyz => "foo" );
	is( Local::test_5($x, "bar"), "barfoo" );
	is( $x->xyz, "barfoo" );
	
	my $y = "baz";
	is( Local::test_5($x, $y), "bazbarfoo" );
	is( $x->xyz, "bazbarfoo" );
	isa_ok( $x, 'Local::Test5' );
	
	is( $GETS, 4 );
	is( $SETS, 2 );
};

sub Local::Test6::_builder {
	shift->{xyz} = 'foo';
}

subtest "Blessed hashref invocant with fallback builder" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_string_prepend( "Local::test_6" => {
		str_source           => Sub::HandlesVia::XS::STR_SRC_DEREF_HASH,
		str_source_string    => "xyz",
		str_source_fallback  => "_builder",
	} );
	
	my $x = bless( {}, 'Local::Test6' );
	is( Local::test_6($x, "bar"), "barfoo" );
	is( $x, bless( { xyz => "barfoo" }, 'Local::Test6' ) );
	
	my $y = "baz";
	is( Local::test_6($x, $y), "bazbarfoo" );
	is( $x, bless( { xyz => "bazbarfoo" }, 'Local::Test6' ) );
	isa_ok( $x, 'Local::Test6' );
};

subtest "With curried SVs and interesting return patterns" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_string_prepend( "Local::test_7" => {
		str_source             => Sub::HandlesVia::XS::STR_SRC_INVOCANT,
		curried_sv             => "x",
		method_return_pattern  => Sub::HandlesVia::XS::SHOULD_RETURN_UNDEF,
	} );
	Sub::HandlesVia::XS::INSTALL_shvxs_string_prepend( "Local::test_8" => {
		str_source             => Sub::HandlesVia::XS::STR_SRC_INVOCANT,
		curried_sv             => "y",
		method_return_pattern  => Sub::HandlesVia::XS::SHOULD_RETURN_FALSE,
	} );
	Sub::HandlesVia::XS::INSTALL_shvxs_string_prepend( "Local::test_9" => {
		str_source             => Sub::HandlesVia::XS::STR_SRC_INVOCANT,
		curried_sv             => "z",
		method_return_pattern  => Sub::HandlesVia::XS::SHOULD_RETURN_TRUE,
	} );

	my $x = "";
	is( Local::test_8( $x ), !!0 );
	is( Local::test_9( $x ), !!1 );
	is( Local::test_9( $x ), !!1 );
	is( Local::test_8( $x ), !!0 );
	is( Local::test_7( $x ), undef );
	is( $x, "xyzzy" );
};

done_testing;
