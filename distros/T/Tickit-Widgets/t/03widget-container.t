#!/usr/bin/perl

use v5.14;
use warnings;

use Test2::V0 0.000148;

my $lines = 1;
my $cols  = 5;
my $widget = TestWidget->new;
my $container = TestContainer->new;

my $changed = 0;
my $resized = 0;

ok( defined $container, 'defined $container' );

is_oneref( $widget, '$widget has refcount 1 initially' );
is_oneref( $container, '$container has refcount 1 initially' );

is( scalar $container->children, 0, 'scalar $container->children is 0' );
is( [ $container->children ], [], '$container->children empty' );

$container->add( $widget, foo => "bar" );

is_refcount( $widget, 2, '$widget has refcount 2 after add' );
is_oneref( $container, '$container has refcount 1 after add' );

ref_is( $widget->parent, $container, '$widget->parent is container' );

is( { $container->child_opts( $widget ) }, { foo => "bar" }, 'child_opts in list context' );

is( scalar $container->child_opts( $widget ), { foo => "bar" }, 'child_opts in scalar context' );

is( $changed, 1, '$changed is 1' );

$container->set_child_opts( $widget, foo => "splot" );

is( { $container->child_opts( $widget ) }, { foo => "splot" }, 'child_opts after change' );

is( $changed, 2, '$changed is 2' );

is( scalar $container->children, 1, 'scalar $container->children is 1' );
is( [ $container->children ], [ exact_ref($widget) ], '$container->children contains widget' );

{
   $cols = 10;
   $widget->resized;

   is( $resized, 1, '$resized is 1 after child ->resized' );

   $widget->resized;

   is( $resized, 1, '$resized still 1 after no-op child ->resized' );

   $widget->set_requested_size( 2, 15 );

   is( $resized, 2, '$resized is 2 after child ->set_requested_size' );
}

$container->remove( $widget );

is( scalar $container->children, 0, 'scalar $container->children is 0' );
is( [ $container->children ], [], '$container->children empty' );

is( $widget->parent, undef, '$widget->parent is undef' );

is( $changed, 3, '$changed is 3' );

# child search
{
   my @widgets = map { TestWidget->new } 1 .. 4;

   $container->add( $_ ) for @widgets;

   ref_is( $container->find_child( first  => undef       ), $widgets[0], '->find_child first' );

   ref_is( $container->find_child( before => $widgets[2] ), $widgets[1], '->find_child before' );
   is    ( $container->find_child( before => $widgets[0] ), undef,       '->find_child before first' );

   ref_is( $container->find_child( after  => $widgets[1] ), $widgets[2], '->find_child after' );
   is    ( $container->find_child( after  => $widgets[3] ), undef,       '->find_child after last' );

   ref_is( $container->find_child( last   => undef       ), $widgets[3], '->find_child last' );

   ref_is( $container->find_child( after => $widgets[1], where => sub { $_ != $widgets[2] } ),
           $widgets[3],
           '->find_child where filter' );
}

done_testing;

use Object::Pad 0.807;

class TestWidget {
   inherit Tickit::Widget;
   use constant WIDGET_PEN_FROM_STYLE => 1;

   method render_to_rb {}

   method lines { $lines }
   method cols  { $cols  }
}

class TestContainer {
   inherit Tickit::ContainerWidget;
   use constant WIDGET_PEN_FROM_STYLE => 1;

   field @_children;
   method children { @_children }

   method render_to_rb {}

   method lines { 2 }
   method cols  { 10 }

   method add
   {
      my ( $child ) = @_;
      push @_children, $child;
      $self->SUPER::add( @_ );
   }

   method remove
   {
      my ( $child ) = @_;
      @_children = grep { $_ != $child } @_children;
      $self->SUPER::remove( @_ );
   }

   method child_resized { $resized++ }

   method children_changed { $changed++ }
}
