use v5.36;
use strict;
use warnings;
use Test::More;
use Socket qw(AF_UNIX SOCK_STREAM PF_UNSPEC);

use Linux::Event::Loop;

{
    package T::RawU32Protocol;
    use parent 'Linux::Event::IO::Sock::Stream';
    sub on_data ($stream, $bytes) {
        my $state = $stream->data;
        $state->{buffer} .= $bytes;
        while (length($state->{buffer}) >= 4) {
            my $length = unpack('N', substr($state->{buffer}, 0, 4));
            die 'frame too large' if $length > 1024;
            last if length($state->{buffer}) < 4 + $length;
            substr($state->{buffer}, 0, 4, '');
            push @{ $state->{messages} }, substr($state->{buffer}, 0, $length, '');
        }
        $state->{loop}->stop if @{ $state->{messages} } == 2;
    }
}

socketpair(my $a, my $b, AF_UNIX, SOCK_STREAM, PF_UNSPEC)
    or die "socketpair: $!";
my $loop = Linux::Event::Loop->new;
my $state = { loop => $loop, buffer => '', messages => [] };
my $stream = T::RawU32Protocol->new(loop => $loop, fh => $a, data => $state);

my $wire = pack('N', 5) . 'first' . pack('N', 6) . 'second';
syswrite($b, substr($wire, 0, 3));
$loop->run_once(0);
is_deeply($state->{messages}, [], 'raw parser retains a partial header');
syswrite($b, substr($wire, 3));
$loop->run;
is_deeply($state->{messages}, [qw(first second)],
    'on_data can implement an application-specific framing rule');
is($state->{buffer}, '', 'raw parser consumed complete frames');
$stream->close;
close $b;
done_testing;
