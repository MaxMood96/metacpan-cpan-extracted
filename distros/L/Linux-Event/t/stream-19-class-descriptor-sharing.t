use v5.36;
use strict;
use warnings;
use Test::More;
use Scalar::Util qw(refaddr);
use Socket qw(AF_UNIX SOCK_STREAM PF_UNSPEC);

use Linux::Event::Loop;

{
    package T::SharedLineStream;
    use parent 'Linux::Event::Stream';
    use Linux::Event::Framer 'Delimiter', "\n";
    sub stream_options ($class) { return read_size => 2 }
    sub on_message ($stream, $message) {
        my $state = $stream->data;
        $state->{got} = $message;
    }
}

socketpair(my $sa, my $ca, AF_UNIX, SOCK_STREAM, PF_UNSPEC)
    or die "socketpair: $!";
socketpair(my $sb, my $cb, AF_UNIX, SOCK_STREAM, PF_UNSPEC)
    or die "socketpair: $!";
my $loop = Linux::Event::Loop->new;
my $state_a = { got => undef };
my $state_b = { got => undef };

my $a = T::SharedLineStream->new(loop => $loop, fh => $sa, data => $state_a);
my $b = T::SharedLineStream->new(loop => $loop, fh => $sb, data => $state_b);

is(refaddr($a->{descriptor}), refaddr($b->{descriptor}),
    'same subclass shares one Perl descriptor');
is(refaddr($a->{descriptor}{xs}), refaddr($b->{descriptor}{xs}),
    'same subclass shares one XS descriptor');
isnt(refaddr($a->{xs_state}), refaddr($b->{xs_state}),
    'connections retain independent mutable XS state');
is(refaddr($a->{descriptor}{callbacks}{on_message}),
    refaddr(\&T::SharedLineStream::on_message),
    'descriptor caches the named callback CV');

syswrite($ca, 'hel');
syswrite($cb, "world\n");
$loop->run_for(0.01);
is($state_a->{got}, undef, 'partial Stream A frame remains buffered');
is($state_b->{got}, 'world', 'Stream B parses independently');
syswrite($ca, "lo\n");
$loop->run_for(0.01);
is($state_a->{got}, 'hello', 'Stream A completes its own parser state');

$a->close;
$b->close;
close $ca;
close $cb;
done_testing;
