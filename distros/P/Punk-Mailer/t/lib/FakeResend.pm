package FakeResend;

use strict;
use warnings;
use IO::Socket::INET;
use File::Spec ();
use File::Temp ();
use POSIX ();

# A Resend-shaped HTTP/1.1 listener, so t/09 runs on a box with no network
# and no API key. One server, five behaviours chosen by the request path:
#
#   /ok     200 {"id":"..."}          /rate   429 {"message":"..."}
#   /bad    422 {"message":"..."}     /down   500 {"message":"..."}
#   /drop   close the connection without answering
#
# Every request is written whole - request line, headers, body - to
# <dir>/req.N, which the test reads after stop(). Never through a pipe
# the parent shares with the TAP stream: the child sends STDOUT and
# STDERR to devnull, alarms, and _exits.

sub new {
    my ($class, %o) = @_;
    my $dir = File::Temp->newdir;
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
        syswrite $wr, "1";      # ready
        close $wr;
        my $n = 0;
        while (my $c = $srv->accept) {
            $c->autoflush(1);
            my $req = '';
            my $line = <$c>;
            last unless defined $line;
            $req .= $line;
            my ($path) = $line =~ m{^\S+\s+(\S+)};
            my %h;
            while (my $hl = <$c>) {
                $req .= $hl;
                last if $hl eq "\r\n";
                $h{lc $1} = $2 if $hl =~ /^([^:]+):\s*(.*?)\r\n\z/;
            }
            my $body = '';
            if (my $len = $h{'content-length'}) {
                while (length $body < $len) {
                    my $got = read($c, $body, $len - length $body, length $body);
                    last unless $got;
                }
            }
            $req .= $body;
            $n++;
            if (open my $fh, '>', "$dir/req.$n") { binmode $fh; print $fh $req; close $fh }

            my ($code, $text, $out);
            if    ($path =~ m{^/ok})   { ($code, $text, $out) = (200, 'OK', '{"id":"49a3999c-0ce1-4ea6-ab68-afcd6dc2e794"}') }
            elsif ($path =~ m{^/rate}) { ($code, $text, $out) = (429, 'Too Many Requests', '{"statusCode":429,"message":"Too many requests. You can only make 2 requests per second.","name":"rate_limit_exceeded"}') }
            elsif ($path =~ m{^/bad})  { ($code, $text, $out) = (422, 'Unprocessable Entity', '{"statusCode":422,"message":"Invalid `to` field. The email address needs to follow the `email@example.com` or `Name <email@example.com>` format.","name":"validation_error"}') }
            elsif ($path =~ m{^/down}) { ($code, $text, $out) = (500, 'Internal Server Error', '{"message":"boom é \"quoted\""}') }
            elsif ($path =~ m{^/drop}) { close $c; next }
            else                       { ($code, $text, $out) = (404, 'Not Found', '{"message":"not found"}') }
            print $c "HTTP/1.1 $code $text\r\nContent-Type: application/json\r\n"
                   . "Content-Length: " . length($out) . "\r\nConnection: close\r\n\r\n$out";
            close $c;
        }
        POSIX::_exit(0);
    }
    close $wr;
    sysread $rd, my $ready, 1;
    close $rd;
    $srv->close;
    return bless { pid => $pid, port => $port, dir => $dir }, $class;
}

sub port { $_[0]{port} }
sub url  { my ($self, $path) = @_; "http://127.0.0.1:$self->{port}$path" }

# the requests seen so far, oldest first, each as { line, headers, body }
sub requests {
    my ($self) = @_;
    my @out;
    for my $n (1 .. 1000) {
        my $f = "$self->{dir}/req.$n";
        last unless -e $f;
        open my $fh, '<', $f or die $!;
        binmode $fh;
        local $/;
        my $raw = <$fh>;
        my ($head, $body) = split /\r\n\r\n/, $raw, 2;
        my ($line, @hl) = split /\r\n/, $head;
        my %h = map { /^([^:]+):\s*(.*)\z/ ? (lc $1, $2) : () } @hl;
        push @out, { line => $line, headers => \%h, body => $body // '' };
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
