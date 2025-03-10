#!/usr/bin/perl

use v5.14;
use warnings;

use Test2::V0;

use Net::Prometheus::Gauge;

sub HASHfromSample
{
   my ( $sample ) = @_;
   return { map { $_, $sample->$_ } qw( varname labels value ) };
}

# No labels
{
   my $gauge = Net::Prometheus::Gauge->new(
      name => "test_gauge",
      help => "A testing gauge",
   );

   ok( defined $gauge, 'defined $gauge' );

   my @samples = $gauge->samples;
   is( scalar @samples, 1, '$gauge->samples yields 1 sample' );

   is( HASHfromSample( $samples[0] ),
      { varname => "test_gauge", labels => [], value => 0, },
      '$samples[0] initially'
   );

   $gauge->inc;

   @samples = $gauge->samples;
   is( $samples[0]->value, 1, 'sample->value after $gauge->inc' );

   $gauge->inc( 10 );

   @samples = $gauge->samples;
   is( $samples[0]->value, 11, 'sample->value after $gauge->inc( 10 )' );

   $gauge->dec( 5 );

   @samples = $gauge->samples;
   is( $samples[0]->value, 6, 'sample->value after $gauge->dec( 5 )' );

   $gauge->set( undef );

   @samples = $gauge->samples;
   is( $samples[0]->value, undef, 'sample->value after $gauge->set( undef )' );
}

# Functions
{
   my $gauge = Net::Prometheus::Gauge->new(
      name => "func_gauge",
      help => "A gauge reporting a function",
   );

   my $value;
   $gauge->set_function( sub { $value } );

   $value = 10;
   is( ( $gauge->samples )[0]->value, 10, 'sample->value from function' );

   $value = 20;
   is( ( $gauge->samples )[0]->value, 20, 'sample->value updates' );
}

# One label
{
   my $gauge = Net::Prometheus::Gauge->new(
      name => "labeled_gauge",
      help => "A gauge with a label",
      labels => [qw( lab )],
   );

   is( [ $gauge->samples ], [],
      '$gauge->samples initially empty'
   );

   $gauge->set( one => 1 );
   $gauge->set( { lab => "two" }, 2 );

   # FRAGILE: depends on the current implementation sorting these
   my @samples = $gauge->samples;
   is( scalar @samples, 2, '$gauge->samples yields 2 samples' );

   is( [ map { HASHfromSample( $_ ) } @samples ],
      [
         { varname => "labeled_gauge", labels => [ lab => "one" ], value => 1 },
         { varname => "labeled_gauge", labels => [ lab => "two" ], value => 2 },
      ],
      '@samples'
   );

   $gauge->labels( "three" )->set( 3 );

   is( [ map { HASHfromSample( $_ ) } $gauge->samples ],
      [
         { varname => "labeled_gauge", labels => [ lab => "one"   ], value => 1 },
         { varname => "labeled_gauge", labels => [ lab => "three" ], value => 3 },
         { varname => "labeled_gauge", labels => [ lab => "two"   ], value => 2 },
      ],
      '@samples after adding "three"'
   );
}

# Functions + label
{
   my $gauge = Net::Prometheus::Gauge->new(
      name => "labeled_func_gauge",
      help => "A gauge reporting a function with a label",
      labels => [qw( lab )],
   );

   my $value;
   $gauge->set_function( one => sub { $value } );

   $value = 50;
   is( ( $gauge->samples )[0]->value, 50, 'sample->value from function with label' );
}

# Two labels
{
   my $gauge = Net::Prometheus::Gauge->new(
      name => "multidimensional_gauge",
      help => "A gauge with two labels",
      labels => [qw( x y )],
   );

   $gauge->set( 0 => 0 => 10 );
   $gauge->set( 0 => 1 => 20 );

   $gauge->set( { x => 1, y => 0 }, 30 );
   $gauge->set( { x => 1, y => 1 }, 40 );

   is( [ map { HASHfromSample( $_ ) } $gauge->samples ],
      [
         { varname => "multidimensional_gauge", labels => [ x => "0", y => "0" ],
            value => 10 },
         { varname => "multidimensional_gauge", labels => [ x => "0", y => "1" ],
            value => 20 },
         { varname => "multidimensional_gauge", labels => [ x => "1", y => "0" ],
            value => 30 },
         { varname => "multidimensional_gauge", labels => [ x => "1", y => "1" ],
            value => 40 },
      ],
      '@samples after adding "three"'
   );
}

# Remove and clear
{
   my $gauge = Net::Prometheus::Gauge->new(
      name   => "removal_test",
      help   => "A gauge for testing removal",
      labels => [qw( x )],
   );

   $gauge->set( { x => "one" }, 1 );
   $gauge->set( { x => "two" }, 2 );
   $gauge->set( { x => "three" }, 3 );

   is( [ map { $_->labels } $gauge->samples ],
      # Grr sorting
      [ [ x => "one" ], [ x => "three" ], [ x => "two" ] ],
      'labels before ->remove' );

   $gauge->remove( { x => "one" } );

   is( [ map { $_->labels } $gauge->samples ],
      [ [ x => "three" ], [ x => "two" ] ],
      'labels after ->remove' );

   $gauge->clear;

   is( [ map { $_->labels } $gauge->samples ],
      [],
      'labels after ->clear' );
}

done_testing;
