package Fey::SQL::Union;

use strict;
use warnings;
use namespace::autoclean;

our $VERSION = '0.44';

use Moose 2.1200;

with 'Fey::Role::SetOperation' => { keyword => 'UNION' };

with 'Fey::Role::SQL::Cloneable';

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: Represents a UNION operation

__END__

=pod

=encoding UTF-8

=head1 NAME

Fey::SQL::Union - Represents a UNION operation

=head1 VERSION

version 0.44

=head1 SYNOPSIS

  my $union = Fey::SQL->new_union;

  $union->union( Fey::SQL->new_select->select(...),
                 Fey::SQL->new_select->select(...),
                 Fey::SQL->new_select->select(...),
                 ...
               );

  $union->order_by( $part_name, 'DESC' );
  $union->limit(10);

  print $union->sql($dbh);

=head1 DESCRIPTION

This class represents a UNION set operator.

=head1 METHODS

See L<Fey::Role::SetOperation> for all methods.

=head1 ROLES

=over 4

=item * L<Fey::Role::SetOperation>

=item * L<Fey::Role::SQL::Cloneable>

=back

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
