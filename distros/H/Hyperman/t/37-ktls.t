#!perl
use strict;
use warnings;
use lib "t/lib";
use Test::More;
use HMTest qw(free_ports quiet_child);
use Time::HiRes ();
use File::Temp ();
use Hyperman;

# Kernel TLS.
#
# After the handshake, the record layer moves into the kernel and the socket
# itself encrypts - which is what lets an HTTPS response take the writev and
# sendfile fast paths that were plaintext-only. It needs three things to line
# up: an OpenSSL built with enable-ktls, a kernel with the tls ULP
# (Linux 4.13+ with CONFIG_TLS, or FreeBSD), and a negotiated cipher the
# kernel can offload. Any of them can say no.
#
# THE POINT OF THIS FILE is that it passes either way. kTLS not engaging is a
# supported outcome, not a failure - most boxes will be in that state - so
# what is asserted is that HTTPS is CORRECT regardless, and the diagnostics
# say which path actually ran. A server that quietly failed to offload looks
# exactly like one that did, so without SSL_KTLS in the env there is no way to
# tell, and this feature could be silently dead for a year.
#
# The kTLS-engaged path was written without a kernel that could run it. When
# you have one, this is the file that tells you whether it works: it prints
# `ktls=1` and then asserts the same bytes come back.

plan skip_all => 'OpenSSL support not built' unless Hyperman->has_tls;
my $openssl = `which openssl`; chomp $openssl;
plan skip_all => 'openssl CLI not found' unless $openssl;
my $curl = `which curl`; chomp $curl;
plan skip_all => 'curl not found' unless $curl;

diag "Hyperman->has_ktls = " . (Hyperman->has_ktls ? 1 : 0)
   . " (build capability; engaging is decided per connection)";

my $dir  = File::Temp::tempdir(CLEANUP => 1);
my $cert = "$dir/cert.pem";
my $key  = "$dir/key.pem";
system(qq{openssl req -x509 -newkey rsa:2048 -nodes -keyout "$key" -out "$cert" }
     . qq{-days 1 -subj "/CN=localhost" >/dev/null 2>&1});
plan skip_all => 'could not create self-signed cert'
    unless -s $cert && -s $key;

# A body big enough to cross more than one TLS record (a record maxes at
# 16KB), because the interesting bug in a gather-write path is at the record
# boundary, not in the first few bytes.
my $BIG = join '', map { sprintf "%06d-abcdefghijklmnopqrstuvwxyz\n", $_ } 1 .. 3000;

# A file to serve, so the sendfile half of kTLS is exercised too and not just
# the writev half.
my $file = "$dir/big.txt";
{ open my $fh, '>', $file or die $!; print {$fh} $BIG; close $fh }

my ($port) = free_ports(1);
plan skip_all => "no free loopback port" unless $port;

my $pid = fork;
die "fork: $!" unless defined $pid;
if ($pid == 0) {
    quiet_child();
    Hyperman->run(
        app => sub {
            my $env = shift;
            my $p = $env->{PATH_INFO};
            if ($p eq '/ktls') {
                # what actually happened on THIS connection
                return [ 200, [ 'Content-Type' => 'text/plain' ],
                         [ ($env->{SSL_KTLS} // 'missing') . " $env->{SSL_PROTOCOL}" ] ];
            }
            if ($p eq '/big') {
                return [ 200, [ 'Content-Type' => 'text/plain' ], [ $BIG ] ];
            }
            if ($p eq '/file') {
                open my $fh, '<', $file or return [ 500, [], ['no file'] ];
                return [ 200, [ 'Content-Type' => 'text/plain' ], $fh ];
            }
            return [ 404, [ 'Content-Type' => 'text/plain' ], ['nope'] ];
        },
        host => '127.0.0.1', port => $port, workers => 1,
        tls_cert => $cert, tls_key => $key,
    );
    exit 0;
}

# wait for the listener
my $up = 0;
for (1 .. 100) {
    my $r = `$curl -sk --max-time 2 https://127.0.0.1:$port/ktls 2>/dev/null`;
    if (defined $r && length $r) { $up = 1; last }
    Time::HiRes::sleep(0.05);
}

SKIP: {
    skip 'TLS server did not come up', 5 unless $up;

    my $probe = `$curl -sk --max-time 5 https://127.0.0.1:$port/ktls 2>/dev/null`;
    my ($ktls, $proto) = split ' ', ($probe // '');
    $ktls  = 'missing' unless defined $ktls;
    $proto = '?'       unless defined $proto;

    isnt($ktls, 'missing',
         'SSL_KTLS is reported in $env - without it kTLS cannot be observed');
    like($ktls, qr/^[01]$/, 'SSL_KTLS is 0 or 1');

    diag "kTLS ENGAGED on this box (SSL_KTLS=1, $proto)" if $ktls eq '1';
    diag "kTLS did NOT engage (SSL_KTLS=0, $proto) - "
       . "expected unless the kernel has the tls ULP" if $ktls eq '0';

    # The assertions that matter either way: whichever write path ran, the
    # bytes must be right. Under kTLS these go out through writev and
    # sendfile with the kernel encrypting; without it, through SSL_write.
    my $big = `$curl -sk --max-time 10 https://127.0.0.1:$port/big 2>/dev/null`;
    is(length($big // ''), length($BIG),
       'a multi-record body comes back with exactly the right length');
    ok(defined $big && $big eq $BIG,
       '...and byte-for-byte identical - the gather-write path is correct');

    my $fh = `$curl -sk --max-time 10 https://127.0.0.1:$port/file 2>/dev/null`;
    ok(defined $fh && $fh eq $BIG,
       'a filehandle body is correct too - the sendfile path under TLS');
}

kill 'TERM', $pid;
waitpid $pid, 0;

done_testing;
