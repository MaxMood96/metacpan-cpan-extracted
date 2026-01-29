=pod

=head1 NAME

unit/array/sort.t - tests the C<sort> method

=cut

use Test2::V0;
use Sub::HandlesVia::XS;

subtest "Basic" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_sort( "Local::test_1" => {
		arr_source  => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
	} );

	my $arr = [ qw( foo bar baz quux ) ];
	is( [ Local::test_1( $arr ) ], [qw( bar baz foo quux )] );
	is( [ Local::test_1( $arr, sub { $_[1] cmp $_[0] } ) ], [qw( quux foo baz bar )] );
	is( [ Local::test_1( $arr, sub { reverse($_[0]) cmp reverse($_[1]) } ) ], [qw( foo bar quux baz )] );
};

subtest "Curried callback" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_sort( "Local::test_2" => {
		arr_source  => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
		callback    => sub { reverse($_[0]) cmp reverse($_[1]) },
	} );

	my $arr = [ qw( foo bar baz quux ) ];
	is( [ Local::test_2( $arr ) ], [qw( foo bar quux baz )] );
};

done_testing;
