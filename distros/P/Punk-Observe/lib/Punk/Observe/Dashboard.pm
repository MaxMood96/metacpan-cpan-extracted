package Punk::Observe::Dashboard;

use 5.010;
use strict;
use warnings;

use Punk::Observe ();

our $VERSION = $Punk::Observe::VERSION;

1;

__END__

=head1 NAME

Punk::Observe::Dashboard - a panel is an OQL string with a title

=head1 SYNOPSIS

    use Punk::Observe::Dashboard;

    my $p = Punk::Observe::Dashboard::check_panel({
        title => 'Checkout latency',
        query => 'metric http.server.duration | p95 by http.route',
        viz   => 'line', position => 2, cols => 3,
    });
    die $p->{error} unless $p->{ok};

=head1 DESCRIPTION

A panel is a query string, a title, a visualisation hint and a position,
stored in the metadata database rather than in a segment: it is edited, and
segments are immutable.

Rendering reuses the same panels the explorer uses, so a chart on a dashboard
and the same chart in the explorer are the same code and cannot disagree. A
panel that is slow is slow in both places, which is the correct feedback.

=head2 The query is validated by the parser that will run it

Panel input is untrusted: it arrives from a form, renders into HTML, and its
query is parsed. So the query is checked at save time by the same parser that
executes it.

A panel validated by a different rule than the one that runs it is a panel
that can be saved and cannot be shown, and the person who finds out is a
reader at three in the morning rather than the author at the form.

=head2 Order is a number and layout is a column count

There is no drag-and-drop grid, and that is a deliberate subtraction. A drag
grid is several hundred lines of JavaScript, a collision algorithm, a mobile
story and a persistence format, in exchange for an arrangement most people
set once. A form with a number in it does the same job, works on a phone, and
is accessible without any work.

=head1 FUNCTIONS

=head2 check_panel

    my $p = Punk::Observe::Dashboard::check_panel(\%spec);

Takes C<title>, C<query>, C<viz>, C<position> and C<cols>. Returns:

    { ok, code, error, viz, position, cols }

C<error> carries the parser's own message where the query is at fault,
because "that query is wrong" is not a usable form error and the parser
already knows exactly what is wrong and where.

C<viz> is one of C<line>, C<area>, C<bar>, C<stat> or C<table>. An unknown
hint becomes C<table>, which shows the data; falling back to nothing would
hide it.

C<cols> is clamped to 1..6 and C<position> to zero or more. A title may
contain markup - the template escapes it, and refusing every angle bracket
would make C<< p95 < 200ms >> unsayable - but not control characters, which
have no legitimate use and reach places that are not HTML.

=head1 SEE ALSO

L<Punk::Observe>, L<Punk::Observe::Query>, L<Punk::Observe::Alert>

=cut
