use v5.36;
use strict;
use warnings;
use Test::More;
use Socket qw(AF_UNIX SOCK_STREAM PF_UNSPEC);

use Linux::Event::Loop;

{
    package T::IncludedDelimiterStream;
    use parent 'Linux::Event::Stream';
    use Linux::Event::Framer 'Delimiter', '<X>', include_delimiter => 1;
    sub on_message ($stream, $message) {
        $stream->data->{got} = $message;
        $stream->data->{loop}->stop;
    }
}

{
    package T::BangParentStream;
    use parent 'Linux::Event::Stream';
    use Linux::Event::Framer 'Delimiter', '!';
    sub on_message ($stream, $message) {
        $stream->data->{got} = "parent:$message";
        $stream->data->{loop}->stop;
    }
}

{
    package T::BangChildStream;
    use parent -norequire, 'T::BangParentStream';
    sub on_message ($stream, $message) {
        $stream->data->{got} = "child:$message";
        $stream->data->{loop}->stop;
    }
}

socketpair(my $a, my $b, AF_UNIX, SOCK_STREAM, PF_UNSPEC)
    or die "socketpair: $!";
my $loop = Linux::Event::Loop->new;
my $state = { loop => $loop };
my $stream = T::IncludedDelimiterStream->new(
    loop => $loop, fh => $a, data => $state,
);
syswrite($b, 'abc<X>');
$loop->run;
is($state->{got}, 'abc<X>', 'native delimiter honors include_delimiter');
$stream->close;
close $b;

socketpair(my $c, my $d, AF_UNIX, SOCK_STREAM, PF_UNSPEC)
    or die "socketpair: $!";
my $loop2 = Linux::Event::Loop->new;
my $child_state = { loop => $loop2 };
my $child = T::BangChildStream->new(
    loop => $loop2, fh => $c, data => $child_state,
);
syswrite($d, 'inherited!');
$loop2->run;
is($child_state->{got}, 'child:inherited',
    'derived Stream inherits framing and overrides a named callback');
is($child->{descriptor}{framer}{package},
    'Linux::Event::Framer::Delimiter',
    'descriptor resolves inherited framer declaration');
$child->close;
close $d;

done_testing;
