use v5.10;
use strict;
use warnings;

use Test2::V0 0.000148; # is_refcount

use Future;

use constant FUTURE_HAS_CONVERGENT_ALSO => ( !defined $Future::XS::VERSION or $Future::XS::VERSION >= 0.13 );

# One done
{
   my $f1 = Future->new;
   my $f2 = Future->new;
   my $c2;
   $f2->on_cancel( sub { $c2++ } );

   my $future = Future->needs_any( $f1, $f2 );
   is_oneref( $future, '$future has refcount 1 initially' );

   # Two refs; one lexical here, one in $future
   is_refcount( $f1, 2, '$f1 has refcount 2 after adding to ->needs_any' );
   is_refcount( $f2, 2, '$f2 has refcount 2 after adding to ->needs_any' );

   my $ready;
   $future->on_ready( sub { $ready++ } );

   ok( !$future->is_ready, '$future not yet ready' );

   $f1->done( one => 1 );

   is( $ready, 1, '$future is now ready' );

   ok( $future->is_ready, '$future now ready after f1 ready' );
   is( [ $future->result ], [ one => 1 ], 'results from $future->result' );

   is( [ $future->pending_futures ],
       [],
       '$future->pending_futures after $f1 done' );

   is( [ $future->ready_futures ],
       [ $f1, $f2 ],
       '$future->ready_futures after $f1 done' );

   is( [ $future->done_futures ],
       [ $f1 ],
       '$future->done_futures after $f1 done' );

   is( [ $future->failed_futures ],
       [],
       '$future->failed_futures after $f1 done' );

   is( [ $future->cancelled_futures ],
       [ $f2 ],
       '$future->cancelled_futures after $f1 done' );

   is_refcount( $future, 1, '$future has refcount 1 at end of test' );
   undef $future;

   is_refcount( $f1, 1, '$f1 has refcount 1 at end of test' );
   is_refcount( $f2, 1, '$f2 has refcount 1 at end of test' );

   is( $c2, 1, 'Unfinished child future cancelled on failure' );
}

# One fails
{
   my $f1 = Future->new;
   my $f2 = Future->new;

   my $future = Future->needs_any( $f1, $f2 );

   my $ready;
   $future->on_ready( sub { $ready++ } );

   ok( !$future->is_ready, '$future not yet ready' );

   $f1->fail( "Partly fails" );

   ok( !$future->is_ready, '$future not yet ready after $f1 fails' );

   $f2->done( two => 2 );

   ok( $future->is_ready, '$future now ready after $f2 done' );
   is( [ $future->result ], [ two => 2 ], '$future->result after $f2 done' );

   is( [ $future->done_futures ],
       [ $f2 ],
       '$future->done_futures after $f2 done' );

   is( [ $future->failed_futures ],
       [ $f1 ],
       '$future->failed_futures after $f2 done' );
}

# All fail
{
   my $f1 = Future->new;
   my $f2 = Future->new;

   my $future = Future->needs_any( $f1, $f2 );

   my $ready;
   $future->on_ready( sub { $ready++ } );

   ok( !$future->is_ready, '$future not yet ready' );

   $f1->fail( "Partly fails" );

   $f2->fail( "It fails" );

   is( $ready, 1, '$future is now ready' );

   ok( $future->is_ready, '$future now ready after f2 fails' );
   is( $future->failure, "It fails", '$future->failure yields exception' );
   my $file = __FILE__;
   my $line = __LINE__ + 1;
   like( dies { $future->result }, qr/^It fails at \Q$file line $line\E\.?\n$/, '$future->result throws exception' );

   is( [ $future->failed_futures ],
       [ $f1, $f2 ],
       '$future->failed_futures after all fail' );
}

# immediately done
{
   my $future = Future->needs_any( Future->fail("F1"), Future->done );

   ok( $future->is_ready, '$future of already-done sub already ready' );
}

# immediately fails
{
   my $future = Future->needs_any( Future->fail("F1") );

   ok( $future->is_ready, '$future of already-failed sub already ready' );
   $future->failure;
}

# cancel propagation
{
   my $f1 = Future->new;
   my $c1;
   $f1->on_cancel( sub { $c1++ } );

   my $f2 = Future->new;
   my $c2;
   $f2->on_cancel( sub { $c2++ } );

   my $future = Future->needs_all( $f1, $f2 );

   $f2->fail( "booo" );

   $future->cancel;

   is( $c1, 1,     '$future->cancel marks subs cancelled' );
   is( $c2, undef, '$future->cancel ignores ready subs' );
}

# cancelled convergent
{
   my $f1 = Future->new;
   my $f2 = Future->new;

   my $future = Future->needs_any( $f1, $f2 );

   $f1->cancel;

   ok( !$future->is_ready, '$future not yet ready after first cancellation' );

   $f2->done( "result" );

   is( [ $future->done_futures ],
       [ $f2 ],
       '->done_futures with cancellation' );
   is( [ $future->cancelled_futures ],
       [ $f1 ],
       '->cancelled_futures with cancellation' );

   my $f3 = Future->new;
   $future = Future->needs_any( $f3 );

   $f3->cancel;

   ok( $future->is_ready, '$future is ready after final cancellation' );

   like( scalar $future->failure, qr/ cancelled/, 'Failure mentions cancelled' );
}

# 'also' subs don't get cancelled
if( FUTURE_HAS_CONVERGENT_ALSO ) {
   my $falso = Future->new;
   my $calso;
   $falso->on_cancel( sub { $calso++ } );

   my $future = Future->needs_any( also => $falso );

   $future->cancel;

   is( $calso, undef, '$future->cancel does not cancel $falso' );

   my $f1 = Future->new;

   $future = Future->needs_any( $f1, also => $falso );

   $f1->done;
   is( $calso, undef, '$f1->done does not cancel $falso' );
}

# needs_any on none
{
   my $f = Future->needs_any( () );

   ok( $f->is_ready, 'needs_any on no futures already done' );
   is( scalar $f->failure, "Cannot ->needs_any with no subfutures",
       '->result on empty needs_any is empty' );
}

# weakself retention (RT120468)
{
   my $f = Future->new;

   my $wait;
   $wait = Future->needs_any(
      $f,
      my $cancelled = Future->new->on_cancel( sub {
         undef $wait;
      }),
   );

   ok( lives { $f->done(1) },
      'no problems cancelling a Future which clears the original ->needs_any ref' );

   ok( $cancelled->is_cancelled, 'cancellation occured as expected' );
   ok( $f->is_done, '->needs_any is marked as done' );
}

# With a cancelled subfuture (RT144459)
foreach ([ precancelled => 0 ], [ postcancelled => 1 ])
{
   my ( $title, $cancel_after ) = @$_;

   my $f1 = Future->new;
   my $f2 = Future->new;

   $f2->cancel if !$cancel_after;

   my $f = Future->needs_any( $f1, $f2 );

   $f2->cancel if $cancel_after;

   ok( !$f->is_ready, "needs_any is pending before f1 done for $title" );

   $f1->done;

   ok( $f->is_done, "needs_any now done after f1 done for $title" );
}

done_testing;
