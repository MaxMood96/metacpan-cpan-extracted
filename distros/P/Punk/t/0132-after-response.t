#!perl
use 5.010;
use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/lib";
use Test::More;
use Punk::Test;

# The after_response phase: work that runs once the response has been handed
# to the server, off the request's own path.
#
# `after_dispatch` sees the finalized triplet and may replace it, so it has to
# run BEFORE the response is written; this is the phase after that. Where
# "after" actually is depends on what is underneath - a psgix.cleanup server
# runs it, a Hyperman worker takes a zero-delay loop timer, and anything else
# runs it inline. This file covers the ordering, both registration forms and
# the two paths that can be driven in one process; the loop timer is proved in
# t/1013-after-response-live.t against a real worker.

our (@ORDER, $ENVREF);

{
    package ARApp;
    use Punk;

    hook before_dispatch => sub { push @main::ORDER, 'before_dispatch'; return };
    hook after_dispatch  => sub {
        my ($c, $resp) = @_;
        push @main::ORDER, 'after_dispatch';
        return;
    };
    hook after_response  => sub {
        my ($c, $resp) = @_;
        push @main::ORDER, "after_response(" . $resp->[0] . ")";
        return;
    };

    get '/' => sub {
        my ($c) = @_;
        push @main::ORDER, 'handler';
        $c->text('body');
    };

    get '/queued' => sub {
        my ($c) = @_;
        $c->after_response(sub { push @main::ORDER, 'queued-one' });
        $c->after_response(sub { push @main::ORDER, 'queued-two' });
        push @main::ORDER, 'handler';
        $c->text('ok');
    };

    # what the callback is given: the context it ran for, and the response
    get '/args' => sub {
        my ($c) = @_;
        $c->stash->{who} = 'auth';
        $c->after_response(sub {
            my ($cc, $resp) = @_;
            push @main::ORDER, join '|', $cc->stash->{who}, $resp->[0],
                                         $cc->req->path;
        });
        $c->text('args', 201);
    };

    # a die is logged and the rest still run: there is no response left to
    # turn into a 500
    get '/dies' => sub {
        my ($c) = @_;
        $c->after_response(sub { die "boom\n" });
        $c->after_response(sub { push @main::ORDER, 'after-the-die' });
        $c->text('still fine');
    };

    # the async delivery path reaches the same place
    get '/future' => sub {
        my ($c) = @_;
        $c->after_response(sub { push @main::ORDER, 'from-a-future' });
        return Punk::Future->done_future($c->text('futured'));
    };

    # for the psgix.cleanup case, which needs the env back
    get '/cleanup' => sub {
        my ($c) = @_;
        $main::ENVREF = $c->env;
        $c->after_response(sub { push @main::ORDER, 'cleaned' });
        $c->text('ok');
    };

    get '/none' => sub { $_[0]->text('nothing registered here') };
}

my $t = Punk::Test->new('ARApp');

# ---- the order of the phases -------------------------------------------------
{
    @ORDER = ();
    $t->get_ok('/')->status_is(200)->content_is('body');
    is_deeply(\@ORDER,
        [ 'before_dispatch', 'handler', 'after_dispatch', 'after_response(200)' ],
        'after_response runs last, and sees the response after_dispatch left');
}

# ---- the per-request queue ---------------------------------------------------
{
    @ORDER = ();
    $t->get_ok('/queued')->status_is(200);
    is_deeply(\@ORDER,
        [ 'before_dispatch', 'handler', 'after_dispatch',
          'after_response(200)', 'queued-one', 'queued-two' ],
        'the hook runs before what the request queued, and the queue in order');
}

# ---- what a callback is handed -----------------------------------------------
{
    @ORDER = ();
    $t->get_ok('/args')->status_is(201);
    is($ORDER[-1], 'auth|201|/args',
       'a callback gets the context it ran for and the response that was sent');
}

# ---- the queue is per request ------------------------------------------------
{
    @ORDER = ();
    $t->get_ok('/none')->status_is(200);
    is_deeply(\@ORDER,
        [ 'before_dispatch', 'after_dispatch', 'after_response(200)' ],
        'a later request does not inherit the last one\'s queue');
}

# ---- a callback that dies ----------------------------------------------------
{
    @ORDER = ();
    my @warn;
    local $SIG{__WARN__} = sub { push @warn, $_[0] };
    $t->get_ok('/dies')->status_is(200)
      ->content_is('still fine',
        'a callback that dies does not touch the response - it has gone');
    ok(scalar(grep { $_ eq 'after-the-die' } @ORDER),
       'and the callbacks after it still run');
}

# ---- the async delivery path -------------------------------------------------
{
    @ORDER = ();
    $t->get_ok('/future')->status_is(200)->content_is('futured');
    ok(scalar(grep { $_ eq 'from-a-future' } @ORDER),
       'a response delivered from a settled future runs the phase too');
}

# ---- psgix.cleanup: the server takes the work --------------------------------
{
    @ORDER = ();
    $ENVREF = undef;
    $t->get_ok('/cleanup', env => { 'psgix.cleanup' => 1 })->status_is(200);

    ok($ENVREF, 'the handler captured its env');
    my $h = $ENVREF->{'psgix.cleanup.handlers'};
    is(ref $h, 'ARRAY', 'a psgix.cleanup server is given handlers');
    is(scalar @$h, 1, 'one of them, for this response');
    ok(!scalar(grep { $_ eq 'cleaned' } @ORDER),
       'and nothing has run yet - the server has not called them');

    $_->($ENVREF) for @$h;
    ok(scalar(grep { $_ eq 'cleaned' } @ORDER),
       'the callbacks run when the server runs its cleanup phase');
}

# ---- what the keyword refuses ------------------------------------------------
{
    my $ok = eval q{
        package ARBad;
        use Punk;
        hook after_resposne => sub { 1 };
        1;
    };
    ok(!$ok, 'a misspelled hook name croaks');
    like($@, qr/after_response/, 'and the message lists the real one');

    $ok = eval q{
        package ARBad2;
        use Punk;
        get '/x' => sub { $_[0]->after_response('not code') };
        1;
    };
    my $t2 = Punk::Test->new('ARBad2');
    eval { $t2->get_ok('/x') };
    like($@ . $t2->body, qr/code reference/,
         'after_response takes a coderef and says so');
}

done_testing;
