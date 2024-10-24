#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2021-2024 -- leonerd@leonerd.org.uk

package Syntax::Operator::Equ 0.10;

use v5.14;
use warnings;

use Carp;

use meta 0.003_002;
no warnings 'meta::experimental';

require XSLoader;
XSLoader::load( __PACKAGE__, our $VERSION );

=head1 NAME

C<Syntax::Operator::Equ> - equality operators that distinguish C<undef>

=head1 SYNOPSIS

On Perl v5.38 or later:

   use v5.38;
   use Syntax::Operator::Equ;

   if($x equ $y) {
      say "x and y are both undef, or both defined and equal strings";
   }

   if($i === $j) {
      say "i and j are both undef, or both defined and equal numbers";
   }

Or via L<Syntax::Keyword::Match> on Perl v5.14 or later:

   use v5.14;
   use Syntax::Keyword::Match;
   use Syntax::Operator::Equ;

   match($str : equ) {
      case(undef) { say "The variable is not defined" }
      case("")    { say "The variable is defined but is empty" }
      default     { say "The string is non-empty" }
   }

=head1 DESCRIPTION

This module provides infix operators that implement equality tests of strings
or numbers similar to perl's C<eq> and C<==> operators, except that they
consider C<undef> to be a distinct value, separate from the empty string or
the number zero.

These operators do not warn when either or both operands are C<undef>. They
yield true if both operands are C<undef>, false if exactly one operand is, or
otherwise behave the same as the regular string or number equality tests if
both operands are defined.

Support for custom infix operators was added in the Perl 5.37.x development
cycle and is available from development release v5.37.7 onwards, and therefore
in Perl v5.38 onwards. The documentation of L<XS::Parse::Infix>
describes the situation in more detail.

While Perl versions before this do not support custom infix operators, they
can still be used via C<XS::Parse::Infix> and hence L<XS::Parse::Keyword>.
Custom keywords which attempt to parse operator syntax may be able to use
these. One such module is L<Syntax::Keyword::Match>; see the SYNOPSIS example
given above.

=cut

sub import
{
   my $pkg = shift;
   my $caller = caller;

   $pkg->import_into( $caller, @_ );
}

sub unimport
{
   my $pkg = shift;
   my $caller = caller;

   $pkg->unimport_into( $caller, @_ );
}

sub import_into   { shift->apply( 1, @_ ) }
sub unimport_into { shift->apply( 0, @_ ) }

sub apply
{
   my $pkg = shift;
   my ( $on, $caller, @syms ) = @_;

   @syms or @syms = qw( equ === );

   $pkg->XS::Parse::Infix::apply_infix( $on, \@syms, qw( equ === ) );

   my %syms = map { $_ => 1 } @syms;
   my $callerpkg;

   foreach (qw( is_strequ is_numequ )) {
      next unless delete $syms{$_};

      $callerpkg //= meta::package->get( $caller );

      $on ? $callerpkg->add_symbol( '&'.$_ => \&{$_} )
          : $callerpkg->remove_symbol( '&'.$_ );
   }

   croak "Unrecognised import symbols @{[ keys %syms ]}" if keys %syms;
}

=head1 OPERATORS

=head2 equ

   my $equal = $lhs equ $rhs;

Yields true if both operands are C<undef>, or if both are defined and contain
equal string values. Yields false if given exactly one C<undef>, or two
unequal strings.

=head2 ===

   my $equal = $lhs === $rhs;

Yields true if both operands are C<undef>, or if both are defined and contain
equal numerical values. Yields false if given exactly one C<undef>, or two
unequal numbers.

Note that while this operator will not cause warnings about uninitialized
values, it can still warn if given defined stringy values that are not valid
as numbers.

=cut

=head1 FUNCTIONS

As a convenience, the following functions may be imported which implement the
same behaviour as the infix operators, though are accessed via regular
function call syntax.

These wrapper functions are implemented using L<XS::Parse::Infix>, and thus
have an optimising call-checker attached to them. In most cases, code which
calls them should not in fact have the full runtime overhead of a function
call because the underlying test operator will get inlined into the calling
code at compiletime. In effect, code calling these functions should run with
the same performance as code using the infix operators directly.

=head2 is_strequ

   my $equal = is_strequ( $lhs, $rhs );

A function version of the L</equ> stringy operator.

=head2 is_numequ

   my $equal = is_numequ( $lhs, $rgh );

A function version of the L</===> numerical operator.

=cut

=head1 SEE ALSO

=over 4

=item *

L<Syntax::Operator::Eqr> - string equality and regexp match operator

=back

=head1 AUTHOR

Paul Evans <leonerd@leonerd.org.uk>

=cut

0x55AA;
