use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit;

my @uris;
my $b = EV::WebKit->new(window=>[300,200], timeout=>3, on_policy => sub {
    my ($i)=@_; push @uris, $i->uri;
    # block any navigation to blocked.test, allow everything else
    ($i->uri // '') =~ /blocked\.test/ ? $i->block : $i->allow;
});
my ($err);
$b->go('http://blocked.test/', sub { (undef,$err)=@_; EV::break });
TWK::run_with_timeout(10);
ok(scalar(@uris), 'decide-policy fired with a uri');
ok(defined $err, 'blocked navigation did not "finish" (errored/ignored)') or note("err=".($err//'undef'));
# blocked.test never resolves via DNS, so a NO-OP block() would still leave
# $err defined (a fast "Name or service not known" load-failed) -- that would
# make the assertion above pass even if decide-policy interception is broken.
# A real ignore() during decide-policy stops WebKit before it ever attempts
# DNS, so the only way $err becomes defined is via the op-level timeout below.
# This distinguishes "actually blocked" from "merely unreachable".
is($err, 'timeout', 'blocked navigation specifically timed out (decide-policy ignore() pre-empted DNS/load-failed)');
done_testing;
