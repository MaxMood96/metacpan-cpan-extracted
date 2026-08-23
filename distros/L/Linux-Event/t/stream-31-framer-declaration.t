use v5.36;
use strict;
use warnings;
use Test::More;
use Socket qw(AF_UNIX SOCK_STREAM PF_UNSPEC);

use Linux::Event::Loop;

BEGIN {
    package Linux::Event::Framer::ProbeNative;
    sub _build_definition ($class, @args) {
        die 'ProbeNative takes no arguments' if @args;
        return {
            native => { read_mode => 3, fixed_size => 2 },
            frame => sub ($config, $payload) {
                $payload = '' if !defined $payload;
                die 'ProbeNative payload must be two bytes' if length($payload) != 2;
                return $payload;
            },
        };
    }
    $INC{'Linux/Event/Framer/ProbeNative.pm'} = __FILE__;
}

{
    package T::ProbeNativeStream;
    use parent 'Linux::Event::Stream';
    use Linux::Event::Framer 'ProbeNative';
    sub on_message ($stream, $message) {
        $stream->data->{got} = $message;
        $stream->data->{loop}->stop;
    }
}

socketpair(my $a, my $b, AF_UNIX, SOCK_STREAM, PF_UNSPEC)
    or die "socketpair: $!";
my $loop = Linux::Event::Loop->new;
my $state = { loop => $loop };
my $stream = T::ProbeNativeStream->new(loop => $loop, fh => $a, data => $state);

is($stream->{descriptor}{framer}{package},
    'Linux::Event::Framer::ProbeNative',
    'declaration derives the implementation package from the exact name');
is($stream->{descriptor}{native}{read_mode}, 3,
    'dynamically loaded declaration contributes native parser configuration');

syswrite($b, 'OK');
$loop->run;
is($state->{got}, 'OK', 'dynamically named declaration uses native parser mode');
ok($stream->send('GO'), 'declaration supplies outbound framing');
my $wire = '';
is(sysread($b, $wire, 2), 2, 'peer reads outbound ProbeNative frame');
is($wire, 'GO', 'outbound declaration callback is used');

$stream->close;
close $b;
done_testing;
