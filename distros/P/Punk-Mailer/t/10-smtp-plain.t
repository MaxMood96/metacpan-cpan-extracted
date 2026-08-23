use strict;
use warnings;
use Test::More;
use lib 't/lib';
use FakeSMTPd;
use MIMERead;
BEGIN { do './t/sibling.pl' }
use Punk::Mailer;

# the smtp transport in plaintext: the conversation end to end, the
# bytes on the wire, dot-stuffing, per-recipient verdicts, HELO fallback.

plan skip_all => 'needs Fetch ABI 3 (the sibling Fetch 0.17 blib, or an installed one)'
    unless Punk::Mailer::_fetch_abi_version() >= 3;

sub smtp {
    my ($srv, %extra) = @_;
    return Punk::Mailer->new(transport => 'smtp', from => 'Ops <ops@example.com>',
        smtp => { host => '127.0.0.1', port => $srv->port, tls => 'none', timeout => 5, %extra });
}

my %msg = (to => 'Alice <a@example.com>', bcc => 'b@example.com', subject => 'over smtp',
           text => "line one\n.\nline after a lone dot\n..two dots\n");

# ---- the happy path ---------------------------------------------------------------
{
    my $srv = FakeSMTPd->new(mode => 'ok');
    my $m = smtp($srv);
    is($m->transport->name, 'smtp', 'the transport');
    is($m->transport->port, $srv->port, '  on the fake');
    is($m->transport->tls, 'none', '  plaintext');
    my $r = $m->send(\%msg);
    is($r->status, 'accepted', '250 after DATA is accepted') or diag $r->message;
    is($r->code, 250, '  code');
    is($r->enhanced, '2.0.0', '  enhanced status');
    like($r->message, qr/queued as ABC123/, '  the server text');
    like($r->id, qr/^<.*\@example\.com>\z/, '  the Message-ID as id');
    is_deeply([ sort keys %{ $r->recipients } ], [ 'a@example.com', 'b@example.com' ],
        '  every recipient has a verdict');
    is($r->recipients->{'b@example.com'}{code}, 250, '  250 each');
    $srv->stop;

    my ($t) = $srv->transcripts;
    my @c = @{ $t->{commands} };
    like($c[0], qr/^EHLO example\.com$/, 'EHLO with the From domain');
    like($c[1], qr/^MAIL FROM:<ops\@example\.com> SIZE=\d+$/,
        'MAIL FROM carries the envelope sender, and SIZE since the server offered it');
    is($c[2], 'RCPT TO:<a@example.com>', 'RCPT for to');
    is($c[3], 'RCPT TO:<b@example.com>', 'RCPT for bcc');
    is($c[4], 'DATA', 'DATA');
    is($c[5], 'QUIT', 'QUIT');

    my $wire = $t->{data};
    like($wire, qr/\r\n\.\.\r\n/, 'a lone dot went out stuffed');
    like($wire, qr/\r\n\.\.\.two dots\r\n/, 'a line starting with two dots gained a third');
    (my $unstuffed = $wire) =~ s/^\.\./\./mg;
    my $parsed = eval { MIMERead::parse($unstuffed) };
    ok($parsed, 'unstuffed, the bytes parse strictly') or diag $@;
    is($parsed->{body}, "line one\r\n.\r\nline after a lone dot\r\n..two dots\r\n",
        '  to the body that was given');
    unlike($wire, qr/(?<![\w.-])b\@example\.com/, '  with the bcc address nowhere in them');
    my ($size) = $c[1] =~ /SIZE=(\d+)/;
    is($size, length($unstuffed), 'SIZE was the unstuffed message size, computed before sending');
}

# ---- some recipients refused --------------------------------------------------
{
    my $srv = FakeSMTPd->new(mode => 'mixed_rcpt');
    my $r = smtp($srv)->send(\%msg);
    is($r->status, 'accepted', 'one accepted recipient is an accepted message');
    is($r->recipients->{'a@example.com'}{code}, 250, '  the first was taken');
    is($r->recipients->{'b@example.com'}{code}, 550, '  the second refused');
    like($r->recipients->{'b@example.com'}{message}, qr/5\.1\.1 no such user/, '  with its text');
}

# ---- a server that only speaks HELO ------------------------------------------------
{
    my $srv = FakeSMTPd->new(mode => 'helo_only');
    my $r = smtp($srv)->send(\%msg);
    is($r->status, 'accepted', 'HELO fallback delivers');
    $srv->stop;
    my ($t) = $srv->transcripts;
    is_deeply([ @{ $t->{commands} }[0, 1] ], [ 'EHLO example.com', 'HELO example.com' ],
        '  EHLO refused, HELO sent');
    unlike($t->{commands}[2], qr/SIZE/, '  and no SIZE, since HELO announces nothing');
}

# ---- the EHLO name ---------------------------------------------------------------
{
    my $srv = FakeSMTPd->new(mode => 'ok');
    smtp($srv, name => 'app.example.net')->send(\%msg);
    $srv->stop;
    my ($t) = $srv->transcripts;
    is($t->{commands}[0], 'EHLO app.example.net', 'name sets the EHLO name');
}

done_testing;
