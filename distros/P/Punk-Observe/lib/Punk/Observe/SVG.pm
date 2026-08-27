package Punk::Observe::SVG;

use 5.010;
use strict;
use warnings;

use Punk::Observe ();

our $VERSION = $Punk::Observe::VERSION;

1;

__END__

=head1 NAME

Punk::Observe::SVG - chart primitives

=head1 SYNOPSIS

    use Punk::Observe::SVG;

    my $axis = Punk::Observe::SVG::axis(0, 970, 5);
    print "@{ $axis->{ticks} }\n";        # 0 200 400 600 800 1000

    my $d = Punk::Observe::SVG::line([ 0, 1, 2 ], [ 5, 9, 7 ], 640, 200);
    print qq{<path d="$d"/>};

=head1 DESCRIPTION

The pieces a chart is drawn from: a number formatter, an attribute escaper, an
axis that picks round ticks, and a path builder.

These draw the waterfall, the flamegraph and the service map, which are laid
out here and arrive complete in the HTML - a trace waterfall that exists only
after a script runs does not exist in a saved page or an email to a colleague.

Charts are the exception and go to a plotting library in the browser: a line
over a hundred thousand points is a different problem from a waterfall of
forty bars. See L<Punk::Observe::Plot>.

=head1 FUNCTIONS

=head2 fmt

    my $str = Punk::Observe::SVG::fmt($number);

Formats a number for display: no trailing zeros, no exponent where one is
avoidable, and the same output on every perl.

It does not go through a Perl-flavoured formatter. C<%f> in one of those reads
an NV, so a double passed to it is undefined behaviour - the quadmath smokers
panic and x86_64 reads silent garbage.

=head2 esc_attr

    my $safe = Punk::Observe::SVG::esc_attr($text);

Escapes a string for an XML attribute. Output is truncated at the internal
buffer size, so a long service name is cut rather than overflowing.

Every string reaching an attribute goes through this. A service name is
attacker-influenced in exactly the way a request path is, and a chart that
renders one unescaped is an injection.

=head2 axis

    my $a = Punk::Observe::SVG::axis($min, $max, $wanted_ticks);

Chooses round tick values covering the range.

    { ticks => [ '0', '200', '400' ], lo => 0, hi => 400, step => 200, n => 3 }

C<ticks> are already formatted. C<lo> and C<hi> are the range the axis actually
covers, which is the given range widened to round numbers, and C<n> is the tick
count, which is near C<$wanted_ticks> rather than equal to it. Round numbers
beat exactly the requested count: an axis labelled 0, 193, 386 is unreadable.

=head2 line

    my $d = Punk::Observe::SVG::line(\@xs, \@ys, $width, $height);

Builds the C<d> attribute of a path, scaling the data to fit a C<$width> by
C<$height> box. The extents are taken from the data. Returns the path data
only, so the caller owns the styling.

=head1 SEE ALSO

L<Punk::Observe>, L<Punk::Observe::Map>, L<Punk::Observe::Flame>

=cut
