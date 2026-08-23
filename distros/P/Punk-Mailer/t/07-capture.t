use strict;
use warnings;
use Test::More;
use File::Temp ();
use lib 't/lib';
use MIMERead;
BEGIN { do './t/sibling.pl' }
use Punk::Mailer;

# the capture transport: messages kept with bytes a strict reader
# accepts, dir writes one file per message, clear empties.

my %msg = (to => 'Alice <a@example.com>', bcc => 'b@example.com',
           subject => 'captured', text => "one\n", html => "<p>one</p>\n");

{
    my $m = Punk::Mailer->new(transport => 'capture', from => 'ops@example.com');
    my $r = $m->send(\%msg);
    my $cap = $m->transport;
    is(scalar @{ $cap->messages }, 1, 'one message captured');
    my $e = $cap->messages->[0];
    is_deeply([ sort keys %$e ], [ qw(bytes envelope result spec) ], 'the entry shape');
    is($e->{spec}{from}, 'ops@example.com', 'the spec, with defaults filled in');
    is_deeply($e->{envelope}, { from => 'ops@example.com',
                                to => [ 'a@example.com', 'b@example.com' ] }, 'the envelope');
    is($e->{result}->status, 'accepted', 'the result');
    my $parsed = eval { MIMERead::parse($e->{bytes}) };
    ok($parsed, 'the bytes parse strictly') or diag $@;
    is($parsed->{type}, 'multipart/alternative', '  as the alternative they are');
    unlike($e->{bytes}, qr/(?<![\w.-])b\@example\.com/, '  with no bcc in them');
    is($r->id, $parsed->{headers}{'message-id'}, 'the id is the Message-ID');

    $m->send(\%msg);
    is(scalar @{ $cap->messages }, 2, 'a second send appends');
    $cap->clear;
    is(scalar @{ $cap->messages }, 0, 'clear empties');
    is($cap->dir, undef, 'no dir was configured');
}

{
    my $dir = File::Temp->newdir;
    my $m = Punk::Mailer->new(transport => 'capture', from => 'ops@example.com',
                              capture => { dir => "$dir/mail" });
    $m->send(\%msg);
    $m->send(\%msg);
    ok(-d "$dir/mail/new", 'dir/new was created');
    my @files = sort glob("$dir/mail/new/*.eml");
    is(scalar @files, 2, 'one .eml per message');
    like($files[0], qr{/\d+\.1\.\d+\.eml\z}, 'named epoch.seq.pid.eml');
    like($files[1], qr{/\d+\.2\.\d+\.eml\z}, '  with the sequence counting');
    is($m->transport->last_path, $files[1], 'last_path names the newest');
    open my $fh, '<', $files[0] or die $!;
    binmode $fh;
    local $/;
    my $bytes = <$fh>;
    is($bytes, $m->transport->messages->[0]{bytes}, 'the file holds the captured bytes');
    ok(eval { MIMERead::parse($bytes) }, '  and they parse');
}

done_testing;
