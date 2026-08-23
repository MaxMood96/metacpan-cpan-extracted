use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Temp ();
use MIME::Base64 ();
use lib 't/lib';
use FakeSMTPd;
BEGIN { do './t/sibling.pl' }
use Punk::Mailer;

# AUTH: PLAIN when offered, LOGIN otherwise, the 535, and the rule that a
# password never crosses plaintext unless the configuration says so.

plan skip_all => 'needs Fetch ABI 3' unless Punk::Mailer::_fetch_abi_version() >= 3;

my %msg = (to => 'a@example.com', subject => 'auth', text => "hello\n");

sub plain {
    my ($srv, %extra) = @_;
    return Punk::Mailer->new(transport => 'smtp', from => 'ops@example.com',
        smtp => { host => '127.0.0.1', port => $srv->port, tls => 'none', timeout => 5,
                  username => 'user@example.com', password => 'pa ss/w0rd',
                  insecure_auth => 1, %extra });
}

# ---- the rule, at new -----------------------------------------------------------
{
    ok(!eval { Punk::Mailer->new(transport => 'smtp', smtp => {
        host => 'h', tls => 'none', username => 'u', password => 'p' }); 1 },
        'a password over plaintext croaks at new');
    like($@, qr/will not send a password over plaintext/, '  and says why');
    ok(!eval { Punk::Mailer->new(transport => 'smtp', smtp => { host => 'h', username => 'u' }); 1 },
        'a username without a password croaks');
    ok(!eval { Punk::Mailer->new(transport => 'smtp', smtp => { host => 'h', tls => 'sometimes' }); 1 },
        'an unknown tls word croaks');
    ok(!eval { Punk::Mailer->new(transport => 'smtp', smtp => { tls => 'none' }); 1 },
        'no host croaks');
    ok(!eval { Punk::Mailer->new(transport => 'smtp', smtp => { host => 'h', port => 'x' }); 1 },
        'a non-numeric port croaks');
    ok(!eval { Punk::Mailer->new(transport => 'smtp', smtp => { host => 'h', hots => 1 }); 1 },
        'an unknown option croaks');
    my $m = Punk::Mailer->new(transport => 'smtp', smtp => { host => 'h' });
    is($m->transport->port, 587, 'the default port for starttls');
    is($m->transport->tls, 'starttls', '  which is the default tls');
    is($m->transport->verify, 1, '  verification on');
    is($m->transport->timeout, 15, '  fifteen seconds');
    is(Punk::Mailer->new(transport => 'smtp', smtp => { host => 'h', tls => 'implicit' })->transport->port, 465,
        'the default port for implicit');
    is(Punk::Mailer->new(transport => 'smtp', smtp => { host => 'h', tls => 'none' })->transport->port, 25,
        'the default port for plaintext');
    ok(!$m->transport->can('password'), 'the password has no accessor');
}

# ---- PLAIN ---------------------------------------------------------------------------
{
    my $srv = FakeSMTPd->new(mode => 'ok');
    my $r = plain($srv)->send(\%msg);
    is($r->status, 'accepted', 'authenticated and delivered') or diag $r->message;
    $srv->stop;
    my ($t) = $srv->transcripts;
    my ($auth) = grep { /^AUTH/ } @{ $t->{commands} };
    like($auth, qr/^AUTH PLAIN \S+$/, 'AUTH PLAIN in one line, since the server offered PLAIN');
    my ($b64) = $auth =~ /^AUTH PLAIN (\S+)/;
    is(MIME::Base64::decode_base64($b64), "\0user\@example.com\0pa ss/w0rd",
        '  NUL user NUL password, base64');
    is($t->{commands}[1], $auth, '  straight after EHLO');
}

# ---- LOGIN, when that is all there is --------------------------------------------------
{
    my $srv = FakeSMTPd->new(mode => 'ok', auth => 'LOGIN');
    my $r = plain($srv)->send(\%msg);
    is($r->status, 'accepted', 'LOGIN delivers') or diag $r->message;
    $srv->stop;
    my ($t) = $srv->transcripts;
    my @c = @{ $t->{commands} };
    is($c[1], 'AUTH LOGIN', 'AUTH LOGIN');
    is(MIME::Base64::decode_base64($c[2]), 'user@example.com', '  then the username');
    is(MIME::Base64::decode_base64($c[3]), 'pa ss/w0rd', '  then the password');
}

# ---- no mechanism in common ---------------------------------------------------------
{
    my $srv = FakeSMTPd->new(mode => 'ok', auth => 'CRAM-MD5 XOAUTH2');
    my $r = plain($srv)->send(\%msg);
    is($r->status, 'failed', 'a server offering neither PLAIN nor LOGIN is failed');
    like($r->message, qr/no AUTH mechanism this client speaks/, '  and says so');
    my $none = FakeSMTPd->new(mode => 'ok', auth => '');
    is(plain($none)->send(\%msg)->status, 'failed', 'a server offering no AUTH at all, too');
}

# ---- refused credentials -----------------------------------------------------------
{
    my $srv = FakeSMTPd->new(mode => 'auth_fail');
    my $r = plain($srv)->send(\%msg);
    is($r->status, 'rejected', 'a 535 is rejected');
    is($r->code, 535, '  code');
    is($r->enhanced, '5.7.8', '  enhanced');
    like($r->message, qr/^auth: 535 Authentication credentials invalid/, '  phase and text');
    unlike($r->message, qr/pa ss|w0rd/, '  and the password is not in it');
    $srv->stop;
    my ($t) = $srv->transcripts;
    ok(!grep({ /^MAIL FROM/ } @{ $t->{commands} }), '  nothing was sent after the refusal');
}

done_testing;
