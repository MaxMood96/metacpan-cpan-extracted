use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Temp ();
use lib 't/lib';
use FakeSMTPd;
BEGIN { do './t/sibling.pl' }
use Punk::Mailer;

# implicit TLS: the whole session inside TLS from the first byte.

plan skip_all => 'needs Fetch ABI 3' unless Punk::Mailer::_fetch_abi_version() >= 3;
plan skip_all => 'Fetch built without OpenSSL' unless eval { require Fetch; Fetch::_tls_available() };
plan skip_all => 'IO::Socket::SSL not installed' unless eval { require IO::Socket::SSL; 1 };

my $dir  = File::Temp->newdir;
my ($cert, $key) = ("$dir/cert.pem", "$dir/key.pem");
my $rc = system("openssl req -x509 -newkey rsa:2048 -keyout $key -out $cert "
              . "-days 1 -nodes -subj /CN=localhost >/dev/null 2>&1");
plan skip_all => 'openssl(1) not available to make a test cert' if $rc != 0;

my $srv = eval { FakeSMTPd->new(mode => 'ok', tls => 'implicit', cert => $cert, key => $key) }
    or plan skip_all => "cannot start a TLS listener: $@";

my %msg = (to => 'a@example.com', subject => 'implicit', text => "inside tls\n");

{
    my $m = Punk::Mailer->new(transport => 'smtp', from => 'ops@example.com',
        smtp => { host => '127.0.0.1', port => $srv->port, tls => 'implicit', verify => 0, timeout => 5 });
    is($m->transport->tls, 'implicit', 'tls implicit');
    my $r = $m->send(\%msg);
    is($r->status, 'accepted', 'delivered over implicit TLS') or diag $r->message;
    like($r->message, qr/queued as/, '  with the queue id');
}

{
    my $m = Punk::Mailer->new(transport => 'smtp', from => 'ops@example.com',
        smtp => { host => '127.0.0.1', port => $srv->port, tls => 'implicit', verify => 1, timeout => 5 });
    my $r = $m->send(\%msg);
    is($r->status, 'failed', 'verify => 1 refuses the self-signed cert');
    like($r->message, qr/cannot connect|handshake/, '  at connect, where implicit TLS handshakes');
}

{
    # a plaintext client against the TLS port: no greeting arrives, the
    # timeout is the verdict. The two refused handshakes above did not
    # end the listener (it upgrades per connection), so this is a connect
    # that succeeds and a greeting that never comes, not a refused connect
    my $m = Punk::Mailer->new(transport => 'smtp', from => 'ops@example.com',
        smtp => { host => '127.0.0.1', port => $srv->port, tls => 'none', timeout => 1 });
    my $r = $m->send(\%msg);
    is($r->status, 'failed', 'plaintext against a TLS port fails');
    like($r->message, qr/during greeting/, '  at the greeting');
}

{
    # the listener outlived the two refused handshakes: a third delivery
    # still goes through
    my $m = Punk::Mailer->new(transport => 'smtp', from => 'ops@example.com',
        smtp => { host => '127.0.0.1', port => $srv->port, tls => 'implicit', verify => 0, timeout => 5 });
    my $r = $m->send(\%msg);
    is($r->status, 'accepted', 'the listener outlived the refused handshakes') or diag $r->message;
}

$srv->stop;
my @t = $srv->transcripts;
ok(scalar @t >= 1, 'the server kept transcripts');
like($t[0]{data} // '', qr/inside tls/, 'the first delivery arrived');
like($t[-1]{data} // '', qr/inside tls/, '  and the last');

done_testing;
