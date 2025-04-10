package Fey::SQL::Fragment::Where::Boolean;

use strict;
use warnings;
use namespace::autoclean;

our $VERSION = '0.44';

use Fey::Types qw( WhereBoolean );

use Moose 2.1200;

has 'comparison' => (
    is       => 'ro',
    isa      => WhereBoolean,
    required => 1,
);

sub sql {
    return $_[0]->comparison();
}

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: Represents an AND or OR in a WHERE clause

__END__

=pod

=encoding UTF-8

=head1 NAME

Fey::SQL::Fragment::Where::Boolean - Represents an AND or OR in a WHERE clause

=head1 VERSION

version 0.44

=head1 DESCRIPTION

This class represents a subselect an AND or OR in a WHERE clause.

It is intended solely for internal use in L<Fey::SQL> objects, and as
such is not intended for public use.

=head1 BUGS

See L<Fey> for details on how to report bugs.

Bugs may be submitted at L<https://github.com/ap/Fey/issues>.

=head1 SOURCE

The source code repository for Fey can be found at L<https://github.com/ap/Fey>.

=head1 AUTHOR

Dave Rolsky <autarch@urth.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2011 - 2025 by Dave Rolsky.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

The full text of the license can be found in the
F<LICENSE> file included with this distribution.

=cut
