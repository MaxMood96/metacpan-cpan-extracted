use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Temp ();
use lib 't/lib';
use FakeSMTPd;
BEGIN { do './t/sibling.pl' }
use Punk::Mailer;

# STARTTLS: the upgrade, the second EHLO, and the refusals that must not
# become a plaintext session.

plan skip_all => 'needs Fetch ABI 3' unless Punk::Mailer::_fetch_abi_version() >= 3;
plan skip_all => 'Fetch built without OpenSSL' unless eval { require Fetch; Fetch::_tls_available() };
plan skip_all => 'IO::Socket::SSL not installed' unless eval { require IO::Socket::SSL; 1 };

my $dir  = File::Temp->newdir;
my ($cert, $key) = ("$dir/cert.pem", "$dir/key.pem");
my $rc = system("openssl req -x509 -newkey rsa:2048 -keyout $key -out $cert "
              . "-days 1 -nodes -subj /CN=localhost >/dev/null 2>&1");
plan skip_all => 'openssl(1) not available to make a test cert' if $rc != 0;

sub smtp {
    my ($srv, %extra) = @_;
    return Punk::Mailer->new(transport => 'smtp', from => 'ops@example.com',
        smtp => { host => '127.0.0.1', port => $srv->port, tls => 'starttls',
                  verify => 0, timeout => 5, %extra });
}
my %msg = (to => 'a@example.com', subject => 'tls', text => "secret\n");

# ---- the upgrade ---------------------------------------------------------------
{
    my $srv = FakeSMTPd->new(mode => 'ok', tls => 'starttls', cert => $cert, key => $key);
    my $m = smtp($srv);
    is($m->transport->port, $srv->port, 'port as given');
    my $r = $m->send(\%msg);
    is($r->status, 'accepted', 'delivered over STARTTLS') or diag $r->message;
    $srv->stop;
    my ($t) = $srv->transcripts;
    ok($t->{tls}, 'the server saw the handshake');
    my @ehlo = grep { /^EHLO/ } @{ $t->{commands} };
    is(scalar @ehlo, 2, 'EHLO twice: before and after the upgrade');
    is($t->{commands}[1], 'STARTTLS', 'STARTTLS after the first EHLO');
    like($t->{data}, qr/secret/, 'the message arrived');
}

# ---- the server does not offer it ----------------------------------------------------
{
    my $srv = FakeSMTPd->new(mode => 'no_starttls', tls => 'starttls', cert => $cert, key => $key);
    my $r = smtp($srv)->send(\%msg);
    is($r->status, 'failed', 'no STARTTLS capability is failed');
    like($r->message, qr/does not offer STARTTLS/, '  and says so');
    $srv->stop;
    my ($t) = $srv->transcripts;
    is_deeply($t->{commands}, [ 'EHLO example.com', 'QUIT' ], '  nothing was sent in plaintext');
    ok(!defined $t->{data}, '  no DATA');
}

# ---- the server declines it ----------------------------------------------------------
{
    my $srv = FakeSMTPd->new(mode => 'starttls_refused', tls => 'starttls', cert => $cert, key => $key);
    my $r = smtp($srv)->send(\%msg);
    is($r->status, 'deferred', 'a 454 to STARTTLS is deferred, as the code says');
    is($r->code, 454, '  code');
    like($r->message, qr/^starttls: 454/, '  naming the phase');
    $srv->stop;
    my ($t) = $srv->transcripts;
    ok(!defined $t->{data}, '  and nothing was sent in plaintext');
}

# ---- verification against a self-signed certificate ------------------------------------
{
    my $srv = FakeSMTPd->new(mode => 'ok', tls => 'starttls', cert => $cert, key => $key);
    my $r = smtp($srv, verify => 1)->send(\%msg);
    is($r->status, 'failed', 'verify => 1 refuses the self-signed cert');
    like($r->message, qr/TLS handshake .* failed .*verification/, '  at the handshake');

    # and the server is still there for a client that does not verify
    $r = smtp($srv)->send(\%msg);
    is($r->status, 'accepted', 'a second connection after the refused one delivers');
}

done_testing;
