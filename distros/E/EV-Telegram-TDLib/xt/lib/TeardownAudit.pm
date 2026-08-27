package TeardownAudit;

use strict;
use warnings;

# Loaded with -M before the test, so this END block registers first and
# therefore runs LAST -- after EV::Telegram::TDLib's own END has sent its
# closes. What survives to here is what TDLib would still be holding when
# its statics are torn down.
#
# TDLib performs no client teardown once exit has begun (Client.cpp: ~Impl
# returns early on ExitGuard::is_exited), and ~MultiImpl then detaches its
# scheduler thread instead of joining it before calling finish() -- so a
# client left materialised at exit is a genuine race, not a tidy leak.
#
# An id that never carried a request is inert: tdjson only creates a client
# on its first request, so a reserved-only id has no MultiImpl behind it.

my %materialised;   # client_id => 1, once a real request was sent to it
my %closed;         # client_id => 1, once a close was sent to it

sub import {
    my $target = 'EV::Telegram::TDLib';
    require EV::Telegram::TDLib;

    my $send = $target->can('_send') or die "no _send to hook";
    no warnings 'redefine';
    no strict 'refs';
    *{"${target}::_send"} = sub {
        my ($cid, $json) = @_;
        # a test that stubs _send itself replaces this hook; that is fine,
        # because nothing then reaches TDLib and the id stays unmaterialised
        if (defined $cid) {
            $materialised{$cid} = 1;
            $closed{$cid} = 1 if $json && $json =~ /"\@type"\s*:\s*"close"/;
        }
        return $send->(@_);
    };
}

END {
    my @live = sort { $a <=> $b } grep { !$closed{$_} } keys %materialised;
    return unless @live;
    # printed, not died: this runs during global destruction
    print STDERR "TEARDOWN-AUDIT-LIVE: @live\n";
}

1;
