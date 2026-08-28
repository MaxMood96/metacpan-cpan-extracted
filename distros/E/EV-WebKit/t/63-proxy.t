use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit; use IO::Socket::INET;

# tiny one-shot HTTP proxy that records the requested URL then serves a page.
# accept/read are non-blocking (a second EV::io watcher per connection reads
# incrementally into a buffer) rather than a plain blocking recv(): this
# process's single EV loop also pumps the GLib main context EV::Glib bridges
# WebKitGTK's IPC through, so a blocking recv() here stalls that context too
# -- empirically this left WebKit's network process waiting on the proxy
# connection for ~40-60s before giving up without ever writing the request
# (same class of EV::Glib-reentrancy hazard as lib/EV/WebKit.pm's _defer;
# see task-14-report.md for the traced repro).
my $srv = IO::Socket::INET->new(LocalAddr=>'127.0.0.1', LocalPort=>0, Listen=>1, ReuseAddr=>1)
    or plan skip_all => "cannot bind proxy socket: $!";
my $port = $srv->sockport;
my $hit;
my %conns;   # keep per-connection read watchers alive (keyed by the socket)
my $io = EV::io($srv, EV::READ, sub {
    my $c = $srv->accept or return;
    $c->blocking(0);
    my $buf = '';
    my $rw; $rw = EV::io($c, EV::READ, sub {
        my $n = sysread($c, my $chunk, 4096);
        if (!defined $n) { return if $!{EAGAIN} || $!{EWOULDBLOCK}; delete $conns{$c}; return }
        return delete $conns{$c} unless $n;    # EOF before a full request arrived
        $buf .= $chunk;
        return unless $buf =~ /\r?\n\r?\n/;    # wait for the full request headers
        ($hit) = $buf =~ /^GET\s+(\S+)/;
        print $c "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nConnection: close\r\nContent-Length: 21\r\n\r\n<html>proxied!</html>";
        close $c;
        delete $conns{$c};
    });
    $conns{$c} = $rw;
});

my $b = EV::WebKit->new(window=>[300,200], proxy => "http://127.0.0.1:$port");
my $body;
$b->go('http://proxy.test/page', sub {
    my (undef,$err)=@_;
    return do { $body = "ERR:$err"; EV::break } if $err;
    $b->script('return document.body.textContent', sub { $body=$_[0]; EV::break });
});
TWK::run_with_timeout(12);
like($hit // '', qr{proxy\.test|http://}, 'proxy received the request');
like($body // '', qr/proxied/, 'page served through proxy');
$b->quit;

# hashref form: { default => $uri, ignore => [@hosts] } -- same recording
# proxy, exercising the ref-branch/destructuring in set_proxy. The ignore
# list's own semantics are WebKit-internal and out of scope here; only the
# routing (branch coverage) is the target, so 'nonexistent.invalid' (which
# never matches proxy2.test) is inert by construction.
$hit = undef;
my $b2 = EV::WebKit->new(window=>[300,200],
    proxy => { default => "http://127.0.0.1:$port", ignore => ['nonexistent.invalid'] });
my $body2;
$b2->go('http://proxy2.test/page', sub {
    my (undef,$err)=@_;
    return do { $body2 = "ERR:$err"; EV::break } if $err;
    $b2->script('return document.body.textContent', sub { $body2=$_[0]; EV::break });
});
TWK::run_with_timeout(12);
like($hit // '', qr{proxy2\.test|http://}, 'proxy received the request (hashref proxy form)');
like($body2 // '', qr/proxied/, 'page served through proxy (hashref proxy form)');
$b2->quit;

# Finding 2 (r12): a malformed/absent default proxy URI must fail loudly
# (croak) instead of letting WebKit silently discard it and route direct --
# GLib's own diagnostic for this is a C-level CRITICAL, not a Perl exception,
# so eval could never catch it without this module validating proactively.
my $b3 = EV::WebKit->new(window=>[100,80]);

eval { $b3->set_proxy('') };
like($@, qr/invalid|non-empty/, "set_proxy('') croaks");

eval { $b3->set_proxy('garbage') };
like($@, qr/invalid|non-empty/, "set_proxy('garbage') croaks");

eval { $b3->set_proxy({ ignore => [] }) };
like($@, qr/invalid|non-empty/, "set_proxy({ignore=>[]}) (no default) croaks");

# GStrv-truncation guard: an undef entry in the ignore list would marshal to a
# NULL that silently drops every host after it (routing them THROUGH the proxy);
# a non-arrayref ignore is a type error. Both croak. (An empty ignore list is
# legal -- "proxy everything" -- and is exercised by the hashref form above.)
eval { $b3->set_proxy({ default => 'http://127.0.0.1:1', ignore => ['ok.test', undef, 'skip.test'] }) };
like($@, qr/ignore.*entries must be/, 'set_proxy ignore with an undef entry croaks (GStrv-truncation guard)');
eval { $b3->set_proxy({ default => 'http://127.0.0.1:1', ignore => 'localhost' }) };
like($@, qr/ignore.*must be an arrayref/, 'set_proxy ignore as a non-arrayref croaks');
eval { $b3->set_proxy({ default => 'http://127.0.0.1:1', ignoer => ['x'] }) };
like($@, qr/unknown proxy-hash key.*ignoer/, "set_proxy with a typo'd hash key croaks (no silent drop)");
$b3->quit;

eval { EV::WebKit->new(window=>[100,80], proxy=>'garbage') };
like($@, qr/invalid|non-empty/, "new(proxy=>'garbage') croaks");

done_testing;
