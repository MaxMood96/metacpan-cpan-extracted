package Punk::Observe::Flame;

use 5.010;
use strict;
use warnings;

use Punk::Observe ();

our $VERSION = $Punk::Observe::VERSION;

1;

__END__

=head1 NAME

Punk::Observe::Flame - aggregated self-time across traces

=head1 SYNOPSIS

    use Punk::Observe::Flame;

    my $f = Punk::Observe::Flame::build(\@spans);
    for my $frame (@{ $f->{frames} }) {
        printf "%*s%d  self %s of %s\n", $frame->{depth} * 2, '',
            $frame->{name}, $frame->{self}, $frame->{total};
    }

=head1 DESCRIPTION

A waterfall shows one trace. A flame graph shows a thousand: the same call
paths merged, so what stands out is where the time actually goes rather than
where it went once.

Frames are keyed by (service, name, path), so the same operation reached by two
different call paths is two frames. Merging them would answer "how slow is this
function" and hide "it is only slow when the checkout path calls it", which is
the question worth asking.

=head2 Self time, not total

C<self> is a frame's duration minus the time its children were running.
C<total> is the whole span. Summing C<total> over a tree counts the same
nanosecond once per level, so a chart built on it says the root is 100% of
everything and tells nobody anything.

C<total_self> across the whole graph is therefore the real denominator.

Traces are folded one at a time, the way the compactor does it, so a partial
trace contributes what it has rather than being held back.

=head1 FUNCTIONS

=head2 build

    my $f = Punk::Observe::Flame::build(\@spans);

Builds the aggregated tree from span specs. The span spec is the one in
L<Punk::Observe::Trace/THE SPAN SPEC>; C<name> and C<service> are symbol
numbers.

    {
      frames => [ { name, service, parent, depth, total, self, count }, ... ],
      total_self => '4200000000',
    }

C<parent> is an index into C<frames>, or -1 for a root. C<depth> is the nesting
level. C<count> is how many spans folded into the frame, which is what
distinguishes one very slow call from ten thousand ordinary ones.

Frames come out in tree order, so a parent always precedes its children.

=head1 SEE ALSO

L<Punk::Observe>, L<Punk::Observe::Trace>, L<Punk::Observe::SVG>

=cut
