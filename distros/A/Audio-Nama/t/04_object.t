use Test2::Bundle::More;
use strict;

$ENV{NAMA_VERBOSE_TEST_OUTPUT} and diag ("TESTING $0\n");
$ENV{NAMA_VERBOSE_TEST_OUTPUT} and diag "testing trivial class Apple";
package Apple;
our @ISA; 
use Audio::Nama::Object qw(color);

package main;

my $apple = Apple->new(color => 'green');

is( ref $apple, 'Apple', "instantiation") ;

is( $apple->color, 'green', "accessor" ); 

$apple->set( color => 'red' );

is( $apple->color, 'red', "mutator" ); 

#$apple->color = 'blue'; 

#is( $apple->color, 'blue', "lvalue" ); 

done_testing()

__END__