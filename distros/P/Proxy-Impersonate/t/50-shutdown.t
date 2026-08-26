use v5.10; use strict; use warnings;
use Test::More;
use EV;
use File::Temp qw(tempdir);
use Proxy::Impersonate;

my $p = Proxy::Impersonate->new(impersonate => 'chrome131',
    listen => '127.0.0.1:0', cert_dir => tempdir(CLEANUP => 1));

# inject a fake active connection to prove shutdown closes it
my $closed = 0;
{ package FakeConn; sub _close { ${ $_[0] } = 1 } }
my $fake = bless \$closed, 'FakeConn';
$p->{conns}{$fake} = $fake;

# shutdown must NOT break the loop: a later timer still fires
my $ran_after = 0;
my $t1 = EV::timer(0,    0, sub { $p->shutdown });
my $t2 = EV::timer(0.05, 0, sub { $ran_after = 1; EV::break() });
EV::run;

ok($closed, 'shutdown closed the active connection');
ok($ran_after, 'EV loop kept running after shutdown (no EV::break)');
is_deeply($p->{conns}, {}, 'connections cleared');
ok(!$p->{aw}, 'accept watcher dropped');
ok(!$p->{multi}, 'multi released');
done_testing;
