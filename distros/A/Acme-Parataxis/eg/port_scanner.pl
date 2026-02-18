use v5.40;
use lib 'lib';
use blib;
use Acme::Parataxis;
use IO::Socket::INET;
use Errno       qw[EINPROGRESS EWOULDBLOCK];
use Time::HiRes qw[time];
$|++;

# This demonstrates how fibers can be used to perform concurrent
# network operations using standard Perl modules (IO::Socket) and the
# Parataxis non-blocking I/O scheduler.
my $target = '127.0.0.1';
my @ports  = ( 22, 80, 443, 3306, 3389, 5432, 8080, 9999 );    # Common ports + our demo server

# To make the test interesting, let's start a tiny listener on 9999 in a fiber
Acme::Parataxis::run(
    sub {
        say "Main: Starting parallel scan of $target...";
        my $start_time = time;

        # Start a dummy listener so we have at least one open port to find
        my $server = IO::Socket::INET->new( LocalAddr => $target, LocalPort => 9999, Listen => 5, Reuse => 1, Blocking => 0 );
        say 'Main: Local dummy server started on 9999' if $server;
        my @results;
        my @futures;

        # Spawn a fiber for each port we want to scan
        for my $port (@ports) {
            push @futures, Acme::Parataxis->spawn(
                sub {
                    my $s = IO::Socket::INET->new( PeerAddr => $target, PeerPort => $port, Proto => 'tcp', Blocking => 0 );

                    # If the socket failed immediately (e.g. invalid target)
                    return { port => $port, status => 'closed' } if !$s;

                    # On most OSs, a non-blocking connect returns immediately with EINPROGRESS
                    # We wait for the socket to become WRITABLE to know if it connected.
                    # We'll give it a 1s timeout
                    my $res = Acme::Parataxis->await_write( $s, 1000 );
                    if ( defined $res && $res > 0 && $s->connected ) {
                        $s->close();
                        return { port => $port, status => 'OPEN' };
                    }
                    else {
                        return { port => $port, status => 'closed' };
                    }
                }
            );
        }

        # Wait for all scanners to finish
        for my $f (@futures) {
            my $r = $f->await();
            push @results, $r;
            if ( $r->{status} eq 'OPEN' ) {
                say "  [!] Port $r->{port} is OPEN";
            }
        }
        my $elapsed = time() - $start_time;
        say 'Main: Scan complete.';
        say 'Summary:';
        for my $r ( sort { $a->{port} <=> $b->{port} } @results ) {
            say sprintf '  Port %-5d: %s', $r->{port}, $r->{status};
        }
        say sprintf 'Total scan time: %.2fs', $elapsed;
        $server->close() if $server;
        Acme::Parataxis::stop();
    }
);
