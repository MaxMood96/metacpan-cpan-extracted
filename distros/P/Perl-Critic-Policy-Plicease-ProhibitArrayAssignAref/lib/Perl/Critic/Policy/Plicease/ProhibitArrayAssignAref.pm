# Copyright 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2019, 2021 Kevin Ryde

# Perl-Critic-Policy-Plicease-ProhibitArrayAssignAref is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by the
# Free Software Foundation; either version 3, or (at your option) any later
# version.
#
# Perl-Critic-Policy-Plicease-ProhibitArrayAssignAref is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License along
# with Perl-Critic-Policy-Plicease-ProhibitArrayAssignAref.  If not, see <http://www.gnu.org/licenses/>.


# eg.
# perlcritic -s ProhibitArrayAssignAref /usr/lib/perl5/Template/Test.pm


package Perl::Critic::Policy::Plicease::ProhibitArrayAssignAref;

use 5.006;
use strict;
use warnings;
use base 'Perl::Critic::Policy';
use Perl::Critic::Utils;

# uncomment this to run the ### lines
#use Smart::Comments;

# ABSTRACT: Don't assign an anonymous arrayref to an array
our $VERSION = '100.00'; # VERSION

use constant supported_parameters => ();
use constant default_severity     => $Perl::Critic::Utils::SEVERITY_MEDIUM;
use constant default_themes       => ();
use constant applies_to           => ('PPI::Token::Symbol',
                                      'PPI::Token::Cast');

sub violates {
  my ($self, $elem, $document) = @_;

  ($elem->isa('PPI::Token::Cast') ? $elem->content : $elem->raw_type)
    eq '@' or return;
  ### ProhibitArrayAssignAref: $elem->content

  my $thing = 'Array';
  for (;;) {
    $elem = $elem->snext_sibling || return;
    last if $elem->isa('PPI::Token::Operator');
    ### skip: ref $elem

    # @foo[1,2] gives the [1,2] as a PPI::Structure::Subscript
    # @{foo()}[1,2] gives the [1,2] as a PPI::Structure::Constructor
    # the latter is probably wrong (as of PPI 1.215)
    if ($elem->isa('PPI::Structure::Subscript')
       || $elem->isa('PPI::Structure::Constructor')) {
      if ($elem->start eq '[') {
        $thing = 'Array slice';
      } elsif ($elem->start eq '{') {
        $thing = 'Hash slice';
      }
    }
  }
  ### $thing
  ### operator: $elem->content
  $elem eq '=' or return;

  $elem = $elem->snext_sibling || return;
  ($elem->isa('PPI::Structure::Constructor') && $elem->start eq '[')
    or return;

  return $self->violation
    ("$thing assigned a [] arrayref, should it be a () list ?",
     '', $elem);
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Perl::Critic::Policy::Plicease::ProhibitArrayAssignAref - Don't assign an anonymous arrayref to an array

=head1 VERSION

version 100.00

=head1 DESCRIPTION

This policy is a fork of L<Perl::Critic::Policy::ValuesAndExpressions::ProhibitArrayAssignAref>.
It differs from the original by not having a dependency on L<List::MoreUtils>.
It is unfortunately still licensed as GPL3.

It asks you not to assign an anonymous arrayref to an array

    @array = [ 1, 2, 3 ];       # bad

The idea is that it's rather unclear whether an arrayref is intended, or
might have meant to be a list like

    @array = ( 1, 2, 3 );

This policy is under the "bugs" theme (see L<Perl::Critic/POLICY THEMES>)
for the chance C<[]> is a mistake, and since even if it's correct it will
likely make anyone reading it wonder.

A single arrayref can still be assigned to an array, but with parens to make
it clear,

    @array = ( [1,2,3] );       # ok

Dereferences or array and hash slices (see L<perldata/Slices>) are
recognised as an array target and treated similarly,

    @$ref = [1,2,3];            # bad assign to deref
    @{$ref} = [1,2,3];          # bad assign to deref
    @x[1,2,3] = ['a','b','c'];  # bad assign to array slice
    @x{'a','b'} = [1,2];        # bad assign to hash slice

=head2 List Assignment Parens

This policy is not a blanket requirement for C<()> parens on array
assignments.  It's normal and unambiguous to have a function call or C<grep>
etc without parens.

    @array = foo();                    # ok
    @array = grep {/\.txt$/} @array;   # ok

The only likely problem from lack of parens in such cases is that the C<,>
comma operator has lower precedence than C<=> (see L<perlop>), so something
like

    @array = 1,2,3;   # oops, not a list

means

    @array = (1);
    2;
    3;

Normally the remaining literals in void context provoke a warning from Perl
itself.

An intentional single element assignment is quite common as a statement, for
instance

    @ISA = 'My::Parent::Class';   # ok

And for reference the range operator precedence is high enough,

    @array = 1..10;               # ok

But of course parens are needed if concatenating some disjoint ranges with
the comma operator,

    @array = (1..5, 10..15);      # parens needed

The C<qw> form gives a list too

    @array = qw(a b c);           # ok

=head1 SEE ALSO

=over 4

=item L<Perl::Critic>

=item L<Perl::Critic::Policy::ValuesAndExpressions::ProhibitArrayAssignAref>

=back

=head1 HOME PAGE

=over 4

=item L<https://github.com/uperl/Perl-Critic-Policy-Plicease-ProhibitArrayAssignAref>

=back

=head1 COPYRIGHT

Copyright 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2019, 2021 Kevin Ryde

Perl-Critic-Policy-Plicease-ProhibitArrayAssignAref is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation; either version 3, or (at your option) any later
version.

Perl-Critic-Policy-Plicease-ProhibitArrayAssignAref is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
more details.

You should have received a copy of the GNU General Public License along with
Perl-Critic-Policy-Plicease-ProhibitArrayAssignAref.  If not, see <http://www.gnu.org/licenses>.

=head1 AUTHOR

Original author: Kevin Ryde

Current maintainer: Graham Ollis E<lt>plicease@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2011-2021 by Kevin Ryde.

This is free software, licensed under:

  The GNU General Public License, Version 3, June 2007

=cut
