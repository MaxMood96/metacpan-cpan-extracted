package Markdent::Event::StartTableCell;

use strict;
use warnings;
use namespace::autoclean;

our $VERSION = '0.40';

use Markdent::Types;

use Moose;
use MooseX::StrictConstructor;

has alignment => (
    is       => 'ro',
    isa      => t('TableCellAlignment'),
    required => 1,
);

has colspan => (
    is       => 'ro',
    isa      => t('PositiveInt'),
    required => 1,
);

has is_header_cell => (
    is      => 'ro',
    isa     => t('Bool'),
    default => 0,
);

with 'Markdent::Role::Event' => { event_class => __PACKAGE__ };

__PACKAGE__->meta->make_immutable;

1;

# ABSTRACT: An event for the start of a table cell

__END__

=pod

=encoding UTF-8

=head1 NAME

Markdent::Event::StartTableCell - An event for the start of a table cell

=head1 VERSION

version 0.40

=head1 DESCRIPTION

This class represents the start of a table cell.

=head1 ATTRIBUTES

This class has the following attributes:

=head2 alignment

The alignment for the cell. This will be one of "left", "right", or "center".

=head2 colspan

The colspan for the cell. This will be a positive integer.

=head2 is_header_cell

A boolean indicating whether the cell is a header cell. This will be true for
all cells in the table's header, but can also be true for cells in the table's
body.

=head1 ROLES

This class does the L<Markdent::Role::Event> role.

=head1 BUGS

See L<Markdent> for bug reporting details.

Bugs may be submitted at L<https://github.com/houseabsolute/Markdent/issues>.

I am also usually active on IRC as 'autarch' on C<irc://irc.perl.org>.

=head1 SOURCE

The source code repository for Markdent can be found at L<https://github.com/houseabsolute/Markdent>.

=head1 AUTHOR

Dave Rolsky <autarch@urth.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2021 by Dave Rolsky.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

The full text of the license can be found in the
F<LICENSE> file included with this distribution.

=cut
