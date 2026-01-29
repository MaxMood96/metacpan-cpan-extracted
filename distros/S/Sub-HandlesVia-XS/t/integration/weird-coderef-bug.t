=pod

=head1 NAME

integration/weird-coderef-bug.t - some sort of refcnt bug

=cut

use Test2::V0;
use Sub::HandlesVia::XS;
use Types::Common qw( CodeRef );

Sub::HandlesVia::XS::INSTALL_shvxs_array_push( "main::add_task" => {
	arr_source         => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
	element_type       => Sub::HandlesVia::XS::TYPE_BASE_CODEREF,
	element_type_cv    => CodeRef->compiled_check,
	element_type_tiny  => CodeRef,
} );

Sub::HandlesVia::XS::INSTALL_shvxs_array_for_each( "main::run_tasks" => {
	arr_source         => Sub::HandlesVia::XS::ARRAY_SRC_INVOCANT,
	callback           => sub { $_->() },
} );

my $task_list = [];
my $str = '';

add_task( $task_list, sub { $str .= 'a' } );
add_task( $task_list, sub { $str .= 'b' } );
add_task( $task_list, sub { $str .= 'c' } );

is( $str, '' );

run_tasks ( $task_list );

is( $str, 'abc' );

done_testing;
