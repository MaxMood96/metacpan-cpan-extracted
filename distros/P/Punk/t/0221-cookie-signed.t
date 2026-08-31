#!perl
use 5.010;
use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/lib";
use Test::More;
use PunkTest;
use Punk ();

# `signed => 1` on $c->cookie, both directions: HMAC-SHA256 over
# `name=value` with the session's secret and the session's own
# sign/verify. The assertions that matter are the failures - every
# tampered, swapped or unsigned read must come back undef exactly as a
# missing cookie does - and the swap attack above all, because signing
# the value WITHOUT the name is the classic that makes any two signed
# cookies interchangeable.

my $ran;

{
    package SignApp;
    use Punk;
    session secret => 'signing-key';

    get '/set' => sub {
        my ($c) = @_;
        $c->cookie(theme => $c->param('v') // 'dark',
                   { signed => 1, max_age => 31536000 });
        $c->text('set');
    };
    get '/set-flat' => sub {           # the flat %opts spelling signs too
        my ($c) = @_;
        $c->cookie(theme => 'flat', signed => 1);
        $c->text('set');
    };
    get '/set-pair' => sub {
        my ($c) = @_;
        $c->cookie(a => 'one', { signed => 1 });
        $c->cookie(b => 'two', { signed => 1 });
        $c->text('set');
    };
    get '/get' => sub {
        my ($c) = @_;
        my $v = $c->cookie('theme', { signed => 1 });
        $c->text(defined $v ? "got:$v" : 'undef');
    };
    get '/get-b' => sub {
        my ($c) = @_;
        my $v = $c->cookie('b', { signed => 1 });
        $c->text(defined $v ? "got:$v" : 'undef');
    };
    get '/get-plain' => sub {
        my ($c) = @_;
        $c->text($c->cookie('theme') // 'undef');
    };
    get '/both' => sub {               # a session write beside a signed write
        my ($c) = @_;
        $c->session->{user} = 'alice';
        $c->cookie(theme => 'dual', { signed => 1 });
        $c->text('both');
    };
    get '/whoami' => sub {
        my ($c) = @_;
        $c->text(($c->session->{user} // 'nobody') . '/'
               . ($c->cookie('theme', { signed => 1 }) // 'undef'));
    };
}
my $app = SignApp->to_app;

sub set_cookie_value {
    my ($r, $name) = @_;
    for (my $i = 0; $i < @{ $r->[1] }; $i += 2) {
        next unless lc $r->[1][$i] eq 'set-cookie';
        my ($v) = $r->[1][$i + 1] =~ /\A\Q$name\E=([^;]*)/ or next;
        return $v;
    }
    return undef;
}
sub body { ref $_[0][2] eq 'ARRAY' ? join('', @{ $_[0][2] }) : '' }
sub read_theme {
    my ($cookie_header) = @_;
    return body(hit($app, path => '/get',
                    env => { HTTP_COOKIE => $cookie_header }));
}

# ---- round trip --------------------------------------------------------------

my $signed = do {
    my $r = hit($app, path => '/set');
    my $v = set_cookie_value($r, 'theme');
    like($r->[1][ (grep { lc $r->[1][$_] eq 'set-cookie' }
                   0 .. $#{ $r->[1] })[0] + 1 ],
         qr/Max-Age=31536000/, 'the other options still apply around signing');
    $v;
};
ok(defined $signed, 'the signed Set-Cookie arrived');
like($signed, qr/\A[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\z/,
    'and is two base64url runs joined by a dot - nothing to percent-encode');
is(read_theme("theme=$signed"), 'got:dark', 'a signed write reads back');

# ---- signed is readable, just not forgeable ----------------------------------

{
    require MIME::Base64;
    my ($payload) = split /\./, $signed;
    $payload =~ tr{-_}{+/};
    is(MIME::Base64::decode_base64($payload), 'theme=dark',
        'the payload is READABLE by anyone - signed is not secret, and this '
      . 'assertion is here so nobody mistakes it for encryption');
}

# ---- the tampers -------------------------------------------------------------

{
    my ($p, $m) = split /\./, $signed;
    my $flip = sub {
        my ($s) = @_;
        substr($s, 3, 1) = substr($s, 3, 1) eq 'A' ? 'B' : 'A';
        return $s;
    };
    is(read_theme('theme=' . $flip->($p) . ".$m"), 'undef',
        'a byte flipped in the value fails closed');
    is(read_theme("theme=$p." . $flip->($m)), 'undef',
        'a byte flipped in the MAC fails closed');
    is(read_theme("theme=$p"), 'undef',
        'the MAC stripped off entirely fails closed');
}

is(read_theme('theme=dark'), 'undef',
    'an unsigned cookie read as signed fails closed - a client cannot just '
  . 'write the bare value');

# ---- the swap attack ---------------------------------------------------------

{
    my $r = hit($app, path => '/set-pair');
    my $a = set_cookie_value($r, 'a');
    my $b = set_cookie_value($r, 'b');
    ok(defined $a && defined $b, 'two signed cookies set');
    is(body(hit($app, path => '/get-b',
                env => { HTTP_COOKIE => "b=$b" })),
       'got:two', 'b reads as b');
    is(body(hit($app, path => '/get-b',
                env => { HTTP_COOKIE => "b=$a" })),
       'undef',
       "a's perfectly valid signature under b's name fails - the name is in "
     . 'the MAC, which is the whole reason this feature is not one line');
}

# ---- signed read as plain: the raw form, chosen not discovered ---------------

is(body(hit($app, path => '/get-plain',
            env => { HTTP_COOKIE => "theme=$signed" })),
   $signed,
   'a plain read of a signed cookie returns the raw joined form, not the '
 . 'value - deliberate, so the option is explicit at every read site');

# ---- the flat-pairs set form signs too ---------------------------------------

{
    my $r = hit($app, path => '/set-flat');
    my $v = set_cookie_value($r, 'theme');
    is(read_theme("theme=$v"), 'got:flat', 'cookie(n => v, signed => 1) signs');
}

# ---- special and empty values ------------------------------------------------

for my $val ('a; b=c, d "quoted"', '') {
    my $r = hit($app, path => '/set', query => 'v=' . do {
        my $q = $val; $q =~ s/([^A-Za-z0-9_.~-])/sprintf '%%%02X', ord $1/ge; $q;
    });
    my $v = set_cookie_value($r, 'theme');
    is(read_theme("theme=$v"), "got:$val",
        sprintf("a value of %s round-trips through base64url",
                length $val ? 'cookie-hostile characters' : 'zero length'));
}

# ---- the session is a neighbour, not a casualty ------------------------------

{
    my $r = hit($app, path => '/both');
    my $theme = set_cookie_value($r, 'theme');
    my $sess  = set_cookie_value($r, 'punk.sid');
    ok(defined $theme, 'the signed cookie set beside a session write');
    ok(defined $sess,  'and the session cookie set beside the signed one');
    my $out = body(hit($app, path => '/whoami',
        env => { HTTP_COOKIE => "theme=$theme; punk.sid=$sess" }));
    is($out, 'alice/dual', 'both round-trip on one request, neither '
        . 'interfering with the other');
}

# ---- no secret croaks, both directions ---------------------------------------

{
    package NoSecret;
    use Punk;
    get '/w' => sub { $_[0]->cookie(x => 'y', { signed => 1 }); $_[0]->text('w') };
    get '/r' => sub { $_[0]->text($_[0]->cookie('x', { signed => 1 }) // 'u') };
}
{
    my $napp = NoSecret->to_app;
    my $w = hit($napp, path => '/w');
    is($w->[0], 500, 'a signed write with no session secret is a server '
        . 'error, not a silently unsigned cookie');
    my $rr = hit($napp, path => '/r', env => { HTTP_COOKIE => 'x=y' });
    is($rr->[0], 500, 'and so is a signed read - the config is missing, '
        . 'which is not the network\'s fault');
}

done_testing;
