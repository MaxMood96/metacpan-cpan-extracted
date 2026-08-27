package Punk::Observe::Map;

use 5.010;
use strict;
use warnings;

use Punk::Observe ();

our $VERSION = $Punk::Observe::VERSION;

1;

__END__

=head1 NAME

Punk::Observe::Map - laying out the service graph

=head1 SYNOPSIS

    use Punk::Observe::Map;

    my $m = Punk::Observe::Map::layout([
        { caller => '*', callee => 1, count => 600, errors => 0 },
        { caller => 1,   callee => 2, count => 600, errors => 4 },
    ]);

    for my $n (@{ $m->{nodes} }) {
        printf "service %s at layer %d slot %d\n",
            $n->{service}, $n->{layer}, $n->{slot};
    }

=head1 DESCRIPTION

Turns the accumulated service graph into positions: a layer per node and a slot
within it. Callers sit left of callees, so traffic reads in one direction.

The graph itself is built when a segment is sealed rather than per query. See
L<Punk::Observe::Trace/The service graph is accumulated at seal>.

=head2 Cycles are drawn, not refused

Real service graphs have cycles - two services that call each other, or a
retry path that loops back. A layering algorithm needs an acyclic graph, so the
edges that would close a cycle are identified and reported as B<back edges>
rather than being dropped.

They are still edges and still drawn. Removing them would hide exactly the
relationship somebody is looking at the map to find.

=head1 FUNCTIONS

=head2 layout

    my $m = Punk::Observe::Map::layout(\@edges);

Lays out a graph. Each edge is a hashref taking C<caller>, C<callee>, C<count>
and C<errors>. Services are symbol numbers; the string C<*> as a caller means
the synthetic root, which is where traffic from something uninstrumented
arrives.

Edges repeating the same pair are summed rather than duplicated.

    {
      nodes  => [ { service, layer, slot, in, out, errors }, ... ],
      layers => 3,
      back_edges => 1,
      back   => [ 2 ],
    }

C<service> is the symbol number, or C<*> for the synthetic root. C<layer> is
the horizontal position and C<slot> the vertical one within it. C<in> and
C<out> are call counts through the node, and C<errors> the errors attributed
to it.

C<back> holds indexes into the B<edge list as the layout saw it>, which is the
deduplicated graph rather than the arrayref that was passed in.

=head1 SEE ALSO

L<Punk::Observe>, L<Punk::Observe::Trace>, L<Punk::Observe::SVG>

=cut
