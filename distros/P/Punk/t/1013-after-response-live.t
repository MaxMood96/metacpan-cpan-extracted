#!perl
use 5.010;
use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/lib";
use Test::More;
use File::Temp ();
use IO::Socket::INET;
use Time::HiRes ();

# after_response on a real Hyperman worker, where the callbacks are handed to
# the loop as a zero-delay timer rather than run inline.
#
# t/0132-after-response.t covers the ordering and the two paths that can be
# driven in one process. This is the one that cannot: a timer that never fires
# is a silent no-op, and nothing in-process would notice.

BEGIN {
    eval { require Hyperman; 1 }
        or plan skip_all => 'Hyperman required for these tests';
}

our $dir  = File::Temp->newdir();
our $file = "$dir/ran.txt";
my $port = 25700 + ($$ % 300);
my $host = "127.0.0.1:$port";

my $pid = fork // die "fork: $!";
if (!$pid) {
    open STDERR, '>', '/dev/null';

    package ARLive;
    use Punk;

    our $FILE = $main::file;

    sub note_line {
        my ($what) = @_;
        open my $fh, '>>', $FILE or return;
        print {$fh} "$what\n";
        close $fh;
    }

    hook after_response => sub { note_line('hook'); return };

    get '/work' => sub {
        my ($c) = @_;
        note_line('handler');
        $c->after_response(sub { note_line('queued') });
        $c->text('sent');
    };

    get '/ping' => sub { $_[0]->text('pong') };

    package main;
    Hyperman->run(app => ARLive->to_app, host => '127.0.0.1',
                  port => $port, workers => 1);
    exit 0;
}

for (1 .. 60) {
    my $s = IO::Socket::INET->new(PeerAddr => $host);
    last if $s;
    Time::HiRes::sleep(0.1);
}

sub get {
    my ($path) = @_;
    my $s = IO::Socket::INET->new(PeerAddr => $host) or die "connect: $!";
    $s->autoflush(1);
    syswrite $s, "GET $path HTTP/1.1\r\nHost: $host\r\nConnection: close\r\n\r\n";
    my $buf = '';
    while (sysread($s, my $chunk, 65536)) { $buf .= $chunk }
    close $s;
    return $buf;
}

sub lines {
    open my $fh, '<', $file or return ();
    my @l = <$fh>;
    close $fh;
    chomp @l;
    return @l;
}

# The response first. Nothing is asserted about the file yet: the timer fires
# on the loop's next pass and racing it from here would be a flaky test either
# way it was written.
my $res = get('/work');
like($res, qr{\AHTTP/1\.1 200}, 'the response arrives');
like($res, qr/sent\z/,          'with the body the handler returned');

# Then converge: a bound, not a sleep, because a loaded smoker schedules the
# worker when it schedules it.
my @got;
for (1 .. 100) {
    @got = lines();
    last if @got >= 3;
    Time::HiRes::sleep(0.05);
}

is_deeply(\@got, [ 'handler', 'hook', 'queued' ],
    'the loop ran the phase after the handler, hook first, then the queue');

# And the worker is still healthy: a timer callback that took the loop down
# would show here rather than in the assertion above.
like(get('/ping'), qr/pong\z/, 'the worker serves the next request');

END { kill 'TERM', $pid if $pid; waitpid $pid, 0 if $pid }

done_testing;
