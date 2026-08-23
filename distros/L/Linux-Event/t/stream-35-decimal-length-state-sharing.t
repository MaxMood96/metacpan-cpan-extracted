use v5.36;
use strict;
use warnings;
use Test::More;
use Scalar::Util qw(refaddr);
use Socket qw(AF_UNIX SOCK_STREAM PF_UNSPEC);

use Linux::Event::Loop;

{
    package T::SharedDecimalStream;
    use parent 'Linux::Event::Stream';
    use Linux::Event::Framer 'DecimalLength';
    sub on_message ($stream, $message) {
        $stream->data->{got} = $message;
    }
}

socketpair(my $sx, my $cx, AF_UNIX, SOCK_STREAM, PF_UNSPEC)
    or die "socketpair: $!";
socketpair(my $sy, my $cy, AF_UNIX, SOCK_STREAM, PF_UNSPEC)
    or die "socketpair: $!";
my $loop = Linux::Event::Loop->new;
my ($state_x, $state_y) = ({}, {});
my $x = T::SharedDecimalStream->new(loop => $loop, fh => $sx, data => $state_x);
my $y = T::SharedDecimalStream->new(loop => $loop, fh => $sy, data => $state_y);

is(refaddr($x->{descriptor}), refaddr($y->{descriptor}),
    'DecimalLength instances share their immutable class descriptor');
syswrite($cx, '128');
syswrite($cy, '5 other');
$loop->run_for(0.01);
is($state_x->{got}, undef, 'Stream X retains a partial decimal prefix');
is($state_y->{got}, 'other', 'Stream Y parses independently');
syswrite($cx, ' ' . ('x' x 128));
$loop->run_for(0.01);
is($state_x->{got}, 'x' x 128,
    'Stream X completes its own DecimalLength state');

$x->close;
$y->close;
close $cx;
close $cy;
done_testing;
