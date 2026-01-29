=pod

=head1 NAME

unit/array/for_each.t - tests the C<for_each> method

=cut

use Test2::V0;
use Sub::HandlesVia::XS;

subtest "Basic" => sub {
	Sub::HandlesVia::XS::INSTALL_shvxs_array_for_each( "Local::test_1" => {
		arr_source  => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
	} );

	my $sum_elems   = 0;
	my $sum_indices = 0;
	my $sum_topics  = 0;
	
	my $arr = [ 10..13 ];
	Local::test_1( $arr, sub {
		$sum_elems    += $_[0];
		$sum_indices  += $_[1];
		$sum_topics   += $_;
	} );
	
	is( $sum_elems,  46 );
	is( $sum_indices, 6 );
	is( $sum_topics, 46 );
};

done_testing;
