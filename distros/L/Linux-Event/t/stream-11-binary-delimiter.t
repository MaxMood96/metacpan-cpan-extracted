use v5.36;
use strict;
use warnings;
use Test::More;
use Socket qw(AF_UNIX SOCK_STREAM PF_UNSPEC);

use Linux::Event::Loop;
use Linux::Event::Stream;

{
    package T::BinaryDelimiterStream;
    use parent 'Linux::Event::Stream';
    use Linux::Event::Framer 'Delimiter', "\x02\xffEND\x00\x03";
    sub on_message ($stream, $message) {
        my $state = $stream->data;
        push @{ $state->{messages} }, $message;
        $state->{loop}->stop if @{ $state->{messages} } == 2;
    }
}

socketpair(my $a, my $b, AF_UNIX, SOCK_STREAM, PF_UNSPEC) or die "socketpair: $!";
my $loop = Linux::Event::Loop->new;
my $delimiter = "\x02\xffEND\x00\x03";
my $state = { loop => $loop, messages => [] };

my $stream = T::BinaryDelimiterStream->new(
    loop => $loop,
    fh   => $a,
    data => $state,
);

my $wire = "alpha${delimiter}beta${delimiter}";
my $cut = index($wire, $delimiter) + 3;
syswrite($b, substr($wire, 0, $cut));
$loop->run_once(0);
is(scalar @{ $state->{messages} }, 0, 'binary delimiter may be split across reads');

syswrite($b, substr($wire, $cut));
$loop->run;
is_deeply($state->{messages}, ['alpha', 'beta'], 'arbitrary binary delimiter frames messages correctly');

$stream->close;
done_testing;
