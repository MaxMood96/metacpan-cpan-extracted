package FakeSMTPd;

use strict;
use warnings;
use IO::Socket::INET;
use IO::Handle ();
use File::Spec ();
use File::Temp ();
use POSIX ();

# An SMTP-shaped listener, so the smtp transport's tests run on a box
# with no mail server. Forked; one child serves every connection of one
# test file; each connection's transcript - every command the client
# sent, and the DATA bytes - goes to <dir>/conn.N, read by the parent
# after stop(). Never through a pipe the parent shares with the TAP
# stream: the child sends STDOUT and STDERR to devnull, alarms, and
# _exits. The transcript is written unbuffered: stop() TERMs the child
# the moment the client has its last reply, and _exit flushes nothing.
#
# The listener is always plaintext; a TLS mode upgrades each accepted
# connection in _serve. An IO::Socket::SSL listener folds the handshake
# into accept(), which returns undef when a client refuses the
# certificate - and that ended the serve loop, so the next connection of
# the same test found nothing listening. The context is made in new() so
# a bad cert or key fails there, where a test can skip.
#
#   FakeSMTPd->new(mode => 'ok', tls => 'none' | 'starttls' | 'implicit',
#                  cert => $pem, key => $pem, auth => 'PLAIN LOGIN',
#                  size => 10_000_000)
#
# Modes:
#   ok               220, EHLO caps, 250s, 354, "250 2.0.0 queued as ABC123"
#   tempfail_rcpt    451 4.7.1 on every RCPT
#   permfail_rcpt    550 5.1.1 on every RCPT
#   mixed_rcpt       first RCPT 250, the rest 550
#   tempfail_data    451 4.3.0 on the final DATA reply
#   permfail_data    554 5.7.1 on the final DATA reply
#   auth_fail        535 5.7.8 on AUTH
#   no_starttls      EHLO omits STARTTLS
#   starttls_refused STARTTLS answered 454
#   drop_in_data     close the socket after 354 and the first line of data
#   size             552 5.3.4 on DATA end when the message is over `size`
#   slow             accept, never greet
#   helo_only        502 on EHLO, 250 on HELO

sub new {
    my ($class, %o) = @_;
    $o{mode} //= 'ok';
    $o{tls}  //= 'none';
    $o{auth} //= 'PLAIN LOGIN';
    $o{size} //= 10_000_000;
    my $dir = File::Temp->newdir;
    if ($o{tls} ne 'none') {
        require IO::Socket::SSL;
        $o{ctx} = IO::Socket::SSL::SSL_Context->new(
            SSL_server => 1, SSL_cert_file => $o{cert}, SSL_key_file => $o{key},
        ) or die "cannot make a TLS context: " . ($IO::Socket::SSL::SSL_ERROR || $!);
    }
    my $srv = IO::Socket::INET->new(
        LocalHost => '127.0.0.1', LocalPort => 0, Listen => 16, ReuseAddr => 1,
    ) or die "cannot listen: $!";
    my $port = $srv->sockport;
    pipe my $rd, my $wr or die "pipe: $!";
    my $pid = fork;
    die "fork: $!" unless defined $pid;
    if (!$pid) {
        close $rd;
        open STDOUT, '>', File::Spec->devnull();
        open STDERR, '>', File::Spec->devnull();
        # Test::Builder dup'd the TAP pipe at load; a child still holding
        # that copy keeps the harness waiting if the test dies before END
        if (my $tb = eval { Test::Builder->new }) {
            close $_ for grep { defined } $tb->output, $tb->failure_output, $tb->todo_output;
        }
        alarm 120;
        $SIG{TERM} = sub { POSIX::_exit(0) };
        $SIG{PIPE} = 'IGNORE';
        syswrite $wr, "1";
        close $wr;
        my $n = 0;
        while (my $c = $srv->accept) {
            $n++;
            _serve(\%o, $c, "$dir/conn.$n");
        }
        POSIX::_exit(0);
    }
    close $wr;
    sysread $rd, my $ready, 1;
    close $rd;
    $srv->close;
    return bless { pid => $pid, port => $port, dir => $dir, opts => \%o }, $class;
}

sub _serve {
    my ($o, $c, $file) = @_;
    my $mode = $o->{mode};
    my $tls_on = $o->{tls} eq 'implicit';
    open my $t, '>', $file or return;
    $t->autoflush(1);
    my $say = sub { print $c join('', @_) };
    my $log = sub { print $t @_ };
    $c->autoflush(1);

    if ($tls_on) {
        # implicit TLS: the handshake before the first byte of SMTP. A
        # client that refuses the certificate, or speaks plaintext, fails
        # it here; the listener goes on to the next connection
        my $up = IO::Socket::SSL->start_SSL($c, SSL_server => 1, SSL_reuse_ctx => $o->{ctx});
        if (!$up) { $log->("S: TLS handshake failed\n"); close $c; close $t; return }
        $log->("S: TLS\n");
    }

    if ($mode eq 'slow') { sleep 30; close $c; close $t; return }

    $say->("220 fake ESMTP\r\n");
    my $rcpt_n = 0;
    my $size_param = 0;
    while (defined(my $line = <$c>)) {
        $line =~ s/\r?\n\z//;
        $log->("C: $line\n");
        if ($line =~ /^EHLO\b/i) {
            if ($mode eq 'helo_only') { $say->("502 5.5.1 EHLO not implemented\r\n"); next }
            my @caps = ('250-fake greets you');
            push @caps, '250-STARTTLS'
                if $o->{tls} eq 'starttls' && !$tls_on && $mode ne 'no_starttls';
            push @caps, "250-SIZE " . ($mode eq 'size' ? 1000 : $o->{size});
            push @caps, "250-AUTH $o->{auth}" if $o->{auth};
            push @caps, '250 8BITMIME';
            $say->(join("\r\n", @caps) . "\r\n");
        }
        elsif ($line =~ /^HELO\b/i) { $say->("250 fake\r\n") }
        elsif ($line =~ /^STARTTLS/i) {
            if ($mode eq 'starttls_refused' || $tls_on) { $say->("454 4.7.0 TLS not available\r\n"); next }
            $say->("220 2.0.0 go ahead\r\n");
            my $up = IO::Socket::SSL->start_SSL($c, SSL_server => 1, SSL_reuse_ctx => $o->{ctx});
            if (!$up) { $log->("S: TLS handshake failed\n"); last }
            $tls_on = 1;
            $log->("S: TLS\n");
        }
        elsif ($line =~ /^AUTH PLAIN(?:\s+(\S+))?/i) {
            my $cred = $1;
            if (!defined $cred) { $say->("334 \r\n"); $cred = <$c>; $cred =~ s/\r?\n\z//; $log->("C: $cred\n") }
            if ($mode eq 'auth_fail') { $say->("535 5.7.8 Authentication credentials invalid\r\n") }
            else { $say->("235 2.7.0 Authentication successful\r\n") }
        }
        elsif ($line =~ /^AUTH LOGIN/i) {
            $say->("334 VXNlcm5hbWU6\r\n");
            my $u = <$c>; $u =~ s/\r?\n\z//; $log->("C: $u\n");
            $say->("334 UGFzc3dvcmQ6\r\n");
            my $p = <$c>; $p =~ s/\r?\n\z//; $log->("C: $p\n");
            if ($mode eq 'auth_fail') { $say->("535 5.7.8 Authentication credentials invalid\r\n") }
            else { $say->("235 2.7.0 Authentication successful\r\n") }
        }
        elsif ($line =~ /^MAIL FROM:/i) {
            ($size_param) = $line =~ /SIZE=(\d+)/i;
            $rcpt_n = 0;
            $say->("250 2.1.0 sender ok\r\n");
        }
        elsif ($line =~ /^RCPT TO:/i) {
            $rcpt_n++;
            if    ($mode eq 'tempfail_rcpt') { $say->("451 4.7.1 try again later\r\n") }
            elsif ($mode eq 'permfail_rcpt') { $say->("550 5.1.1 no such user\r\n") }
            elsif ($mode eq 'mixed_rcpt' && $rcpt_n > 1) { $say->("550 5.1.1 no such user\r\n") }
            else { $say->("250 2.1.5 recipient ok\r\n") }
        }
        elsif ($line =~ /^DATA/i) {
            $say->("354 go ahead\r\n");
            my $data = '';
            my $first = 1;
            while (defined(my $dl = <$c>)) {
                if ($mode eq 'drop_in_data' && $first) { $log->("S: dropped\n"); close $c; close $t; return }
                $first = 0;
                last if $dl eq ".\r\n";
                $data .= $dl;
            }
            $log->("DATA " . length($data) . "\n$data\nEND\n");
            if    ($mode eq 'tempfail_data') { $say->("451 4.3.0 try again later\r\n") }
            elsif ($mode eq 'permfail_data') { $say->("554 5.7.1 message refused\r\n") }
            elsif ($mode eq 'size' && length $data > 1000) { $say->("552 5.3.4 message too big\r\n") }
            else { $say->("250 2.0.0 queued as ABC123\r\n") }
        }
        elsif ($line =~ /^RSET/i) { $say->("250 2.0.0 ok\r\n") }
        elsif ($line =~ /^NOOP/i) { $say->("250 2.0.0 ok\r\n") }
        elsif ($line =~ /^QUIT/i) { $say->("221 2.0.0 bye\r\n"); last }
        else { $say->("502 5.5.2 command not implemented\r\n") }
    }
    close $c;
    close $t;
}

sub port { $_[0]{port} }

# the transcripts so far, oldest first: { commands => [...], data => $bytes }
sub transcripts {
    my ($self) = @_;
    my @out;
    for my $n (1 .. 1000) {
        my $f = "$self->{dir}/conn.$n";
        last unless -e $f;
        open my $fh, '<', $f or die $!;
        binmode $fh;
        local $/;
        my $raw = <$fh>;
        my %t = (commands => [], data => undef, tls => 0, dropped => 0);
        if ($raw =~ s/^DATA (\d+)\n(.*)\nEND\n//ms) { $t{data} = $2 }
        for my $l (split /\n/, $raw) {
            if    ($l =~ /^C: (.*)/) { push @{ $t{commands} }, $1 }
            elsif ($l eq 'S: TLS')   { $t{tls} = 1 }
            elsif ($l eq 'S: dropped') { $t{dropped} = 1 }
        }
        push @out, \%t;
    }
    return @out;
}

sub stop {
    my ($self) = @_;
    return unless $self->{pid};
    local $?;
    kill 'TERM', $self->{pid};
    select(undef, undef, undef, 0.05);
    kill 'KILL', $self->{pid};
    waitpid $self->{pid}, 0;
    $self->{pid} = 0;
}

sub DESTROY { local $?; $_[0]->stop }

1;
