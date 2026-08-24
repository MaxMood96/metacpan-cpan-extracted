use strict;
use warnings;
use Test::More;
use Plack::Test;
use HTTP::Request::Common;
use Scalar::Util ();

{
    package TestApp;
    use Dancer2;
    use Uniform::HTMX::Dancer2;

    get '/test' => sub {
        if (is_htmx) {
            my $target = htmx->target || 'none';
            my $prompt = htmx->prompt || 'none';

            htmx->res_retarget('#output-div');
            htmx->res_trigger('itemSaved', { id => 101 });

            return "HTMX Request: target=$target, prompt=$prompt";
        }
        return "Standard Request";
    };

    # Calls htmx twice; used to prove both calls share one instance and
    # that headers set across both calls all survive to the response.
    get '/test-multi' => sub {
        my $first  = htmx;
        $first->res_retarget('#first-call');

        my $second = htmx;
        $second->res_reswap('outerHTML');

        return Scalar::Util::refaddr($first) == Scalar::Util::refaddr($second)
            ? 'same instance' : 'different instance';
    };

    # HX-Request sent as a literal false-ish string rather than omitted
    # entirely; is_htmx must still report false.
    get '/test-false-header' => sub {
        return is_htmx ? 'true' : 'false';
    };
}

my $app  = TestApp->to_app;
my $test = Plack::Test->create($app);

subtest 'Standard Non-HTMX Request' => sub {
    my $res = $test->request(GET '/test');
    is $res->code, 200, 'HTTP status 200';
    is $res->content, 'Standard Request', 'Executes non-HTMX code path';
    ok !$res->header('HX-Retarget'), 'No HX-Retarget header returned';
};

subtest 'HTMX Request & Header Mutation' => sub {
    my $req = GET '/test',
    'HX-Request' => 'true',
    'HX-Target'  => '#card',
    'HX-Prompt'  => 'user_input';

    my $res = $test->request($req);
    is $res->code, 200, 'HTTP status 200';
    is $res->content, 'HTMX Request: target=#card, prompt=user_input', 'Reads request headers correctly';
    is $res->header('HX-Retarget'), '#output-div', 'Sets HX-Retarget header';
    ok $res->header('HX-Trigger'), 'Sets HX-Trigger header';
};

subtest 'Repeated htmx calls share one instance' => sub {
    my $res = $test->request(GET '/test-multi');
    is $res->code, 200, 'HTTP status 200';
    is $res->content, 'same instance', 'Both calls to htmx return the same object';
    is $res->header('HX-Retarget'), '#first-call', 'Header set on first call survives';
    is $res->header('HX-Reswap'), 'outerHTML', 'Header set on second call also applied';
};

subtest 'HX-Request sent as false-ish string' => sub {
    my $req = GET '/test-false-header', 'HX-Request' => 'false';
    my $res = $test->request($req);
    is $res->code, 200, 'HTTP status 200';
    is $res->content, 'false', 'is_htmx is false when HX-Request is not "true"';
};

done_testing();
