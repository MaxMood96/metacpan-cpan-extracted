use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available(); use TCTL;
use File::Temp qw(tempdir);
use EV; use EV::WebKit; use EV::WebKit::Control;

# An Element cannot cross a socket, so find() answers with a handle the server
# holds on the client's behalf.
#
# The hazard this exists to avoid: every find() mints an Element that holds the
# browser, so a table that is never pruned rebuilds -- in Perl -- the unbounded
# registry growth just fixed on the JavaScript side. A find() poll loop against a
# long-lived page is the ORDINARY case.

my $dir  = tempdir(CLEANUP => 1);
my $path = "$dir/el.sock";

my $b = EV::WebKit->new(window => [300,200], ephemeral => 1);
$b->mock_scheme('el', sub {
    my $uri = shift;
    return ('<html><body><h1 id=greeting>hi</h1><p>a</p><p>b</p><p>c</p></body></html>', 'text/html')
        if $uri =~ /p\b|p$/;
    return ('<html><body><h1>other</h1></body></html>', 'text/html');
});
my $ctl = EV::WebKit::Control->listen($b, path => $path);
my $cl  = TCTL->new($path);
$cl->pump(1);   # hello

sub reply { $cl->reply(@_) }   # matches on the request id, skipping events

reply({ i => 1, m => 'go', a => ['el://p'] }, 25);

# find returns a handle, and the handle works
my $r = reply({ i => 2, m => 'find', a => ['h1'] });
my $h = $r->{r}{h};
ok(defined $h, 'find returns a handle');
is(reply({ i => 3, m => 'el.text', h => $h })->{r}, 'hi', 'the handle reads its element');

# no match is not an error -- it is a null result, exactly as in-process.
# ok($r) first: reply() answers undef on a timeout, and `undef->{r}` is undef
# while `!exists undef->{e}` is true, so both assertions below pass on a request
# that was never answered at all.
$r = reply({ i => 4, m => 'find', a => ['#nope'] });
ok($r, 'the no-match request was answered');
is($r->{r}, undef, 'no match answers null');
ok(!exists $r->{e}, '...and is not an error');

# find_all returns a handle each
$r = reply({ i => 5, m => 'find_all', a => ['p'] });
is(scalar @{ $r->{r} }, 3, 'find_all returns a handle per match');
cmp_ok(scalar keys %{ $ctl->{handles} }, '>=', 4, 'the server is holding them');

# an element method that takes arguments. The h1 carries an id so this reads a
# VALUE: against an attribute-less element the expected answer is undef, which
# is also what a dropped argument, a croak and a timeout all produce.
is(reply({ i => 6, m => 'el.tag', h => $h })->{r}, 'h1', 'el.tag works');
is(reply({ i => 7, m => 'el.attr', h => $h, a => ['id'] })->{r}, 'greeting', 'el.attr with an argument works');

# NAVIGATION frees every handle -- they are all stale anyway, and keeping them is
# precisely how you rebuild the registry leak in Perl
reply({ i => 8, m => 'go', a => ['el://other'] }, 25);
is(scalar keys %{ $ctl->{handles} }, 0, 'navigating frees every handle');

# ...and a handle from the previous page fails cleanly rather than crashing
like(reply({ i => 9, m => 'el.text', h => $h })->{e}, qr/stale element/,
    'a handle from the old page is stale, not a crash');

# el.release frees one
reply({ i => 10, m => 'go', a => ['el://p'] }, 25);
my $h2 = reply({ i => 11, m => 'find', a => ['h1'] })->{r}{h};
is(scalar keys %{ $ctl->{handles} }, 1, 'one handle held');
reply({ i => 12, m => 'el.release', h => $h2 });
is(scalar keys %{ $ctl->{handles} }, 0, 'el.release frees it');

# DISCONNECT frees that client's handles
{
    my $c2 = TCTL->new($path);
    $c2->pump(1);   # hello
    $c2->reply({ i => 1, m => "find", a => ["h1"] }, 15);
    cmp_ok(scalar keys %{ $ctl->{handles} }, '>=', 1, 'the second client holds a handle');
    $c2->close;
    for (1 .. 10) { my $t = EV::timer(0.05, 0, sub { EV::break }); EV::run }   # let the server notice EOF
    is(scalar keys %{ $ctl->{handles} }, 0, 'disconnecting frees that client\'s handles');
}

# an unknown element method is an error, not silence
like(reply({ i => 13, m => 'el.no_such', h => 1 })->{e}, qr/unknown method/,
    'an unknown el.* method answers with an error');

# find_js resolves with an element too, so it needs the same handle marshalling
# find/find_all get -- a method added to the async table instead would answer
# with an unserialisable object. resize/zoom are plain forwards, but the client
# POD now promises them.
{
    reply({ i => 39, m => 'go', a => ['el://p'] }, 25);   # earlier blocks navigate away
    my $r = reply({ i => 40, m => 'find_js',
                    a => ['return [...document.querySelectorAll("p")].find(x => x.textContent === "b");'] });
    ok($r, 'the find_js request was answered');
    ok(!exists $r->{e}, 'find_js is accepted over the socket') or diag $r->{e};
    my $jh = $r->{r}{h};
    ok(defined $jh, 'find_js answers with a handle');
    is(reply({ i => 41, m => 'el.text', h => $jh })->{r}, 'b', 'the handle reads the node the snippet chose');

    $r = reply({ i => 42, m => 'find_all_js', a => ['return document.querySelectorAll("p");'] });
    is(scalar @{ $r->{r} || [] }, 3, 'find_all_js answers with a handle per node');

    # resize BEFORE zoom: the viewport it reports is in CSS pixels, which zoom
    # scales -- at zoom 2 a 400px window reports 200.
    $r = reply({ i => 43, m => 'resize', a => [400, 320] }, 25);
    ok($r, 'the resize request was answered');
    ok(!exists $r->{e}, 'resize is forwarded') or diag $r->{e};
    is($r->{r}{width}, 400, 'resize answers with the size the page has');

    $r = reply({ i => 44, m => 'zoom', a => [2] });
    ok($r, 'the zoom request was answered');
    ok(!exists $r->{e}, 'zoom is forwarded') or diag $r->{e};
    is(reply({ i => 45, m => 'zoom' })->{r}, 2, 'and reads back');
}

$ctl->close;
$b->quit;

done_testing;
