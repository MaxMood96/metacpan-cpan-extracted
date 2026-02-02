=pod

=head1 NAME

unit/array/for_each2.t - tests the C<for_each2> method

=cut

use Test2::V0;
use Sub::HandlesVia::XS;

subtest "Basic" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_for_each2( "Local::test_1" => {
		arr_source  => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
	} );

	my $sum_topics  = 0;
	
	my $arr = [ 10..13 ];
	use Data::Dumper;
	Local::test_1( $arr, sub {
		die if @_;
		$sum_topics   += $_;
	} );
	
	is( $sum_topics, 46 );
};

done_testing;
