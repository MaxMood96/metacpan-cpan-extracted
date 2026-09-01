#!perl
use 5.010;
use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/lib";
use Test::More;
use PunkTest;
use File::Raw::JSON qw(file_json_decode);

# Punk::AsyncAwait puts the async and await keywords into an app, a controller
# and a model. The keywords are lexical, so each package imports them itself -
# which is also the thing users get wrong, so it is asserted here.

BEGIN {
    plan skip_all => 'Future::AsyncAwait required'
        unless eval { require Future::AsyncAwait; 1 };
    plan skip_all => 'perl 5.16 required for Future::AsyncAwait'
        if $] < 5.016;
}

# ---- a controller and a model, each importing for itself -----------------
{
    package T::AA::App::Model::Thing;
    use Punk::Model;
    use Punk::AsyncAwait;
    table 'things';
    field id => 'integer';
    sub rows {
        return Punk::Future->done_future([ { id => 1 }, { id => 2 } ]);
    }
    async sub decorated {
        my $rows = await rows();
        $_->{seen} = 1 for @$rows;
        return $rows;
    }
}
{
    package T::AA::App::Controller::Things;
    use Punk::Controller;
    use Punk::AsyncAwait;

    async sub list {
        my ($c) = @_;
        my $rows = await T::AA::App::Model::Thing::decorated();
        return $c->json({ rows => $rows });
    }

    # the blocking $c->await method still works inside an async sub, and is a
    # different thing from the keyword
    async sub both {
        my ($c) = @_;
        my $a = await Punk::Future->done_future('kw');
        my ($b) = $c->await(Punk::Future->done_future('method'));
        return $c->json({ keyword => $a, method => $b });
    }
}

# ---- the app ------------------------------------------------------------
{
    package T::AA::App;
    use Punk;
    use Punk::AsyncAwait;

    # The headline parse: route keywords are prototype-less list operators, so
    # `get PATH => async sub {...}` depends on `async` firing in term position.
    get '/inline' => async sub {
        my ($c) = @_;
        my $v = await Punk::Future->done_future('inline-value');
        return $c->json({ got => $v });
    };

    # an async sub that never suspends still returns a Punk::Future
    get '/nosuspend' => async sub {
        my ($c) = @_;
        return $c->json({ got => 'straight' });
    };

    get '/list' => 'Things#list';
    get '/both' => 'Things#both';
    package main;
}

my $app = T::AA::App->to_app;

# ---- the app, blocking server -------------------------------------------
{
    my $r = hit($app, path => '/inline');
    is($r->[0], 200, 'an async sub route answers');
    is(file_json_decode($r->[2][0])->{got}, 'inline-value',
       'and the awaited value reached the body');
}
{
    my $r = hit($app, path => '/nosuspend');
    is(file_json_decode($r->[2][0])->{got}, 'straight',
       'an async sub that never suspends answers too');
}

# ---- a controller reached by a route target string ----------------------
{
    my $r = hit($app, path => '/list');
    is($r->[0], 200, 'an async controller method answers');
    my $got = file_json_decode($r->[2][0]);
    is(scalar @{ $got->{rows} }, 2, 'the model rows came back');
    is($got->{rows}[0]{seen}, 1, 'through the model async sub');
}

# ---- the keyword and the method are different things --------------------
{
    my $r = hit($app, path => '/both');
    my $got = file_json_decode($r->[2][0]);
    is($got->{keyword}, 'kw',     'the await keyword works');
    is($got->{method},  'method', 'and $c->await still works beside it');
}

# ---- nonblocking: a future comes back -----------------------------------
{
    my $f = hit($app, path => '/inline', env => { 'psgi.nonblocking' => 1 });
    ok(ref $f && eval { $f->can('on_ready') },
       'nonblocking: a future comes back from an async sub route');
    my $r = $f->get;
    is($r->[0], 200, 'which resolves to a finalized triplet');
}

# ---- the future an async sub returns is a Punk::Future ------------------
{
    package T::AA::Direct;
    use Punk::AsyncAwait;
    sub make {
        my $inner = Punk::Future->new;
        my $outer = (async sub { my @v = await $inner; return "got:@v" })->();
        return ($inner, $outer);
    }
    package main;

    my ($inner, $outer) = T::AA::Direct::make();
    isa_ok($outer, 'Punk::Future', 'the future an async sub returns');
    ok(!$outer->is_ready, 'pending while suspended');
    $inner->done('a', 'b');
    ok($outer->is_ready, 'settled when the awaited future settles');
    is(scalar $outer->get, 'got:a b', 'with the awaited values');
}

# ---- cancelling the returned future cancels what it awaits --------------
{
    package T::AA::Cancel;
    use Punk::AsyncAwait;
    sub make {
        my $inner = Punk::Future->new;
        my $outer = (async sub { await $inner; return 1 })->();
        return ($inner, $outer);
    }
    package main;

    my ($inner, $outer) = T::AA::Cancel::make();
    $outer->cancel;
    ok($inner->is_cancelled, 'cancelling the caller cancels the awaited future');
}

# ---- on a real loop: suspend, resume, and pump ---------------------------
# The end-to-end proof that the future an async sub returns carries a usable
# loop. It is built by cloning the one that was awaited, and if the clone lost
# its loop the ->get below croaks "no event loop" instead of resuming.
SKIP: {
    skip 'Hyperman required for the loop test', 2
        unless eval { require Hyperman; require Hyperman::Loop; 1 };

    my $ok = eval <<'LOOP';
        use Future::AsyncAwait future_class => 'Punk::Future';
        my $loop = Hyperman::Loop->new;
        my $done = Hyperman::Future->new;
        my ($pending, $got);
        $loop->timer(0.01, sub {
            my $inner = Punk::Future->timer(0.05);   # loop-backed, pending
            my $outer = (async sub { await $inner; return 'resumed' })->();
            $pending = !$outer->is_ready;
            $got = eval { scalar $outer->get } // "CROAK: $@";
            $done->done(1);
        });
        $loop->run_until($done);
        ok($pending, 'the async sub suspended on a loop-backed future');
        is($got, 'resumed', 'and ->get pumped the loop to resume it');
        1;
LOOP
    diag("loop block failed: $@") unless $ok;
}

# ---- the keywords are lexical to the file that imports them -------------
{
    my $ok = eval q{
        package T::AA::NoImport;
        async sub nope { 1 }
        1;
    };
    ok(!$ok, 'a package that did not import cannot use async');
    like($@, qr/async|syntax|bareword/i, 'and says so at compile time');
}

done_testing;
