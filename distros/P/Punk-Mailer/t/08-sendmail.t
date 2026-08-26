use strict;
use warnings;
use Test::More;
use File::Temp ();
use lib 't/lib';
use MIMERead;
BEGIN { do './t/sibling.pl' }
use Punk::Mailer;

# the sendmail transport: an argv list run without a shell, -f and the
# envelope recipients appended, the message streamed into its stdin, and
# the exit status as a Result.

my $dir  = File::Temp->newdir;
my $file = "$dir/out";
my %msg  = (to => 'Alice <a@example.com>', cc => 'c@example.com', bcc => 'b@example.com',
            subject => 'piped', text => "line one\n.\nline after a dot\n");

{
    my $m = Punk::Mailer->new(transport => 'sendmail', from => 'Ops <ops@example.com>',
                              sendmail => { command => [ $^X, 't/bin/sink.pl', $file ] });
    is_deeply($m->transport->command, [ $^X, 't/bin/sink.pl', $file ], 'the command as given');
    my $r = $m->send(\%msg);
    is($r->status, 'accepted', 'exit 0 is accepted') or diag $r->message;
    is($r->code, undef, '  with no code');
    is($r->transport, 'sendmail', '  from sendmail');
    like($r->id, qr/^<.*\@example\.com>\z/, '  and the Message-ID as id');

    open my $fh, '<', "$file.argv" or die $!;
    my @argv = map { chomp; $_ } <$fh>;
    close $fh;
    is_deeply(\@argv, [ '-f', 'ops@example.com', 'a@example.com', 'c@example.com', 'b@example.com' ],
        '-f sender then every envelope recipient, bcc included');

    open $fh, '<', $file or die $!;
    binmode $fh;
    local $/;
    my $bytes = <$fh>;
    close $fh;
    my $parsed = eval { MIMERead::parse($bytes) };
    ok($parsed, 'what reached stdin parses strictly') or diag $@;
    is($parsed->{body}, "line one\r\n.\r\nline after a dot\r\n",
        'the body went through as is - no dot-stuffing for an MTA');
    unlike($bytes, qr/(?<![\w.-])b\@example\.com/, 'bcc is in the envelope, not the headers');
}

{
    my $m = Punk::Mailer->new(transport => 'sendmail', from => 'ops@example.com',
                              sendmail => { command => [ 'false' ] });
    my $r = $m->send(\%msg);
    is($r->status, 'failed', 'a non-zero exit is failed');
    is($r->code, 1, '  carrying the exit status');
    like($r->message, qr/false exited 1/, '  and saying so');
    ok($r->retryable, '  retryable');
}

{
    my $m = Punk::Mailer->new(transport => 'sendmail', from => 'ops@example.com',
                              sendmail => { command => [ $^X, '-e', 'exit 3' ] });
    is($m->send(\%msg)->code, 3, 'the exit status comes through');
}

{
    # a body too big for the pipe buffer, so the write is certain to hit
    # EPIPE - the exit status still has to win, or the exec failure comes
    # back as a broken pipe with no code
    my $m = Punk::Mailer->new(transport => 'sendmail', from => 'ops@example.com',
                              sendmail => { command => [ "$dir/no-such-command" ] });
    my $r = $m->send({ %msg, text => ('x' x 200_000) . "\n" });
    is($r->status, 'failed', 'a command that cannot run is failed');
    is($r->code, 127, '  with 127');
    like($r->message, qr/not found or not executable/, '  and the hint');
}

{
    # a command that both stops reading and exits non-zero: the status wins
    my $m = Punk::Mailer->new(transport => 'sendmail', from => 'ops@example.com',
                              sendmail => { command => [ $^X, '-e', 'close STDIN; exit 3' ] });
    my $r = $m->send({ %msg, text => ('x' x 200_000) . "\n" });
    is($r->code, 3, 'the exit status beats the broken pipe');
    like($r->message, qr/exited 3/, '  and the message says so');
}

{
    # the command stops reading early: not a dead worker, a failed Result
    my $m = Punk::Mailer->new(transport => 'sendmail', from => 'ops@example.com',
                              sendmail => { command => [ $^X, '-e', 'close STDIN; exit 0' ] });
    my $big = { %msg, text => ('x' x 200_000) . "\n" };
    my $r = $m->send($big);
    ok(defined $r, 'a closed pipe came back as a Result');
    ok($r->failed || $r->accepted, '  (failed, or accepted if the pipe buffered it all)');
}

{
    ok(!eval { Punk::Mailer->new(transport => 'sendmail', sendmail => { command => '/usr/sbin/sendmail -t' }); 1 },
        'a string command croaks at new');
    like($@, qr/a list of arguments, not a shell string/, '  and says why');
    ok(!eval { Punk::Mailer->new(transport => 'sendmail', sendmail => { command => [] }); 1 },
        'an empty command croaks');
    my $m = Punk::Mailer->new(transport => 'sendmail', from => 'ops@example.com');
    is_deeply($m->transport->command, [ '/usr/sbin/sendmail', '-i' ], 'the default command, with -i');
}

done_testing;
