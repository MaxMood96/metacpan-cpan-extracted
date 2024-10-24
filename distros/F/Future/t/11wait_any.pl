use v5.10;
use strict;
use warnings;

use Test2::V0 0.000148; # is_refcount

use Future;

use constant FUTURE_HAS_CONVERGENT_ALSO => ( !defined $Future::XS::VERSION or $Future::XS::VERSION >= 0.13 );

# First done
{
   my $f1 = Future->new;
   my $f2 = Future->new;

   my $future = Future->wait_any( $f1, $f2 );
   is_oneref( $future, '$future has refcount 1 initially' );

   # Two refs; one lexical here, one in $future
   is_refcount( $f1, 2, '$f1 has refcount 2 after adding to ->wait_any' );
   is_refcount( $f2, 2, '$f2 has refcount 2 after adding to ->wait_any' );

   is( [ $future->pending_futures ],
       [ $f1, $f2 ],
       '$future->pending_futures before any ready' );

   is( [ $future->ready_futures ],
       [],
       '$future->done_futures before any ready' );

   my @on_ready_args;
   $future->on_ready( sub { @on_ready_args = @_ } );

   ok( !$future->is_ready, '$future not yet ready' );
   is( scalar @on_ready_args, 0, 'on_ready not yet invoked' );

   $f1->done( one => 1 );

   is( [ $future->pending_futures ],
       [],
       '$future->pending_futures after $f1 ready' );

   is( [ $future->ready_futures ],
       [ $f1, $f2 ],
       '$future->ready_futures after $f1 ready' );

   is( [ $future->done_futures ],
       [ $f1 ],
       '$future->done_futures after $f1 ready' );

   is( [ $future->cancelled_futures ],
       [ $f2 ],
       '$future->cancelled_futures after $f1 ready' );

   is( scalar @on_ready_args, 1, 'on_ready passed 1 argument' );
   ref_is( $on_ready_args[0], $future, 'Future passed to on_ready' );
   undef @on_ready_args;

   ok( $future->is_ready, '$future now ready after f1 ready' );
   is( [ $future->result ], [ one => 1 ], 'results from $future->result' );

   is_refcount( $future, 1, '$future has refcount 1 at end of test' );
   undef $future;

   is_refcount( $f1,   1, '$f1 has refcount 1 at end of test' );
   is_refcount( $f2,   1, '$f2 has refcount 1 at end of test' );
}

# First fails
{
   my $f1 = Future->new;
   my $f2 = Future->new;

   my $future = Future->wait_any( $f1, $f2 );

   $f1->fail( "It fails\n" );

   ok( $future->is_ready, '$future now ready after a failure' );

   is( $future->failure, "It fails\n", '$future->failure yields exception' );

   is( dies { $future->result }, "It fails\n", '$future->result throws exception' );

   ok( $f2->is_cancelled, '$f2 cancelled after a failure' );
}

# immediately done
{
   my $f1 = Future->done;

   my $future = Future->wait_any( $f1 );

   ok( $future->is_ready, '$future of already-ready sub already ready' );
}

# cancel propagation
{
   my $f1 = Future->new;
   my $c1;
   $f1->on_cancel( sub { $c1++ } );

   my $future = Future->wait_all( $f1 );

   $future->cancel;

   is( $c1, 1, '$future->cancel marks subs cancelled' );
}

# cancelled convergent
{
   my $f1 = Future->new;
   my $f2 = Future->new;

   my $future = Future->wait_any( $f1, $f2 );

   $f1->cancel;

   ok( !$future->is_ready, '$future not yet ready after first cancellation' );

   $f2->done( "result" );

   ok( $future->is_ready, '$future is ready' );

   is( [ $future->done_futures ],
       [ $f2 ],
       '->done_futures with cancellation' );
   is( [ $future->cancelled_futures ],
       [ $f1 ],
       '->cancelled_futures with cancellation' );

   my $f3 = Future->new;
   $future = Future->wait_any( $f3 );

   $f3->cancel;

   ok( $future->is_ready, '$future is ready after final cancellation' );

   like( scalar $future->failure, qr/ cancelled/, 'Failure mentions cancelled' );
}

# 'also' subs don't get cancelled
if( FUTURE_HAS_CONVERGENT_ALSO ) {
   my $falso = Future->new;
   my $calso;
   $falso->on_cancel( sub { $calso++ } );

   my $future = Future->wait_any( also => $falso );

   $future->cancel;

   is( $calso, undef, '$future->cancel does not cancel $falso' );

   my $f1 = Future->new;

   $future = Future->wait_any( $f1, also => $falso );

   $f1->done;
   is( $calso, undef, '$f1->done does not cancel $falso' );

   $f1 = Future->new;

   $future = Future->wait_any( $f1, also => $falso );

   $f1->fail( "Oops\n" );
   is( $calso, undef, '$f1->fail does not cancel $falso' );
}

# wait_any on none
{
   my $f = Future->wait_any( () );

   ok( $f->is_ready, 'wait_any on no futures already done' );
   is( scalar $f->failure, "Cannot ->wait_any with no subfutures",
       '->result on empty wait_any is empty' );
}

# wait_any instance disappearing partway through cancellation (RT120468)
{
   my $f = Future->new;

   my $wait;
   $wait = Future->wait_any(
      $f,
      my $cancelled = Future->new->on_cancel( sub {
         undef $wait;
      }),
   );

   ok( lives { $f->done(1) },
      'no problems cancelling a Future which clears the original ->wait_any ref' );

   ok( $cancelled->is_cancelled, 'cancellation occurred as expected' );
   ok( $f->is_done, '->wait_any is marked as done' );
}

# With a cancelled subfuture (RT144459)
foreach ([ precancelled => 0 ], [ postcancelled => 1 ])
{
   my ( $title, $cancel_after ) = @$_;

   my $f1 = Future->new;
   my $f2 = Future->new;

   $f2->cancel if !$cancel_after;

   my $f = Future->wait_any( $f1, $f2 );

   $f2->cancel if $cancel_after;

   ok( !$f->is_ready, "wait_any is pending before f1 done for $title" );

   $f1->done;

   ok( $f->is_done, "wait_any now done after f1 done for $title" );
}

done_testing;
