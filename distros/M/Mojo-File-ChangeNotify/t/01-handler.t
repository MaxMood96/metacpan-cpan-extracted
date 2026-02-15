#!perl
use 5.020;
use experimental "signatures";
use Test2::V0 '-no_srand';

use Mojo::File::ChangeNotify;

use File::Temp 'tempdir';

my $tempdir = tempdir(CLEANUP => 1);
my $testfile = "$tempdir/testfile";

my @events;
my $w = Mojo::File::ChangeNotify->instantiate_watcher(
    directories => [$tempdir],
    on_change => sub($s,$ev) {
        note "Saw event(s)";
        push @events, $ev;
        Mojo::IOLoop->stop_gracefully;
    });

# We need to give the watcher some time to start up :-/
my $create = Mojo::IOLoop->timer( 1 => sub {
    note "Creating file '$testfile'";
    open my $fh, '>', $testfile
        or die "Couldn't create '$testfile': $!";
});

my $timeout = Mojo::IOLoop->timer( 10 => sub {
    Mojo::IOLoop->stop_gracefully;
});

Mojo::IOLoop->start unless Mojo::IOLoop->is_running;

is \@events, [
    [{ path => $testfile, type => 'create' }],
];

done_testing;
