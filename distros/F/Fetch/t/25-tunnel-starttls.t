#!perl
use 5.008003;
use strict;
use warnings;
no warnings 'once';   # $IO::Socket::SSL::SSL_ERROR is referenced once
use IO::Socket::INET;
use File::Temp ();
use File::Spec ();
use Test::More;
use Fetch;

# fetch_abi v3: tunnel_starttls. A tunnel opened plain is upgraded to TLS
# after the application protocol says so - the SMTP STARTTLS shape.
#
# Perl cannot call into the function-pointer table, so the client side is
# the C selftest in ft_abi.h (Fetch::_abi_tunnel_starttls_probe): connect
# plain, read the greeting, send STARTTLS, upgrade only on a 220, then one
# line each way over TLS. The servers below are the other half, forked, one
# per mode:
#
#   refuse - 220, then 454 to STARTTLS and never upgrades. Plaintext only,
#            so it runs on every build and proves the probe does not upgrade
#            (or hang) on a refusal.
#   ok     - 220, then 220 to STARTTLS, then start_SSL, then answers PING.

my @pids;
END {
    local $?;   # waitpid sets it, and END's $? is the script's exit status
    for my $p (@pids) { kill 'TERM', $p; waitpid $p, 0 }
}

sub spawn {
    my (%o) = @_;
    my $srv = IO::Socket::INET->new(
        LocalHost => '127.0.0.1', LocalPort => 0, Listen => 8, ReuseAddr => 1,
    ) or plan skip_all => "cannot listen: $!";
    my $port = $srv->sockport;
    my $pid  = fork;
    plan skip_all => "cannot fork: $!" unless defined $pid;
    if (!$pid) {
        # Never hold the harness TAP pipe open, and never outlive the run:
        # a leaked server child hangs the whole suite after this test.
        open STDOUT, ">", File::Spec->devnull();
        open STDERR, ">", File::Spec->devnull();
        alarm 120;
        $SIG{TERM} = sub { exit 0 };
        # LibreSSL writes the TLS 1.3 server flight one record per write(2)
        # (OpenSSL flushes the whole flight in one), so when the client
        # refuses the certificate mid-flight the next handshake write lands
        # on a reset socket. Without this the SIGPIPE kills the fake, the
        # listener dies with it, and the NEXT probe finds its queued
        # connection reset before any greeting (OpenBSD smokers).
        $SIG{PIPE} = "IGNORE";
        while (my $c = $srv->accept) {
            $c->autoflush(1);
            print $c "220 fake\r\n";
            my $l = <$c>;
            if (!defined $l || $l !~ /^STARTTLS/i) { close $c; next }
            if ($o{mode} eq 'refuse') {
                print $c "454 no\r\n";
                close $c;
                next;
            }
            print $c "220 go\r\n";
            my $tls = IO::Socket::SSL->start_SSL($c,
                SSL_server    => 1,
                SSL_cert_file => $o{cert},
                SSL_key_file  => $o{key},
            );
            if (!$tls) { close $c; next }       # the client refused our cert
            my $ping = <$tls>;
            print $tls "250 PONG\r\n" if defined $ping && $ping =~ /^PING/;
            close $tls;
        }
        exit 0;
    }
    $srv->close;
    push @pids, $pid;
    select(undef, undef, undef, 0.2);
    return $port;
}

# ---- every build: the table entry and its NULL contract -----------------
cmp_ok(Fetch::_abi_version(), '>=', 3, 'the table reports ABI 3 or later');
is(Fetch::_abi_tunnel_starttls_null(), -1, 'tunnel_starttls(NULL) is -1');

# ---- every build: a server that declines STARTTLS ------------------------
{
    my $port = spawn(mode => 'refuse');
    my ($step, $text) = Fetch::_abi_tunnel_starttls_probe('127.0.0.1', $port, 0);
    is($step, 'refused', 'a 454 to STARTTLS stops the probe before upgrading');
    is($text, "220 fake\n454 no", 'greeting and refusal both read');
}

# ---- TLS builds: the upgrade itself --------------------------------------
SKIP: {
    skip 'Fetch built without OpenSSL', 5 unless Fetch::_tls_available();
    skip 'IO::Socket::SSL not installed', 5
        unless eval { require IO::Socket::SSL; 1 };

    my $dir  = File::Temp->newdir;
    my $cert = "$dir/cert.pem";
    my $key  = "$dir/key.pem";
    my $rc = system("openssl req -x509 -newkey rsa:2048 -keyout $key -out $cert "
                  . "-days 1 -nodes -subj /CN=localhost >/dev/null 2>&1");
    skip 'openssl(1) not available to make a test cert', 5 if $rc != 0;

    my $port = spawn(mode => 'ok', cert => $cert, key => $key);

    my ($step, $text) = Fetch::_abi_tunnel_starttls_probe('127.0.0.1', $port, 0);
    is($step, 'ok', 'plain greeting, STARTTLS, upgrade, then a line over TLS');
    is($text, "220 fake\n220 go\n250 PONG", 'all three server lines');

    # verify => 1 against a self-signed cert: the handshake is refused, and
    # the probe says so at the handshake step - nothing after it.
    ($step, $text) = Fetch::_abi_tunnel_starttls_probe('127.0.0.1', $port, 1);
    is($step, 'starttls', 'hostname/cert verification refuses the self-signed cert');
    is($text, "220 fake\n220 go", 'the conversation stopped at the upgrade');

    # and once more without verification, to show the server survived the
    # refused handshake and the fake is not single-shot
    ($step) = Fetch::_abi_tunnel_starttls_probe('127.0.0.1', $port, 0);
    is($step, 'ok', 'a second upgrade after a refused one');
}

done_testing;
