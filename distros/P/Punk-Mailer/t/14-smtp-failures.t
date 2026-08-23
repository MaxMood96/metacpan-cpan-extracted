use strict;
use warnings;
use Test::More;
use File::Temp ();
use Time::HiRes ();
use IO::Socket::INET;
use lib 't/lib';
use FakeSMTPd;
BEGIN { do './t/sibling.pl' }
use Punk::Mailer;

# every way an SMTP delivery does not end in 250, each as the documented
# Result: status, code, enhanced, and the phase in the message.

plan skip_all => 'needs Fetch ABI 3' unless Punk::Mailer::_fetch_abi_version() >= 3;

my %msg = (to => [ 'a@example.com', 'b@example.com' ], subject => 'f', text => "x\n");

sub smtp {
    my ($srv, %extra) = @_;
    my $port = ref $srv ? $srv->port : $srv;
    return Punk::Mailer->new(transport => 'smtp', from => 'ops@example.com',
        smtp => { host => '127.0.0.1', port => $port, tls => 'none', timeout => 5, %extra });
}

my %cases = (
    tempfail_rcpt => [ 'deferred', 451, '4.7.1', qr/every recipient was refused/ ],
    permfail_rcpt => [ 'rejected', 550, '5.1.1', qr/every recipient was refused/ ],
    tempfail_data => [ 'deferred', 451, '4.3.0', qr/^data: 451 try again later/ ],
    permfail_data => [ 'rejected', 554, '5.7.1', qr/^data: 554 message refused/ ],
);
for my $mode (sort keys %cases) {
    my ($status, $code, $enh, $re) = @{ $cases{$mode} };
    my $srv = FakeSMTPd->new(mode => $mode);
    my $r = smtp($srv)->send(\%msg);
    is($r->status, $status, "$mode: $status");
    is($r->code, $code, "  code $code");
    is($r->enhanced, $enh, "  enhanced $enh");
    like($r->message, $re, '  message');
    is(scalar keys %{ $r->recipients }, 2, '  both recipients have verdicts');
    $srv->stop;
    my ($t) = $srv->transcripts;
    if ($mode =~ /rcpt/) {
        ok(!defined $t->{data}, '  no DATA after every recipient was refused');
        ok(grep({ $_ eq 'RSET' } @{ $t->{commands} }), '  RSET was sent');
    }
}

# ---- the connection dies inside DATA ------------------------------------------------
{
    my $srv = FakeSMTPd->new(mode => 'drop_in_data');
    my $r = smtp($srv)->send({ %msg, text => ("x" x 100_000) . "\n" });
    is($r->status, 'failed', 'a connection dropped during DATA is failed');
    like($r->message, qr/during data/, '  naming the phase');
    ok($r->retryable, '  retryable');
    like($r->id, qr/^<.*>\z/, '  and the Message-ID is still known');
}

# ---- SIZE ----------------------------------------------------------------------------
{
    my $srv = FakeSMTPd->new(mode => 'size');
    my $r = smtp($srv)->send({ %msg, text => ("y" x 5000) . "\n" });
    is($r->status, 'rejected', 'over the announced SIZE is rejected locally');
    is($r->code, 552, '  with 552');
    is($r->enhanced, '5.3.4', '  and 5.3.4');
    like($r->message, qr/over the 1000-byte SIZE limit/, '  saying so');
    $srv->stop;
    my ($t) = $srv->transcripts;
    ok(!grep({ /^MAIL FROM/ } @{ $t->{commands} }), '  nothing was sent past EHLO');
    ok(!defined $t->{data}, '  and no DATA');

    my $dir = File::Temp->newdir;
    open my $fh, '>', "$dir/big" or die $!; print $fh 'z' x 4000; close $fh;
    $srv = FakeSMTPd->new(mode => 'size');
    $r = smtp($srv)->send({ %msg, attachments => [ { path => "$dir/big", filename => 'big' } ] });
    is($r->status, 'rejected', 'a path attachment counts toward SIZE without being read');
}

# ---- a server that never greets ---------------------------------------------------------
{
    my $srv = FakeSMTPd->new(mode => 'slow');
    my $t0 = Time::HiRes::time();
    my $r = smtp($srv, timeout => 1)->send(\%msg);
    my $took = Time::HiRes::time() - $t0;
    is($r->status, 'failed', 'no greeting within the timeout is failed');
    like($r->message, qr/timeout or connection lost during greeting/, '  naming the phase');
    cmp_ok($took, '<', 4, "  and it came back in ${\ sprintf '%.1f', $took}s, bounded by the timeout");
}

# ---- nobody listening -------------------------------------------------------------------
{
    my $s = IO::Socket::INET->new(LocalHost => '127.0.0.1', LocalPort => 0, Listen => 1);
    my $port = $s->sockport;
    $s->close;
    my $r = smtp($port)->send(\%msg);
    is($r->status, 'failed', 'a refused connection is failed');
    like($r->message, qr/cannot connect to 127\.0\.0\.1:$port/, '  naming the host and port');
    is($r->code, undef, '  no code');
    like($r->id, qr/^<.*>\z/, '  the Message-ID is known even so');
}

# ---- a large attachment streams to the socket ----------------------------------------
{
    my $rss = sub { my $o = `ps -o rss= -p $$ 2>/dev/null`; $o =~ /(\d+)/ ? $1 : undef };
    SKIP: {
        skip 'no ps -o rss', 3 unless defined $rss->();
        my $dir = File::Temp->newdir;
        my $size = 16 * 1024 * 1024;
        open my $fh, '>', "$dir/big.bin" or die $!;
        binmode $fh;
        my $chunk = join '', map { chr($_ & 255) } 0 .. 65535;
        print $fh $chunk for 1 .. $size / length $chunk;
        close $fh;
        # the fake's default SIZE is 10,000,000, and the local check would
        # refuse this message before sending - correctly, as the block above
        # shows - so this server announces room for it
        my $srv = FakeSMTPd->new(mode => 'ok', size => 100_000_000);
        my $m = smtp($srv);
        $m->send(\%msg);                      # warm
        my $before = $rss->();
        my $r = $m->send({ %msg, attachments => [ { path => "$dir/big.bin", filename => 'big.bin' } ] });
        my $after = $rss->();
        is($r->status, 'accepted', 'a 16 MiB attachment delivered') or diag $r->message;
        my $growth = ($after - $before) / 1024;
        diag sprintf 'RSS growth %.1f MiB', $growth;
        cmp_ok($growth, '<', 8, '  with flat RSS: it streamed');
        $srv->stop;
        my @t = $srv->transcripts;
        cmp_ok(length($t[1]{data}), '>', $size, '  and all of it arrived');
    }
}

done_testing;
