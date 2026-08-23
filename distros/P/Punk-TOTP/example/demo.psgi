#!/usr/bin/env plackup
# A one-page Punk::TOTP demonstration: scan the QR with any
# authenticator app, then type the codes it shows you.
#
#     plackup -s Hyperman example/demo.psgi
#
# The secret is generated at boot and lives in memory, so every
# restart is a fresh enrolment. The replay floor lives in memory too -
# submit the same code twice and watch the second one refuse, which is
# the difference between TOTP and a TOTP-shaped function.

use strict;
use warnings;

# Development fallback: run against sibling working copies before the
# dists are installed (see t/sibling.pl for the reasoning).
BEGIN {
    for my $sib ('..', '../..', '.') {
        for my $dist ('File-Raw-Hash', 'QR-Code', 'Punk-TOTP') {
            my $b = "$sib/$dist/blib";
            unshift @INC, "$b/lib", "$b/arch" if -d $b;
        }
    }
}

{
    package Demo;
    use Punk;
    use Punk::TOTP;
    use QR::Code;

    # one demo identity, reborn on every restart
    my $SECRET  = Punk::TOTP->secret;
    my $URI     = Punk::TOTP->uri($SECRET,
        issuer  => 'Punk::TOTP demo',
        account => 'you@example.com');
    my $last_counter;                      # the replay floor
    my @log;                               # what happened, newest first

    my $QR = QR::Code->svg($URI, ecc => 'H', logo => 'Punk');

    my $page = sub {
        my ($c) = @_;
        my $rows = join '', map {
            qq{<li class="$_->{class}">$_->{text}</li>}
        } @log;
        $rows = '<li class="quiet">nothing yet - scan, then type a '
              . 'code</li>' unless $rows;
        return $c->html(<<"HTML");
<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Punk::TOTP demo</title>
<style>
  :root { color-scheme: light dark }
  body { font: 16px/1.5 system-ui, sans-serif; max-width: 40rem;
         margin: 3rem auto; padding: 0 1rem }
  .qr { width: 16rem; max-width: 80vw; margin: 1rem 0 }
  .qr svg { width: 100%; height: auto; display: block;
            background: #fff; border-radius: 8px }
  code { user-select: all }
  form { display: flex; gap: .5rem; margin: 1rem 0 }
  input { font: inherit; padding: .5rem .75rem; width: 11ch;
          letter-spacing: .2ch }
  button { font: inherit; padding: .5rem 1rem }
  ul { list-style: none; padding: 0 }
  li { padding: .35rem .6rem; border-radius: 6px; margin: .25rem 0 }
  .ok     { background: #1a7f3722; }
  .bad    { background: #b3261e22; }
  .quiet, .error { opacity: .7 }
  small { opacity: .6 }
</style></head><body>

<h1>Punk::TOTP</h1>
<p>Scan with Google Authenticator, 1Password, Aegis - anything.
Or add the secret by hand: <code>$SECRET</code></p>

<div class="qr">$QR</div>

<form method="post" action="/verify">
  <input name="code" autofocus autocomplete="one-time-code"
         inputmode="numeric" pattern="[0-9]*" placeholder="000000">
  <button>Verify</button>
</form>

<ul>$rows</ul>

<p><small>The secret lives in memory: restarting the server is a
fresh enrolment. Try a code twice - the second submission is refused
by the replay floor, and a code stays good for about ninety seconds
of clock drift (skew 1).</small></p>

</body></html>
HTML
    };

    get '/' => $page;

    post '/verify' => sub {
        my ($c) = @_;
        my $code = $c->param('code') // '';
        $code =~ s/\s+//g;

        my ($ok, $counter) = Punk::TOTP->verify($SECRET, $code,
            defined $last_counter ? (last_counter => $last_counter) : ());

        if ($ok) {
            $last_counter = $counter;
            unshift @log, { class => 'ok',
                text => "accepted <code>$code</code> "
                      . "(counter $counter - now the replay floor)" };
        } else {
            my $why = '';
            if ($code =~ /\A[0-9]{6}\z/ && defined $last_counter) {
                # was it refused as a replay rather than as wrong?
                my ($would) = Punk::TOTP->verify($SECRET, $code);
                $why = ' - a replay: that code was already spent'
                    if $would;
            }
            my $shown = $code =~ /\A[0-9]{0,8}\z/ ? $code : '(not digits)';
            unshift @log, { class => 'bad',
                text => "refused <code>$shown</code>$why" };
        }
        splice @log, 8;                    # the page is not a logbook
        return $c->redirect('/');
    };
}

Demo->to_app;
