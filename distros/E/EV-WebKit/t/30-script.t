use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit; use File::Temp 'tempdir';

my $b = EV::WebKit->new(window=>[300,200]);
my %got;
$b->load_html('<title>T</title><p id=p>hello</p>', sub {
    my $n = 0; my $done = sub { EV::break if ++$n == 6 };
    $b->script('return 1 + 2', sub { $got{num}  = $_[0]; $done->() });
    $b->script('return document.getElementById("p").textContent', sub { $got{str} = $_[0]; $done->() });
    $b->script('return [1,2,3]', sub { $got{arr} = $_[0]; $done->() });
    $b->script('return {a:1,b:[2,3],c:null}', sub { $got{obj} = $_[0]; $done->() });
    $b->script('throw new Error("boom")', sub { $got{err} = $_[1]; $done->() });
    $b->script_async('return 1', { bad => sub {} }, sub { $got{enc_err} = $_[1]; $done->() });
});
TWK::run_with_timeout(10);
is($got{num}, 3, 'number marshalled');
is($got{str}, 'hello', 'string marshalled');
is_deeply($got{arr}, [1,2,3], 'array marshalled');
is_deeply($got{obj}, {a=>1, b=>[2,3], c=>undef}, 'object marshalled (null -> undef)');
like($got{err}, qr/boom/, 'JS exception -> err');
like($got{enc_err}, qr/^encode error: /, 'unencodable args -> encode error');

# wait_for/screenshot/pdf use `my $cb = pop` with no coderef check, so a
# missing callback silently grabs a data argument (an options hash element or
# a path) as $cb instead -- which then dies with a useless "not a CODE
# reference" deep inside an unrelated later completion. Catch the misuse
# immediately and loudly (croak) instead.
my $tmp = tempdir(CLEANUP=>1);
my $unwanted_png = "$tmp/should-not-be-created.png";
my $unwanted_pdf = "$tmp/should-not-be-created.pdf";

eval { $b->wait_for('#p') };
like($@, qr/callback/i, 'wait_for without a callback croaks immediately');

eval { $b->screenshot($unwanted_png) };
like($@, qr/callback/i, 'screenshot without a callback croaks immediately');

eval { $b->pdf($unwanted_pdf) };
like($@, qr/callback/i, 'pdf without a callback croaks immediately');

ok(!-e $unwanted_png, 'screenshot croak happened before any file was written');
ok(!-e $unwanted_pdf, 'pdf croak happened before any file was written');

# _defer (which backs _call_js's completion, and so script/find/find_all/
# html) lacked _defer_final's `return unless $cb` guard, so a cb-less call on
# a live browser eventually ran `undef->(@a)` inside an EV timer callback.
# EV catches watcher-callback exceptions (unlike the GI-callback-argument
# crash in mock_scheme/finding 1) and routes them to $EV::DIED (default:
# warn) -- so this "only" produced ugly noise rather than crashing, but it
# is still a real bug this fix must silence.
my @caught;
{
    local $EV::DIED = sub { push @caught, "\$EV::DIED: $@" };
    $b->script('return 1');           # no callback at all -- must be a clean no-op
    my $t = EV::timer(0.5, 0, sub { EV::break });
    EV::run;
}
is(scalar(@caught), 0, 'script() with no callback does not trip $EV::DIED')
    or diag(explain(\@caught));

# script_async's real signature is ($body, \%args, $cb), but script() is
# ($js, $cb) -- so omitting \%args is the natural slip, and it used to bind the
# callback into the args slot: _enc died on the coderef inside an eval, the
# error was routed to _defer_final(undef), and the callback was never called at
# all, with no warning. Control.pm compensated for exactly this on the wire; the
# in-process method now does it itself, and Control's copy is gone.
{
    my $two = EV::WebKit->new(window => [200,150], ephemeral => 1, timeout => 10);
    my ($v, $e, $fired) = (undef, undef, 0);
    $two->load_html('<p>x</p>', sub {
        $two->script_async('return 6 * 7;', sub { ($v, $e) = @_; $fired++; EV::break });
    });
    TWK::run_with_timeout(20);
    is($fired, 1, 'script_async(body, cb) calls its callback exactly once');
    is($e, undef, '...without an error') or diag $e;
    is($v, 42, '...with the result');
    # and the three-argument form is untouched
    my ($v3, $f3) = (undef, 0);
    $two->script_async('return A.n * 2;', { n => 21 }, sub { $v3 = $_[0]; $f3++; EV::break });
    TWK::run_with_timeout(20);
    is($f3, 1, 'script_async(body, args, cb) still works');
    is($v3, 42, '...and still sees its arguments');
    $two->quit;
}

# script/script_async never validated their JS, unlike find_js, add_user_script
# and find. Measured: script(undef, $cb) concatenated undef into the body,
# warned "Use of uninitialized value" from inside WebKit.pm, and then resolved
# (undef, undef) -- a false success masking the caller's own bug. And
# script($cb), the snippet omitted, bound the coderef to $js and left $cb undef,
# so the callback was never called at all.
{
    my $s = EV::WebKit->new(window => [200,150], ephemeral => 1, timeout => 8);
    my $ready = 0;
    $s->load_html('<p>x</p>', sub { $ready = 1; EV::break });
    TWK::run_with_timeout(20);
    ok($ready, 'premise: a page is loaded');

    my @w; local $SIG{__WARN__} = sub { push @w, $_[0] };
    for my $m (qw(script script_async)) {
        ok(!eval { $s->$m(undef, sub {}); 1 }, "$m(undef) croaks rather than reporting a false success");
        like($@, qr/a JavaScript snippet is required/, '...saying so');
        ok(!eval { $s->$m(sub {}); 1 }, "$m(\$cb) with the snippet omitted croaks rather than hanging");
        like($@, qr/did you omit the snippet/, '...naming the likely mistake');
    }
    is(scalar(@w), 0, 'none of that warned from inside the module');
    $s->quit;
}

done_testing;
