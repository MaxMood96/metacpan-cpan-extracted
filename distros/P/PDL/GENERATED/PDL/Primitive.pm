#
# GENERATED WITH PDL::PP from lib/PDL/Primitive.pd! Don't modify!
#
package PDL::Primitive;

our @EXPORT_OK = qw(inner outer matmult innerwt inner2 inner2d inner2t crossp norm indadd conv1d in uniq uniqind uniqvec hclip lclip clip wtstat statsover stats histogram whistogram histogram2d whistogram2d fibonacci append axisvalues cmpvec eqvec enumvec enumvecg vsearchvec unionvec intersectvec setdiffvec union_sorted intersect_sorted setdiff_sorted vcos srandom random randsym grandom vsearch vsearch_sample vsearch_insert_leftmost vsearch_insert_rightmost vsearch_match vsearch_bin_inclusive vsearch_bin_exclusive interpolate interpol interpND one2nd which which_both whichover approx_artol where where_both whereND whereND_both whichND whichND_both setops intersect pchip_chim pchip_chic pchip_chsp pchip_chfd pchip_chfe pchip_chia pchip_chid pchip_chbs pchip_bvalu );
our %EXPORT_TAGS = (Func=>\@EXPORT_OK);

use PDL::Core;
use PDL::Exporter;
use DynaLoader;


   
   our @ISA = ( 'PDL::Exporter','DynaLoader' );
   push @PDL::Core::PP, __PACKAGE__;
   bootstrap PDL::Primitive ;

{ package # hide from MetaCPAN
 PDL;

#line 1440 "lib/PDL/PP.pm"
{
  my ($foo, $overload_sub);
  use overload 'x' => $overload_sub = sub {
    Carp::confess("PDL::matmult: overloaded 'x' given undef")
      if grep !defined, @_[0,1];
    return PDL::matmult(@_) unless ref $_[1]
            && (ref $_[1] ne 'PDL')
            && defined($foo = overload::Method($_[1], 'x'))
            && $foo != $overload_sub; # recursion guard
    goto &$foo;
  };
}
#line 36 "lib/PDL/Primitive.pm"
}







#line 12 "lib/PDL/Primitive.pd"

use strict;
use warnings;
use PDL::Slices;
use Carp;

=head1 NAME

PDL::Primitive - primitive operations for pdl

=head1 DESCRIPTION

This module provides some primitive and useful functions defined
using PDL::PP and able to use the new indexing tricks.

See L<PDL::Indexing> for how to use indices creatively.
For explanation of the signature format, see L<PDL::PP>.

=head1 SYNOPSIS

 # Pulls in PDL::Primitive, among other modules.
 use PDL;

 # Only pull in PDL::Primitive:
 use PDL::Primitive;

=cut
#line 73 "lib/PDL/Primitive.pm"


=head1 FUNCTIONS

=cut






=head2 inner

=for sig

 Signature: (a(n); b(n); [o]c())
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble cfloat cdouble cldouble)

=for usage

 $c = inner($a, $b);
 inner($a, $b, $c);  # all arguments given
 $c = $a->inner($b); # method call
 $a->inner($b, $c);

=for ref

Inner product over one dimension

 c = sum_i a_i * b_i

See also L</norm>, L<PDL::Ufunc/magnover>.

=pod

Broadcasts over its inputs.

=for bad

If C<a() * b()> contains only bad data,
C<c()> is set bad. Otherwise C<c()> will have its bad flag cleared,
as it will not contain any bad values.

=cut




*inner = \&PDL::inner;






=head2 outer

=for sig

 Signature: (a(n); b(m); [o]c(n,m))
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble cfloat cdouble cldouble)

=for usage

 $c = outer($a, $b);
 outer($a, $b, $c);  # all arguments given
 $c = $a->outer($b); # method call
 $a->outer($b, $c);

=for ref

outer product over one dimension

Naturally, it is possible to achieve the effects of outer
product simply by broadcasting over the "C<*>"
operator but this function is provided for convenience.

=pod

Broadcasts over its inputs.

=for bad

C<outer> processes bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*outer = \&PDL::outer;





#line 98 "lib/PDL/Primitive.pd"

=head2 x

=for sig

 Signature: (a(i,z), b(x,i),[o]c(x,z))

=for ref

Matrix multiplication

PDL overloads the C<x> operator (normally the repeat operator) for
matrix multiplication.  The number of columns (size of the 0
dimension) in the left-hand argument must normally equal the number of
rows (size of the 1 dimension) in the right-hand argument.

Row vectors are represented as (N x 1) two-dimensional PDLs, or you
may be sloppy and use a one-dimensional PDL.  Column vectors are
represented as (1 x N) two-dimensional PDLs.

Broadcasting occurs in the usual way, but as both the 0 and 1 dimension
(if present) are included in the operation, you must be sure that
you don't try to broadcast over either of those dims.

Of note, due to how Perl v5.14.0 and above implement operator overloading of
the C<x> operator, the use of parentheses for the left operand creates a list
context, that is

 pdl> ( $x * $y ) x $z
 ERROR: Argument "..." isn't numeric in repeat (x) ...

treats C<$z> as a numeric count for the list repeat operation and does not call
the scalar form of the overloaded operator. To use the operator in this case,
use a scalar context:

 pdl> scalar( $x * $y ) x $z

or by calling L</matmult> directly:

 pdl> ( $x * $y )->matmult( $z )

EXAMPLES

Here are some simple ways to define vectors and matrices:

 pdl> $r = pdl(1,2);                # A row vector
 pdl> $c = pdl([[3],[4]]);          # A column vector
 pdl> $c = pdl(3,4)->(*1);          # A column vector, using NiceSlice
 pdl> $m = pdl([[1,2],[3,4]]);      # A 2x2 matrix

Now that we have a few objects prepared, here is how to
matrix-multiply them:

 pdl> print $r x $m                 # row x matrix = row
 [
  [ 7 10]
 ]

 pdl> print $m x $r                 # matrix x row = ERROR
 PDL: Dim mismatch in matmult of [2x2] x [2x1]: 2 != 1

 pdl> print $m x $c                 # matrix x column = column
 [
  [ 5]
  [11]
 ]

 pdl> print $m x 2                  # Trivial case: scalar mult.
 [
  [2 4]
  [6 8]
 ]

 pdl> print $r x $c                 # row x column = scalar
 [
  [11]
 ]

 pdl> print $c x $r                 # column x row = matrix
 [
  [3 6]
  [4 8]
 ]

INTERNALS

The mechanics of the multiplication are carried out by the
L</matmult> method.

=cut
#line 264 "lib/PDL/Primitive.pm"


=head2 matmult

=for sig

 Signature: (a(t,h); b(w,t); [o]c(w,h))
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble cfloat cdouble cldouble)

=for usage

 $c = x $a, $b;        # overloads the Perl 'x' operator
 $c = matmult($a, $b);
 matmult($a, $b, $c);  # all arguments given
 $c = $a->matmult($b); # method call
 $a->matmult($b, $c);

=for ref

Matrix multiplication

Notionally, matrix multiplication $x x $y is equivalent to the
broadcasting expression

    $x->dummy(1)->inner($y->xchg(0,1)->dummy(2),$c);

but for large matrices that breaks CPU cache and is slow.  Instead,
matmult calculates its result in 32x32x32 tiles, to keep the memory
footprint within cache as long as possible on most modern CPUs.

For usage, see L</x>, a description of the overloaded 'x' operator

=pod

Broadcasts over its inputs.

=for bad

C<matmult> processes bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut





#line 197 "lib/PDL/Primitive.pd"
sub PDL::matmult {
    my ($x,$y,$c) = @_;
    $y = PDL->topdl($y);
    $c = PDL->null if !UNIVERSAL::isa($c, 'PDL');
    while($x->getndims < 2) {$x = $x->dummy(-1)}
    while($y->getndims < 2) {$y = $y->dummy(-1)}
    return ($c .= $x * $y) if( ($x->dim(0)==1 && $x->dim(1)==1) ||
                               ($y->dim(0)==1 && $y->dim(1)==1) );
    barf sprintf 'Dim mismatch in matmult of [%1$dx%2$d] x [%3$dx%4$d]: %1$d != %4$d',$x->dim(0),$x->dim(1),$y->dim(0),$y->dim(1)
      if $y->dim(1) != $x->dim(0);
    PDL::_matmult_int($x,$y,$c);
    $c;
}
#line 327 "lib/PDL/Primitive.pm"

*matmult = \&PDL::matmult;






=head2 innerwt

=for sig

 Signature: (a(n); b(n); c(n); [o]d())
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble cfloat cdouble cldouble)

=for usage

 $d = innerwt($a, $b, $c);
 innerwt($a, $b, $c, $d);  # all arguments given
 $d = $a->innerwt($b, $c); # method call
 $a->innerwt($b, $c, $d);

=for ref

Weighted (i.e. triple) inner product

 d = sum_i a(i) b(i) c(i)

=pod

Broadcasts over its inputs.

=for bad

C<innerwt> processes bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*innerwt = \&PDL::innerwt;






=head2 inner2

=for sig

 Signature: (a(n); b(n,m); c(m); [o]d())
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble cfloat cdouble cldouble)

=for usage

 $d = inner2($a, $b, $c);
 inner2($a, $b, $c, $d);  # all arguments given
 $d = $a->inner2($b, $c); # method call
 $a->inner2($b, $c, $d);

=for ref

Inner product of two vectors and a matrix

 d = sum_ij a(i) b(i,j) c(j)

Note that you should probably not broadcast over C<a> and C<c> since that would be
very wasteful. Instead, you should use a temporary for C<b*c>.

=pod

Broadcasts over its inputs.

=for bad

C<inner2> processes bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*inner2 = \&PDL::inner2;






=head2 inner2d

=for sig

 Signature: (a(n,m); b(n,m); [o]c())
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble cfloat cdouble cldouble)

=for usage

 $c = inner2d($a, $b);
 inner2d($a, $b, $c);  # all arguments given
 $c = $a->inner2d($b); # method call
 $a->inner2d($b, $c);

=for ref

Inner product over 2 dimensions.

Equivalent to

 $c = inner($x->clump(2), $y->clump(2))

=pod

Broadcasts over its inputs.

=for bad

C<inner2d> processes bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*inner2d = \&PDL::inner2d;






=head2 inner2t

=for sig

 Signature: (a(j,n); b(n,m); c(m,k); [t]tmp(n,k); [o]d(j,k))
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble cfloat cdouble cldouble)

=for usage

 $d = inner2t($a, $b, $c);
 inner2t($a, $b, $c, $d);  # all arguments given
 $d = $a->inner2t($b, $c); # method call
 $a->inner2t($b, $c, $d);

=for ref

Efficient Triple matrix product C<a*b*c>

Efficiency comes from by using the temporary C<tmp>. This operation only
scales as C<N**3> whereas broadcasting using L</inner2> would scale
as C<N**4>.

The reason for having this routine is that you do not need to
have the same broadcast-dimensions for C<tmp> as for the other arguments,
which in case of large numbers of matrices makes this much more
memory-efficient.

It is hoped that things like this could be taken care of as a kind of
closure at some point.

=pod

Broadcasts over its inputs.

=for bad

C<inner2t> processes bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*inner2t = \&PDL::inner2t;






=head2 crossp

=for sig

 Signature: (a(tri=3); b(tri); [o] c(tri))
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble cfloat cdouble cldouble)

=for usage

 $c = crossp($a, $b);
 crossp($a, $b, $c);  # all arguments given
 $c = $a->crossp($b); # method call
 $a->crossp($b, $c);

=for ref

Cross product of two 3D vectors

After

=for example

 $c = crossp $x, $y

the inner product C<$c*$x> and C<$c*$y> will be zero, i.e. C<$c> is
orthogonal to C<$x> and C<$y>

=pod

Broadcasts over its inputs.

=for bad

C<crossp> does not process bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*crossp = \&PDL::crossp;






=head2 norm

=for sig

 Signature: (vec(n); [o] norm(n))
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble cfloat cdouble cldouble)

=for usage

 $norm = norm($vec);
 norm($vec, $norm);  # all arguments given
 $norm = $vec->norm; # method call
 $vec->norm($norm);

Normalises a vector to unit Euclidean length

See also L</inner>, L<PDL::Ufunc/magnover>.

=pod

Broadcasts over its inputs.

=for bad

C<norm> processes bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*norm = \&PDL::norm;






=head2 indadd

=for sig

 Signature: (input(n); indx ind(n); [io] sum(m))
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble cfloat cdouble cldouble)

=for usage

 indadd($input, $ind, $sum); # all arguments given
 $input->indadd($ind, $sum); # method call

=for ref

Broadcasting index add: add C<input> to the C<ind> element of C<sum>, i.e:

 sum(ind) += input

=for example

Simple example:

  $x = 2;
  $ind = 3;
  $sum = zeroes(10);
  indadd($x,$ind, $sum);
  print $sum
  #Result: ( 2 added to element 3 of $sum)
  # [0 0 0 2 0 0 0 0 0 0]

Broadcasting example:

  $x = pdl( 1,2,3);
  $ind = pdl( 1,4,6);
  $sum = zeroes(10);
  indadd($x,$ind, $sum);
  print $sum."\n";
  #Result: ( 1, 2, and 3 added to elements 1,4,6 $sum)
  # [0 1 0 0 2 0 3 0 0 0]

=pod

Broadcasts over its inputs.

=for bad

The routine barfs on bad indices, and bad inputs set target outputs bad.

=cut




*indadd = \&PDL::indadd;






=head2 conv1d

=for sig

 Signature: (a(m); kern(p); [o]b(m); int reflect)
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble cfloat cdouble cldouble)

=for usage

 $b = conv1d($a, $kern, $reflect);
 conv1d($a, $kern, $b, $reflect);  # all arguments given
 $b = $a->conv1d($kern, $reflect); # method call
 $a->conv1d($kern, $b, $reflect);

=for ref

1D convolution along first dimension

The m-th element of the discrete convolution of an input ndarray
C<$a> of size C<$M>, and a kernel ndarray C<$kern> of size C<$P>, is
calculated as

                              n = ($P-1)/2
                              ====
                              \
  ($a conv1d $kern)[m]   =     >      $a_ext[m - n] * $kern[n]
                              /
                              ====
                              n = -($P-1)/2

where C<$a_ext> is either the periodic (or reflected) extension of
C<$a> so it is equal to C<$a> on C< 0..$M-1 > and equal to the
corresponding periodic/reflected image of C<$a> outside that range.

=for example

  $con = conv1d sequence(10), pdl(-1,0,1);

  $con = conv1d sequence(10), pdl(-1,0,1), {Boundary => 'reflect'};

By default, periodic boundary conditions are assumed (i.e. wrap around).
Alternatively, you can request reflective boundary conditions using
the C<Boundary> option:

  {Boundary => 'reflect'} # case in 'reflect' doesn't matter

The convolution is performed along the first dimension. To apply it across
another dimension use the slicing routines, e.g.

  $y = $x->mv(2,0)->conv1d($kernel)->mv(0,2); # along third dim

This function is useful for broadcasted filtering of 1D signals.

Compare also L<conv2d|PDL::Image2D/conv2d>, L<convolve|PDL::ImageND/convolve>,
L<fftconvolve|PDL::FFT/fftconvolve()>

=for bad

WARNING: C<conv1d> processes bad values in its inputs as
the numeric value of C<< $pdl->badvalue >> so it is not
recommended for processing pdls with bad values in them
unless special care is taken.

=pod

Broadcasts over its inputs.

=for bad

C<conv1d> ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut





#line 568 "lib/PDL/Primitive.pd"
sub PDL::conv1d {
   my $opt = pop @_ if ref($_[-1]) eq 'HASH';
   die 'Usage: conv1d( a(m), kern(p), [o]b(m), {Options} )'
      if @_<2 || @_>3;
   my($x,$kern) = @_;
   my $c = @_ == 3 ? $_[2] : PDL->null;
   PDL::_conv1d_int($x,$kern,$c,
		     !(defined $opt && exists $$opt{Boundary}) ? 0 :
		     lc $$opt{Boundary} eq "reflect");
   return $c;
}
#line 760 "lib/PDL/Primitive.pm"

*conv1d = \&PDL::conv1d;






=head2 in

=for sig

 Signature: (a(); b(n); [o] c())
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble cfloat cdouble cldouble)

=for usage

 $c = in($a, $b);
 in($a, $b, $c);  # all arguments given
 $c = $a->in($b); # method call
 $a->in($b, $c);

=for ref

test if a is in the set of values b

=for example

   $goodmsk = $labels->in($goodlabels);
   print pdl(3,1,4,6,2)->in(pdl(2,3,3));
  [1 0 0 0 1]

C<in> is akin to the I<is an element of> of set theory. In principle,
PDL broadcasting could be used to achieve its functionality by using a
construct like

   $msk = ($labels->dummy(0) == $goodlabels)->orover;

However, C<in> doesn't create a (potentially large) intermediate
and is generally faster.

=pod

Broadcasts over its inputs.

=for bad

C<in> does not process bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*in = \&PDL::in;





#line 636 "lib/PDL/Primitive.pd"

=head2 uniq

=for ref

return all unique elements of an ndarray

The unique elements are returned in ascending order.

=for example

  PDL> p pdl(2,2,2,4,0,-1,6,6)->uniq
  [-1 0 2 4 6]     # 0 is returned 2nd (sorted order)

  PDL> p pdl(2,2,2,4,nan,-1,6,6)->uniq
  [-1 2 4 6 nan]   # NaN value is returned at end

Note: The returned pdl is 1D; any structure of the input
ndarray is lost.  C<NaN> values are never compare equal to
any other values, even themselves.  As a result, they are
always unique. C<uniq> returns the NaN values at the end
of the result ndarray.  This follows the Matlab usage.

See L</uniqind> if you need the indices of the unique
elements rather than the values.

=for bad

Bad values are not considered unique by uniq and are ignored.

 $x=sequence(10);
 $x=$x->setbadif($x%3);
 print $x->uniq;
 [0 3 6 9]

=cut

*uniq = \&PDL::uniq;
# return unique elements of array
# find as jumps in the sorted array
# flattens in the process
sub PDL::uniq {
   my ($arr) = @_;
   return $arr if($arr->nelem == 0); # The null list is unique (CED)
   return $arr->flat if($arr->nelem == 1); # singleton list is unique
   my $aflat = $arr->flat;
   my $srt  = $aflat->where($aflat==$aflat)->qsort; # no NaNs or BADs for qsort
   my $nans = $aflat->where($aflat!=$aflat);
   my $uniq = ($srt->nelem > 1) ? $srt->where($srt != $srt->rotate(-1)) : $srt;
   # make sure we return something if there is only one value
   (
      $uniq->nelem > 0 ? $uniq :
      $srt->nelem == 0 ? $srt :
      PDL::pdl( ref($srt), [$srt->index(0)] )
   )->append($nans);
}

#line 695 "lib/PDL/Primitive.pd"

=head2 uniqind

=for ref

Return the indices of all unique elements of an ndarray
The order is in the order of the values to be consistent
with uniq. C<NaN> values never compare equal with any
other value and so are always unique.  This follows the
Matlab usage.

=for example

  PDL> p pdl(2,2,2,4,0,-1,6,6)->uniqind
  [5 4 1 3 6]     # the 0 at index 4 is returned 2nd, but...

  PDL> p pdl(2,2,2,4,nan,-1,6,6)->uniqind
  [5 1 3 6 4]     # ...the NaN at index 4 is returned at end

Note: The returned pdl is 1D; any structure of the input
ndarray is lost.

See L</uniq> if you want the unique values instead of the
indices.

=for bad

Bad values are not considered unique by uniqind and are ignored.

=cut

*uniqind = \&PDL::uniqind;
# return unique elements of array
# find as jumps in the sorted array
# flattens in the process
sub PDL::uniqind {
  use PDL::Core 'barf';
  my ($arr) = @_;
  return $arr if($arr->nelem == 0); # The null list is unique (CED)
  # Different from uniq we sort and store the result in an intermediary
  my $aflat = $arr->flat;
  my $nanind = which($aflat!=$aflat);                        # NaN indexes
  my $good = PDL->sequence(indx, $aflat->dims)->where($aflat==$aflat);  # good indexes
  my $i_srt = $aflat->where($aflat==$aflat)->qsorti;         # no BAD or NaN values for qsorti
  my $srt = $aflat->where($aflat==$aflat)->index($i_srt);
  my $uniqind;
  if ($srt->nelem > 0) {
     $uniqind = which($srt != $srt->rotate(-1));
     $uniqind = $i_srt->slice('0') if $uniqind->isempty;
  } else {
     $uniqind = which($srt);
  }
  # Now map back to the original space
  my $ansind = $nanind;
  if ( $uniqind->nelem > 0 ) {
     $ansind = ($good->index($i_srt->index($uniqind)))->append($ansind);
  } else {
     $ansind = $uniqind->append($ansind);
  }
  return $ansind;
}

#line 761 "lib/PDL/Primitive.pd"

=head2 uniqvec

=for ref

Return all unique vectors out of a collection

  NOTE: If any vectors in the input ndarray have NaN values
  they are returned at the end of the non-NaN ones.  This is
  because, by definition, NaN values never compare equal with
  any other value.

  NOTE: The current implementation does not sort the vectors
  containing NaN values.

The unique vectors are returned in lexicographically sorted
ascending order. The 0th dimension of the input PDL is treated
as a dimensional index within each vector, and the 1st and any
higher dimensions are taken to run across vectors. The return
value is always 2D; any structure of the input PDL (beyond using
the 0th dimension for vector index) is lost.

See also L</uniq> for a unique list of scalars; and
L<qsortvec|PDL::Ufunc/qsortvec> for sorting a list of vectors
lexicographcally.

=for bad

If a vector contains all bad values, it is ignored as in L</uniq>.
If some of the values are good, it is treated as a normal vector. For
example, [1 2 BAD] and [BAD 2 3] could be returned, but [BAD BAD BAD]
could not.  Vectors containing BAD values will be returned after any
non-NaN and non-BAD containing vectors, followed by the NaN vectors.

=cut

sub PDL::uniqvec {
   my($pdl) = shift;

   return $pdl if ( $pdl->nelem == 0 || $pdl->ndims < 2 );
   return $pdl if ( $pdl->slice("(0)")->nelem < 2 );                     # slice isn't cheap but uniqvec isn't either

   my $pdl2d = $pdl->clump(1..$pdl->ndims-1);
   my $ngood = $pdl2d->ngoodover;
   $pdl2d = $pdl2d->mv(0,-1)->dice($ngood->which)->mv(-1,0);             # remove all-BAD vectors

   my $numnan = ($pdl2d!=$pdl2d)->sumover;                                  # works since no all-BADs to confuse

   my $presrt = $pdl2d->mv(0,-1)->dice($numnan->not->which)->mv(0,-1);      # remove vectors with any NaN values
   my $nanvec = $pdl2d->mv(0,-1)->dice($numnan->which)->mv(0,-1);           # the vectors with any NaN values

   my $srt = $presrt->qsortvec->mv(0,-1);                                   # BADs are sorted by qsortvec
   my $srtdice = $srt;
   my $somebad = null;
   if ($srt->badflag) {
      $srtdice = $srt->dice($srt->mv(0,-1)->nbadover->not->which);
      $somebad = $srt->dice($srt->mv(0,-1)->nbadover->which);
   }

   my $uniq = $srtdice->nelem > 0
     ? ($srtdice != $srtdice->rotate(-1))->mv(0,-1)->orover->which
     : $srtdice->orover->which;

   my $ans = $uniq->nelem > 0 ? $srtdice->dice($uniq) :
      ($srtdice->nelem > 0) ? $srtdice->slice("0,:") :
      $srtdice;
   return $ans->append($somebad)->append($nanvec->mv(0,-1))->mv(0,-1);
}
#line 1013 "lib/PDL/Primitive.pm"


=head2 hclip

=for sig

 Signature: (a(); b(); [o] c())
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble)

=for usage

 $c = hclip($a, $b);
 hclip($a, $b, $c);  # all arguments given
 $c = $a->hclip($b); # method call
 $a->hclip($b, $c);

=for ref

clip (threshold) C<$a> by C<$b> (C<$b> is upper bound)

=pod

Broadcasts over its inputs.

=for bad

C<hclip> processes bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut





#line 856 "lib/PDL/Primitive.pd"
sub PDL::hclip {
   my ($x,$y) = @_;
   my $c;
   if ($x->is_inplace) {
       $x->set_inplace(0); $c = $x;
   } elsif (@_ > 2) {$c=$_[2]} else {$c=PDL->nullcreate($x)}
   PDL::_hclip_int($x,$y,$c);
   return $c;
}
#line 1060 "lib/PDL/Primitive.pm"

*hclip = \&PDL::hclip;






=head2 lclip

=for sig

 Signature: (a(); b(); [o] c())
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble)

=for usage

 $c = lclip($a, $b);
 lclip($a, $b, $c);  # all arguments given
 $c = $a->lclip($b); # method call
 $a->lclip($b, $c);

=for ref

clip (threshold) C<$a> by C<$b> (C<$b> is lower bound)

=pod

Broadcasts over its inputs.

=for bad

C<lclip> processes bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut





#line 856 "lib/PDL/Primitive.pd"
sub PDL::lclip {
   my ($x,$y) = @_;
   my $c;
   if ($x->is_inplace) {
       $x->set_inplace(0); $c = $x;
   } elsif (@_ > 2) {$c=$_[2]} else {$c=PDL->nullcreate($x)}
   PDL::_lclip_int($x,$y,$c);
   return $c;
}
#line 1113 "lib/PDL/Primitive.pm"

*lclip = \&PDL::lclip;






=head2 clip

=for sig

 Signature: (a(); l(); h(); [o] c())
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble)

=for ref

Clip (threshold) an ndarray by (optional) upper or lower bounds.

=for usage

 $y = $x->clip(0,3);
 $c = $x->clip(undef, $x);

=pod

Broadcasts over its inputs.

=for bad

C<clip> processes bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut





#line 892 "lib/PDL/Primitive.pd"
*clip = \&PDL::clip;
sub PDL::clip {
  my($x, $l, $h) = @_;
  my $d;
  unless(defined($l) || defined($h)) {
      # Deal with pathological case
      if($x->is_inplace) {
	  $x->set_inplace(0);
	  return $x;
      } else {
	  return $x->copy;
      }
  }

  if($x->is_inplace) {
      $x->set_inplace(0); $d = $x
  } elsif (@_ > 3) {
      $d=$_[3]
  } else {
      $d = PDL->nullcreate($x);
  }
  if(defined($l) && defined($h)) {
      PDL::_clip_int($x,$l,$h,$d);
  } elsif( defined($l) ) {
      PDL::_lclip_int($x,$l,$d);
  } elsif( defined($h) ) {
      PDL::_hclip_int($x,$h,$d);
  } else {
      die "This can't happen (clip contingency) - file a bug";
  }

  return $d;
}
#line 1188 "lib/PDL/Primitive.pm"

*clip = \&PDL::clip;






=head2 wtstat

=for sig

 Signature: (a(n); wt(n); avg(); [o]b(); int deg)
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble cfloat cdouble cldouble)

=for usage

 $b = wtstat($a, $wt, $avg, $deg);
 wtstat($a, $wt, $avg, $b, $deg);  # all arguments given
 $b = $a->wtstat($wt, $avg, $deg); # method call
 $a->wtstat($wt, $avg, $b, $deg);

=for ref

Weighted statistical moment of given degree

This calculates a weighted statistic over the vector C<a>.
The formula is

 b() = (sum_i wt_i * (a_i ** degree - avg)) / (sum_i wt_i)

=pod

Broadcasts over its inputs.

=for bad

Bad values are ignored in any calculation; C<$b> will only
have its bad flag set if the output contains any bad data.

=cut




*wtstat = \&PDL::wtstat;






=head2 statsover

=for sig

 Signature: (a(n); w(n); float+ [o]avg(); float+ [o]prms(); int+ [o]min(); int+ [o]max(); float+ [o]adev(); float+ [o]rms())
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble)

=for ref

Calculate useful statistics over a dimension of an ndarray

=for usage

  ($mean,$prms,$median,$min,$max,$adev,$rms) = statsover($ndarray, $weights);

This utility function calculates various useful
quantities of an ndarray. These are:

=over 3

=item * the mean:

  MEAN = sum (x)/ N

with C<N> being the number of elements in x

=item * the population RMS deviation from the mean:

  PRMS = sqrt( sum( (x-mean(x))^2 )/(N-1) )

The population deviation is the best-estimate of the deviation
of the population from which a sample is drawn.

=item * the median

The median is the 50th percentile data value.  Median is found by
L<medover|PDL::Ufunc/medover>, so WEIGHTING IS IGNORED FOR THE MEDIAN CALCULATION.

=item * the minimum

=item * the maximum

=item * the average absolute deviation:

  AADEV = sum( abs(x-mean(x)) )/N

=item * RMS deviation from the mean:

  RMS = sqrt(sum( (x-mean(x))^2 )/N)

(also known as the root-mean-square deviation, or the square root of the
variance)

=back

This operator is a projection operator so the calculation
will take place over the final dimension. Thus if the input
is N-dimensional each returned value will be N-1 dimensional,
to calculate the statistics for the entire ndarray either
use C<clump(-1)> directly on the ndarray or call C<stats>.

=pod

Broadcasts over its inputs.

=for bad

Bad values are simply ignored in the calculation, effectively reducing
the sample size.  If all data are bad then the output data are marked bad.

=cut





#line 1018 "lib/PDL/Primitive.pd"
sub PDL::statsover {
   barf('Usage: ($mean,[$prms, $median, $min, $max, $adev, $rms]) = statsover($data,[$weights])') if @_>2;
   my ($data, $weights) = @_;
   $weights //= $data->ones();
   my $median = $data->medover;
   my $mean = PDL->nullcreate($data);
   my $rms = PDL->nullcreate($data);
   my $min = PDL->nullcreate($data);
   my $max = PDL->nullcreate($data);
   my $adev = PDL->nullcreate($data);
   my $prms = PDL->nullcreate($data);
   PDL::_statsover_int($data, $weights, $mean, $prms, $min, $max, $adev, $rms);
   wantarray ? ($mean, $prms, $median, $min, $max, $adev, $rms) : $mean;
}
#line 1334 "lib/PDL/Primitive.pm"

*statsover = \&PDL::statsover;





#line 1095 "lib/PDL/Primitive.pd"

=head2 stats

=for ref

Calculates useful statistics on an ndarray

=for usage

 ($mean,$prms,$median,$min,$max,$adev,$rms) = stats($ndarray,[$weights]);

This utility calculates all the most useful quantities in one call.
It works the same way as L</statsover>, except that the quantities are
calculated considering the entire input PDL as a single sample, rather
than as a collection of rows. See L</statsover> for definitions of the
returned quantities.

=for bad

Bad values are handled; if all input values are bad, then all of the output
values are flagged bad.

=cut

*stats	  = \&PDL::stats;
sub PDL::stats {
    barf('Usage: ($mean,[$rms]) = stats($data,[$weights])') if @_>2;
    my ($data,$weights) = @_;

    # Ensure that $weights is properly broadcasted over; this could be
    # done rather more efficiently...
    if(defined $weights) {
	$weights = pdl($weights) unless UNIVERSAL::isa($weights,'PDL');
	if( ($weights->ndims != $data->ndims) or
	    (pdl($weights->dims) != pdl($data->dims))->or
	  ) {
		$weights = $weights + zeroes($data)
	}
	$weights = $weights->flat;
    }

    return PDL::statsover($data->flat,$weights);
}
#line 1386 "lib/PDL/Primitive.pm"


=head2 histogram

=for sig

 Signature: (in(n); int+[o] hist(m); double step; double min; IV msize => m)
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble cfloat cdouble cldouble)

=for ref

Calculates a histogram for given stepsize and minimum.

=for usage

 $h = histogram($data, $step, $min, $numbins);
 $hist = zeroes $numbins;  # Put histogram in existing ndarray.
 histogram($data, $hist, $step, $min, $numbins);

The histogram will contain C<$numbins> bins starting from C<$min>, each
C<$step> wide. The value in each bin is the number of
values in C<$data> that lie within the bin limits.

Data below the lower limit is put in the first bin, and data above the
upper limit is put in the last bin.

The output is reset in a different broadcastloop so that you
can take a histogram of C<$a(10,12)> into C<$b(15)> and get the result
you want.

For a higher-level interface, see L<hist|PDL::Basic/hist>.

=for example

 pdl> p histogram(pdl(1,1,2),1,0,3)
 [0 2 1]

=pod

Broadcasts over its inputs.

=for bad

C<histogram> processes bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*histogram = \&PDL::histogram;






=head2 whistogram

=for sig

 Signature: (in(n); float+ wt(n);float+[o] hist(m); double step; double min; IV msize => m)
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble cfloat cdouble cldouble)

=for ref

Calculates a histogram from weighted data for given stepsize and minimum.

=for usage

 $h = whistogram($data, $weights, $step, $min, $numbins);
 $hist = zeroes $numbins;  # Put histogram in existing ndarray.
 whistogram($data, $weights, $hist, $step, $min, $numbins);

The histogram will contain C<$numbins> bins starting from C<$min>, each
C<$step> wide. The value in each bin is the sum of the values in C<$weights>
that correspond to values in C<$data> that lie within the bin limits.

Data below the lower limit is put in the first bin, and data above the
upper limit is put in the last bin.

The output is reset in a different broadcastloop so that you
can take a histogram of C<$a(10,12)> into C<$b(15)> and get the result
you want.

=for example

 pdl> p whistogram(pdl(1,1,2), pdl(0.1,0.1,0.5), 1, 0, 4)
 [0 0.2 0.5 0]

=pod

Broadcasts over its inputs.

=for bad

C<whistogram> processes bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*whistogram = \&PDL::whistogram;






=head2 histogram2d

=for sig

 Signature: (ina(n); inb(n); int+[o] hist(ma,mb); double stepa; double mina; IV masize => ma;
	             double stepb; double minb; IV mbsize => mb;)
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble cfloat cdouble cldouble)

=for ref

Calculates a 2d histogram.

=for usage

 $h = histogram2d($datax, $datay, $stepx, $minx,
       $nbinx, $stepy, $miny, $nbiny);
 $hist = zeroes $nbinx, $nbiny;  # Put histogram in existing ndarray.
 histogram2d($datax, $datay, $hist, $stepx, $minx,
       $nbinx, $stepy, $miny, $nbiny);

The histogram will contain C<$nbinx> x C<$nbiny> bins, with the lower
limits of the first one at C<($minx, $miny)>, and with bin size
C<($stepx, $stepy)>.
The value in each bin is the number of
values in C<$datax> and C<$datay> that lie within the bin limits.

Data below the lower limit is put in the first bin, and data above the
upper limit is put in the last bin.

=for example

 pdl> p histogram2d(pdl(1,1,1,2,2),pdl(2,1,1,1,1),1,0,3,1,0,3)
 [
  [0 0 0]
  [0 2 2]
  [0 1 0]
 ]

=pod

Broadcasts over its inputs.

=for bad

C<histogram2d> processes bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*histogram2d = \&PDL::histogram2d;






=head2 whistogram2d

=for sig

 Signature: (ina(n); inb(n); float+ wt(n);float+[o] hist(ma,mb); double stepa; double mina; IV masize => ma;
	             double stepb; double minb; IV mbsize => mb;)
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble cfloat cdouble cldouble)

=for ref

Calculates a 2d histogram from weighted data.

=for usage

 $h = whistogram2d($datax, $datay, $weights,
       $stepx, $minx, $nbinx, $stepy, $miny, $nbiny);
 $hist = zeroes $nbinx, $nbiny;  # Put histogram in existing ndarray.
 whistogram2d($datax, $datay, $weights, $hist,
       $stepx, $minx, $nbinx, $stepy, $miny, $nbiny);

The histogram will contain C<$nbinx> x C<$nbiny> bins, with the lower
limits of the first one at C<($minx, $miny)>, and with bin size
C<($stepx, $stepy)>.
The value in each bin is the sum of the values in
C<$weights> that correspond to values in C<$datax> and C<$datay> that lie within the bin limits.

Data below the lower limit is put in the first bin, and data above the
upper limit is put in the last bin.

=for example

 pdl> p whistogram2d(pdl(1,1,1,2,2),pdl(2,1,1,1,1),pdl(0.1,0.2,0.3,0.4,0.5),1,0,3,1,0,3)
 [
  [  0   0   0]
  [  0 0.5 0.9]
  [  0 0.1   0]
 ]

=pod

Broadcasts over its inputs.

=for bad

C<whistogram2d> processes bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*whistogram2d = \&PDL::whistogram2d;






=head2 fibonacci

=for sig

 Signature: (i(n); [o]x(n))
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble cfloat cdouble cldouble)

=for usage

 $x = fibonacci($i);
 fibonacci($i, $x);      # all arguments given
 $x = $i->fibonacci;     # method call
 $i->fibonacci($x);
 $i->inplace->fibonacci; # can be used inplace
 fibonacci($i->inplace);

=for ref

Constructor - a vector with Fibonacci's sequence

=pod

Broadcasts over its inputs.

=for bad

C<fibonacci> does not process bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut





#line 1363 "lib/PDL/Primitive.pd"
sub fibonacci { ref($_[0]) && ref($_[0]) ne 'PDL::Type' ? $_[0]->fibonacci : PDL->fibonacci(@_) }
sub PDL::fibonacci{
   my $x = &PDL::Core::_construct;
   my $is_inplace = $x->is_inplace;
   my ($in, $out) = $x->flat;
   $out = $is_inplace ? $in->inplace : PDL->null;
   PDL::_fibonacci_int($in, $out);
   $out;
}
#line 1667 "lib/PDL/Primitive.pm"


=head2 append

=for sig

 Signature: (a(n); b(m); [o] c(mn=CALC($SIZE(n)+$SIZE(m))))
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble cfloat cdouble cldouble)

=for usage

 $c = append($a, $b);
 append($a, $b, $c);  # all arguments given
 $c = $a->append($b); # method call
 $a->append($b, $c);

=for ref

append two ndarrays by concatenating along their first dimensions

=for example

 $x = ones(2,4,7);
 $y = sequence 5;
 $c = $x->append($y);  # size of $c is now (7,4,7) (a jumbo-ndarray ;)

C<append> appends two ndarrays along their first dimensions. The rest of the
dimensions must be compatible in the broadcasting sense. The resulting
size of the first dimension is the sum of the sizes of the first dimensions
of the two argument ndarrays - i.e. C<n + m>.

Similar functions include L</glue> (below), which can append more
than two ndarrays along an arbitrary dimension, and
L<cat|PDL::Core/cat>, which can append more than two ndarrays that all
have the same sized dimensions.

=pod

Broadcasts over its inputs.

=for bad

C<append> does not process bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut





#line 1389 "lib/PDL/Primitive.pd"

sub PDL::append {
  my ($i1, $i2, $o) = map PDL->topdl($_), @_;
  $_ = empty() for grep $_->isnull, $i1, $i2;
  my $nempty = grep $_->isempty, $i1, $i2;
  if ($nempty == 2) {
    my @dims = $i1->dims;
    $dims[0] += $i2->dim(0);
    return PDL->zeroes($i1->type, @dims);
  }
  $o //= PDL->null;
  $o .= $i1->isempty ? $i2 : $i1, return $o if $nempty == 1;
  PDL::_append_int($i1, $i2->convert($i1->type), $o);
  $o;
}
        
#line 1737 "lib/PDL/Primitive.pm"

*append = \&PDL::append;





#line 1433 "lib/PDL/Primitive.pd"

=head2 glue

=for usage

  $c = $x->glue(<dim>,$y,...)

=for ref

Glue two or more PDLs together along an arbitrary dimension
(N-D L</append>).

Sticks $x, $y, and all following arguments together along the
specified dimension.  All other dimensions must be compatible in the
broadcasting sense.

Glue is permissive, in the sense that every PDL is treated as having an
infinite number of trivial dimensions of order 1 -- so C<< $x->glue(3,$y) >>
works, even if $x and $y are only one dimensional.

If one of the PDLs has no elements, it is ignored.  Likewise, if one
of them is actually the undefined value, it is treated as if it had no
elements.

If the first parameter is a defined perl scalar rather than a pdl,
then it is taken as a dimension along which to glue everything else,
so you can say C<$cube = PDL::glue(3,@image_list);> if you like.

C<glue> is implemented in pdl, using a combination of L<xchg|PDL::Slices/xchg> and
L</append>.  It should probably be updated (one day) to a pure PP
function.

Similar functions include L</append> (above), which appends
only two ndarrays along their first dimension, and
L<cat|PDL::Core/cat>, which can append more than two ndarrays that all
have the same sized dimensions.

=cut

sub PDL::glue{
    my($x) = shift;
    my($dim) = shift;

    ($dim, $x) = ($x, $dim) if defined $x && !ref $x;
    confess 'dimension must be Perl scalar' if ref $dim;

    if(!defined $x || $x->nelem==0) {
	return $x unless(@_);
	return shift() if(@_<=1);
	$x=shift;
	return PDL::glue($x,$dim,@_);
    }

    if($dim - $x->dim(0) > 100) {
	print STDERR "warning:: PDL::glue allocating >100 dimensions!\n";
    }
    while($dim >= $x->ndims) {
	$x = $x->dummy(-1,1);
    }
    $x = $x->xchg(0,$dim) if 0 != $dim;

    while(scalar(@_)){
	my $y = shift;
	next unless(defined $y && $y->nelem);

	while($dim >= $y->ndims) {
		$y = $y->dummy(-1,1);
        }
	$y = $y->xchg(0,$dim) if 0 != $dim;
	$x = $x->append($y);
    }
    0 == $dim ? $x : $x->xchg(0,$dim);
}
#line 1819 "lib/PDL/Primitive.pm"

*axisvalues = \&PDL::axisvalues;






=head2 cmpvec

=for sig

 Signature: (a(n); b(n); sbyte [o]c())
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble)

=for usage

 $c = cmpvec($a, $b);
 cmpvec($a, $b, $c);  # all arguments given
 $c = $a->cmpvec($b); # method call
 $a->cmpvec($b, $c);

=for ref

Compare two vectors lexicographically.

Returns -1 if a is less, 1 if greater, 0 if equal.

=pod

Broadcasts over its inputs.

=for bad

The output is bad if any input values up to the point of inequality are
bad - any after are ignored.

=cut




*cmpvec = \&PDL::cmpvec;






=head2 eqvec

=for sig

 Signature: (a(n); b(n); sbyte [o]c())
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble)

=for usage

 $c = eqvec($a, $b);
 eqvec($a, $b, $c);  # all arguments given
 $c = $a->eqvec($b); # method call
 $a->eqvec($b, $c);

=for ref

Compare two vectors, returning 1 if equal, 0 if not equal.

=pod

Broadcasts over its inputs.

=for bad

The output is bad if any input values are bad.

=cut




*eqvec = \&PDL::eqvec;






=head2 enumvec

=for sig

 Signature: (v(M,N); indx [o]k(N))
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble)

=for usage

 $k = enumvec($v);
 enumvec($v, $k);  # all arguments given
 $k = $v->enumvec; # method call
 $v->enumvec($k);

=for ref

Enumerate a list of vectors with locally unique keys.

Given a sorted list of vectors $v, generate a vector $k containing locally unique keys for the elements of $v
(where an "element" is a vector of length $M occurring in $v).

Note that the keys returned in $k are only unique over a run of a single vector in $v,
so that each unique vector in $v has at least one 0 (zero) index in $k associated with it.
If you need global keys, see enumvecg().

Contributed by Bryan Jurish E<lt>moocow@cpan.orgE<gt>.

=pod

Broadcasts over its inputs.

=for bad

C<enumvec> does not process bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*enumvec = \&PDL::enumvec;






=head2 enumvecg

=for sig

 Signature: (v(M,N); indx [o]k(N))
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble)

=for usage

 $k = enumvecg($v);
 enumvecg($v, $k);  # all arguments given
 $k = $v->enumvecg; # method call
 $v->enumvecg($k);

=for ref

Enumerate a list of vectors with globally unique keys.

Given a sorted list of vectors $v, generate a vector $k containing globally unique keys for the elements of $v
(where an "element" is a vector of length $M occurring in $v).
Basically does the same thing as:

 $k = $v->vsearchvec($v->uniqvec);

... but somewhat more efficiently.

Contributed by Bryan Jurish E<lt>moocow@cpan.orgE<gt>.

=pod

Broadcasts over its inputs.

=for bad

C<enumvecg> does not process bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*enumvecg = \&PDL::enumvecg;






=head2 vsearchvec

=for sig

 Signature: (find(M); which(M,N); indx [o]found())
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble)

=for usage

 $found = vsearchvec($find, $which);
 vsearchvec($find, $which, $found);  # all arguments given
 $found = $find->vsearchvec($which); # method call
 $find->vsearchvec($which, $found);

=for ref

Routine for searching N-dimensional values - akin to vsearch() for vectors.

=for example

 $found   = vsearchvec($find, $which);
 $nearest = $which->dice_axis(1,$found);

Returns for each row-vector in C<$find> the index along dimension N
of the least row vector of C<$which>
greater or equal to it.
C<$which> should be sorted in increasing order.
If the value of C<$find> is larger
than any member of C<$which>, the index to the last element of C<$which> is
returned.

See also: L</vsearch>.
Contributed by Bryan Jurish E<lt>moocow@cpan.orgE<gt>.

=pod

Broadcasts over its inputs.

=for bad

C<vsearchvec> does not process bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*vsearchvec = \&PDL::vsearchvec;






=head2 unionvec

=for sig

 Signature: (a(M,NA); b(M,NB); [o]c(M,NC=CALC($SIZE(NA) + $SIZE(NB))); indx [o]nc())
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble)

=for usage

 ($c, $nc) = unionvec($a, $b);
 unionvec($a, $b, $c, $nc);    # all arguments given
 ($c, $nc) = $a->unionvec($b); # method call
 $a->unionvec($b, $c, $nc);

=for ref

Union of two vector-valued PDLs.

Input PDLs $a() and $b() B<MUST> be sorted in lexicographic order.
On return, $nc() holds the actual number of vector-values in the union.

In scalar context, slices $c() to the actual number of elements in the union
and returns the sliced PDL.

Contributed by Bryan Jurish E<lt>moocow@cpan.orgE<gt>.

=pod

Broadcasts over its inputs.

=for bad

C<unionvec> does not process bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut





#line 1708 "lib/PDL/Primitive.pd"
 sub PDL::unionvec {
   my ($a,$b,$c,$nc) = @_;
   $c = PDL->null if (!defined($nc));
   $nc = PDL->null if (!defined($nc));
   PDL::_unionvec_int($a,$b,$c,$nc);
   return ($c,$nc) if (wantarray);
   return $c->slice(",0:".($nc->max-1));
 }
#line 2115 "lib/PDL/Primitive.pm"

*unionvec = \&PDL::unionvec;






=head2 intersectvec

=for sig

 Signature: (a(M,NA); b(M,NB); [o]c(M,NC=CALC(PDLMIN($SIZE(NA),$SIZE(NB)))); indx [o]nc())
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble)

=for usage

 ($c, $nc) = intersectvec($a, $b);
 intersectvec($a, $b, $c, $nc);    # all arguments given
 ($c, $nc) = $a->intersectvec($b); # method call
 $a->intersectvec($b, $c, $nc);

=for ref

Intersection of two vector-valued PDLs.
Input PDLs $a() and $b() B<MUST> be sorted in lexicographic order.
On return, $nc() holds the actual number of vector-values in the intersection.

In scalar context, slices $c() to the actual number of elements in the intersection
and returns the sliced PDL.

Contributed by Bryan Jurish E<lt>moocow@cpan.orgE<gt>.

=pod

Broadcasts over its inputs.

=for bad

C<intersectvec> does not process bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut





#line 1767 "lib/PDL/Primitive.pd"
 sub PDL::intersectvec {
   my ($a,$b,$c,$nc) = @_;
   $c = PDL->null if (!defined($c));
   $nc = PDL->null if (!defined($nc));
   PDL::_intersectvec_int($a,$b,$c,$nc);
   return ($c,$nc) if (wantarray);
   my $nc_max = $nc->max;
   return ($nc_max > 0
	   ? $c->slice(",0:".($nc_max-1))
	   : $c->reshape($c->dim(0), 0, ($c->dims)[2..($c->ndims-1)]));
 }
#line 2177 "lib/PDL/Primitive.pm"

*intersectvec = \&PDL::intersectvec;






=head2 setdiffvec

=for sig

 Signature: (a(M,NA); b(M,NB); [o]c(M,NC=CALC($SIZE(NA))); indx [o]nc())
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble)

=for usage

 ($c, $nc) = setdiffvec($a, $b);
 setdiffvec($a, $b, $c, $nc);    # all arguments given
 ($c, $nc) = $a->setdiffvec($b); # method call
 $a->setdiffvec($b, $c, $nc);

=for ref

Set-difference ($a() \ $b()) of two vector-valued PDLs.

Input PDLs $a() and $b() B<MUST> be sorted in lexicographic order.
On return, $nc() holds the actual number of vector-values in the computed vector set.

In scalar context, slices $c() to the actual number of elements in the output vector set
and returns the sliced PDL.

Contributed by Bryan Jurish E<lt>moocow@cpan.orgE<gt>.

=pod

Broadcasts over its inputs.

=for bad

C<setdiffvec> does not process bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut





#line 1822 "lib/PDL/Primitive.pd"
 sub PDL::setdiffvec {
  my ($a,$b,$c,$nc) = @_;
  $c = PDL->null if (!defined($c));
  $nc = PDL->null if (!defined($nc));
  PDL::_setdiffvec_int($a,$b,$c,$nc);
  return ($c,$nc) if (wantarray);
  my $nc_max = $nc->max;
  return ($nc_max > 0
	  ? $c->slice(",0:".($nc_max-1))
	  : $c->reshape($c->dim(0), 0, ($c->dims)[2..($c->ndims-1)]));
 }
#line 2240 "lib/PDL/Primitive.pm"

*setdiffvec = \&PDL::setdiffvec;






=head2 union_sorted

=for sig

 Signature: (a(NA); b(NB); [o]c(NC=CALC($SIZE(NA) + $SIZE(NB))); indx [o]nc())
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble)

=for usage

 ($c, $nc) = union_sorted($a, $b);
 union_sorted($a, $b, $c, $nc);    # all arguments given
 ($c, $nc) = $a->union_sorted($b); # method call
 $a->union_sorted($b, $c, $nc);

=for ref

Union of two flat sorted unique-valued PDLs.
Input PDLs $a() and $b() B<MUST> be sorted in lexicographic order and contain no duplicates.
On return, $nc() holds the actual number of values in the union.

In scalar context, reshapes $c() to the actual number of elements in the union and returns it.

Contributed by Bryan Jurish E<lt>moocow@cpan.orgE<gt>.

=pod

Broadcasts over its inputs.

=for bad

C<union_sorted> does not process bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut





#line 1888 "lib/PDL/Primitive.pd"
 sub PDL::union_sorted {
   my ($a,$b,$c,$nc) = @_;
   $c = PDL->null if (!defined($c));
   $nc = PDL->null if (!defined($nc));
   PDL::_union_sorted_int($a,$b,$c,$nc);
   return ($c,$nc) if (wantarray);
   return $c->slice("0:".($nc->max-1));
 }
#line 2298 "lib/PDL/Primitive.pm"

*union_sorted = \&PDL::union_sorted;






=head2 intersect_sorted

=for sig

 Signature: (a(NA); b(NB); [o]c(NC=CALC(PDLMIN($SIZE(NA),$SIZE(NB)))); indx [o]nc())
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble)

=for usage

 ($c, $nc) = intersect_sorted($a, $b);
 intersect_sorted($a, $b, $c, $nc);    # all arguments given
 ($c, $nc) = $a->intersect_sorted($b); # method call
 $a->intersect_sorted($b, $c, $nc);

=for ref

Intersection of two flat sorted unique-valued PDLs.
Input PDLs $a() and $b() B<MUST> be sorted in lexicographic order and contain no duplicates.
On return, $nc() holds the actual number of values in the intersection.

In scalar context, reshapes $c() to the actual number of elements in the intersection and returns it.

Contributed by Bryan Jurish E<lt>moocow@cpan.orgE<gt>.

=pod

Broadcasts over its inputs.

=for bad

C<intersect_sorted> does not process bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut





#line 1947 "lib/PDL/Primitive.pd"
 sub PDL::intersect_sorted {
   my ($a,$b,$c,$nc) = @_;
   $c = PDL->null if (!defined($c));
   $nc = PDL->null if (!defined($nc));
   PDL::_intersect_sorted_int($a,$b,$c,$nc);
   return ($c,$nc) if (wantarray);
   my $nc_max = $nc->max;
   return ($nc_max > 0
	   ? $c->slice("0:".($nc_max-1))
	   : $c->reshape(0, ($c->dims)[1..($c->ndims-1)]));
 }
#line 2359 "lib/PDL/Primitive.pm"

*intersect_sorted = \&PDL::intersect_sorted;






=head2 setdiff_sorted

=for sig

 Signature: (a(NA); b(NB); [o]c(NC=CALC($SIZE(NA))); indx [o]nc())
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble)

=for usage

 ($c, $nc) = setdiff_sorted($a, $b);
 setdiff_sorted($a, $b, $c, $nc);    # all arguments given
 ($c, $nc) = $a->setdiff_sorted($b); # method call
 $a->setdiff_sorted($b, $c, $nc);

=for ref

Set-difference ($a() \ $b()) of two flat sorted unique-valued PDLs.

Input PDLs $a() and $b() B<MUST> be sorted in lexicographic order and contain no duplicate values.
On return, $nc() holds the actual number of values in the computed vector set.

In scalar context, reshapes $c() to the actual number of elements in the difference set and returns it.

Contributed by Bryan Jurish E<lt>moocow@cpan.orgE<gt>.

=pod

Broadcasts over its inputs.

=for bad

C<setdiff_sorted> does not process bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut





#line 2003 "lib/PDL/Primitive.pd"
 sub PDL::setdiff_sorted {
   my ($a,$b,$c,$nc) = @_;
   $c = PDL->null if (!defined($c));
   $nc = PDL->null if (!defined($nc));
   PDL::_setdiff_sorted_int($a,$b,$c,$nc);
   return ($c,$nc) if (wantarray);
   my $nc_max = $nc->max;
   return ($nc_max > 0
	   ? $c->slice("0:".($nc_max-1))
	   : $c->reshape(0, ($c->dims)[1..($c->ndims-1)]));
 }
#line 2421 "lib/PDL/Primitive.pm"

*setdiff_sorted = \&PDL::setdiff_sorted;






=head2 vcos

=for sig

 Signature: (a(M,N);b(M);float+ [o]vcos(N))
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble cfloat cdouble cldouble)

=for usage

 $vcos = vcos($a, $b);
 vcos($a, $b, $vcos);  # all arguments given
 $vcos = $a->vcos($b); # method call
 $a->vcos($b, $vcos);

Computes the vector cosine similarity of a dense vector $b() with respect
to each row $a(*,i) of a dense PDL $a().  This is basically the same
thing as:

 inner($a, $b) / $a->magnover * $b->magnover

... but should be much faster to compute, and avoids allocating
potentially large temporaries for the vector magnitudes.  Output values
in $vcos() are cosine similarities in the range [-1,1], except for
zero-magnitude vectors which will result in NaN values in $vcos().

You can use PDL broadcasting to batch-compute distances for multiple $b()
vectors simultaneously:

  $bx   = random($M, $NB);   ##-- get $NB random vectors of size $N
  $vcos = vcos($a,$bx);   ##-- $vcos(i,j) ~ sim($a(,i),$b(,j))

Contributed by Bryan Jurish E<lt>moocow@cpan.orgE<gt>.

=pod

Broadcasts over its inputs.

=for bad

vcos() will set the bad status flag on the output $vcos() if
it is set on either of the inputs $a() or $b(), but BAD values
will otherwise be ignored for computing the cosine similarity.

=cut




*vcos = \&PDL::vcos;






=head2 srandom

=for sig

 Signature: (a())
 Types: (longlong)

=for ref

Seed random-number generator with a 64-bit int. Will generate seed data
for a number of threads equal to the return-value of
L<PDL::Core/online_cpus>.
As of 2.062, the generator changed from Perl's generator to xoshiro256++
(see L<https://prng.di.unimi.it/>).
Before PDL 2.090, this was called C<srand>, but was renamed to avoid
clashing with Perl's built-in.

=for usage

 srandom(); # uses current time
 srandom(5); # fixed number e.g. for testing

=pod

Does not broadcast.
Can't use POSIX threads.

=for bad

C<srandom> does not process bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut





#line 2179 "lib/PDL/Primitive.pd"
*srandom = \&PDL::srandom;
sub PDL::srandom { PDL::_srandom_int($_[0] // PDL::Core::seed()) }
#line 2527 "lib/PDL/Primitive.pm"

*srandom = \&PDL::srandom;






=head2 random

=for sig

 Signature: ([o] a())
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble)

=for ref

Constructor which returns ndarray of random numbers, real data-types only.

=for usage

 $x = random([type], $nx, $ny, $nz,...);
 $x = random $y;

etc (see L<zeroes|PDL::Core/zeroes>).

This is the uniform distribution between 0 and 1 (assumedly
excluding 1 itself). The arguments are the same as C<zeroes>
(q.v.) - i.e. one can specify dimensions, types or give
a template.

You can use the PDL function L</srandom> to seed the random generator.
If it has not been called yet, it will be with the current time.
As of 2.062, the generator changed from Perl's generator to xoshiro256++
(see L<https://prng.di.unimi.it/>).

=pod

Broadcasts over its inputs.

=for bad

C<random> does not process bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut





#line 2219 "lib/PDL/Primitive.pd"
sub random { ref($_[0]) && ref($_[0]) ne 'PDL::Type' ? $_[0]->random : PDL->random(@_) }
sub PDL::random {
   splice @_, 1, 0, double() if !ref($_[0]) and @_<=1;
   my $x = &PDL::Core::_construct;
   PDL::_random_int($x);
   return $x;
}
#line 2588 "lib/PDL/Primitive.pm"


=head2 randsym

=for sig

 Signature: ([o] a())
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble)

=for ref

Constructor which returns ndarray of random numbers, real data-types only.

=for usage

 $x = randsym([type], $nx, $ny, $nz,...);
 $x = randsym $y;

etc (see L<zeroes|PDL::Core/zeroes>).

This is the uniform distribution between 0 and 1 (excluding both 0 and
1, cf L</random>). The arguments are the same as C<zeroes> (q.v.) -
i.e. one can specify dimensions, types or give a template.

You can use the PDL function L</srandom> to seed the random generator.
If it has not been called yet, it will be with the current time.

=pod

Broadcasts over its inputs.

=for bad

C<randsym> does not process bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut





#line 2263 "lib/PDL/Primitive.pd"
sub randsym { ref($_[0]) && ref($_[0]) ne 'PDL::Type' ? $_[0]->randsym : PDL->randsym(@_) }
sub PDL::randsym {
   splice @_, 1, 0, double() if !ref($_[0]) and @_<=1;
   my $x = &PDL::Core::_construct;
   PDL::_randsym_int($x);
   return $x;
}

#line 2274 "lib/PDL/Primitive.pd"

=head2 grandom

=for ref

Constructor which returns ndarray of Gaussian random numbers

=for usage

 $x = grandom([type], $nx, $ny, $nz,...);
 $x = grandom $y;

etc (see L<zeroes|PDL::Core/zeroes>).

This is generated using the math library routine C<ndtri>.

Mean = 0, Stddev = 1

You can use the PDL function L</srandom> to seed the random generator.
If it has not been called yet, it will be with the current time.

=cut

sub grandom { ref($_[0]) && ref($_[0]) ne 'PDL::Type' ? $_[0]->grandom : PDL->grandom(@_) }
sub PDL::grandom {
   my $x = &PDL::Core::_construct;
   use PDL::Math 'ndtri';
   $x .= ndtri(randsym($x));
   return $x;
}

#line 2313 "lib/PDL/Primitive.pd"

=head2 vsearch

=for sig

  Signature: ( vals(); xs(n); [o] indx(); [\%options] )

=for ref

Efficiently search for values in a sorted ndarray, returning indices.

=for usage

  $idx = vsearch( $vals, $x, [\%options] );
  vsearch( $vals, $x, $idx, [\%options ] );

B<vsearch> performs a binary search in the ordered ndarray C<$x>,
for the values from C<$vals> ndarray, returning indices into C<$x>.
What is a "match", and the meaning of the returned indices, are determined
by the options.

The C<mode> option indicates which method of searching to use, and may
be one of:

=over

=item C<sample>

invoke L<B<vsearch_sample>|/vsearch_sample>, returning indices appropriate for sampling
within a distribution.

=item C<insert_leftmost>

invoke L<B<vsearch_insert_leftmost>|/vsearch_insert_leftmost>, returning the left-most possible
insertion point which still leaves the ndarray sorted.

=item C<insert_rightmost>

invoke L<B<vsearch_insert_rightmost>|/vsearch_insert_rightmost>, returning the right-most possible
insertion point which still leaves the ndarray sorted.

=item C<match>

invoke L<B<vsearch_match>|/vsearch_match>, returning the index of a matching element,
else -(insertion point + 1)

=item C<bin_inclusive>

invoke L<B<vsearch_bin_inclusive>|/vsearch_bin_inclusive>, returning an index appropriate for binning
on a grid where the left bin edges are I<inclusive> of the bin. See
below for further explanation of the bin.

=item C<bin_exclusive>

invoke L<B<vsearch_bin_exclusive>|/vsearch_bin_exclusive>, returning an index appropriate for binning
on a grid where the left bin edges are I<exclusive> of the bin. See
below for further explanation of the bin.

=back

The default value of C<mode> is C<sample>.

=for example

  use PDL;

  my @modes = qw( sample insert_leftmost insert_rightmost match
                  bin_inclusive bin_exclusive );

  # Generate a sequence of 3 zeros, 3 ones, ..., 3 fours.
  my $x = zeroes(3,5)->yvals->flat;

  for my $mode ( @modes ) {
    # if the value is in $x
    my $contained = 2;
    my $idx_contained = vsearch( $contained, $x, { mode => $mode } );
    my $x_contained = $x->copy;
    $x_contained->slice( $idx_contained ) .= 9;

    # if the value is not in $x
    my $not_contained = 1.5;
    my $idx_not_contained = vsearch( $not_contained, $x, { mode => $mode } );
    my $x_not_contained = $x->copy;
    $x_not_contained->slice( $idx_not_contained ) .= 9;

    print sprintf("%-23s%30s\n", '$x', $x);
    print sprintf("%-23s%30s\n",   "$mode ($contained)", $x_contained);
    print sprintf("%-23s%30s\n\n", "$mode ($not_contained)", $x_not_contained);
  }

  # $x                     [0 0 0 1 1 1 2 2 2 3 3 3 4 4 4]
  # sample (2)             [0 0 0 1 1 1 9 2 2 3 3 3 4 4 4]
  # sample (1.5)           [0 0 0 1 1 1 9 2 2 3 3 3 4 4 4]
  #
  # $x                     [0 0 0 1 1 1 2 2 2 3 3 3 4 4 4]
  # insert_leftmost (2)    [0 0 0 1 1 1 9 2 2 3 3 3 4 4 4]
  # insert_leftmost (1.5)  [0 0 0 1 1 1 9 2 2 3 3 3 4 4 4]
  #
  # $x                     [0 0 0 1 1 1 2 2 2 3 3 3 4 4 4]
  # insert_rightmost (2)   [0 0 0 1 1 1 2 2 2 9 3 3 4 4 4]
  # insert_rightmost (1.5) [0 0 0 1 1 1 9 2 2 3 3 3 4 4 4]
  #
  # $x                     [0 0 0 1 1 1 2 2 2 3 3 3 4 4 4]
  # match (2)              [0 0 0 1 1 1 2 9 2 3 3 3 4 4 4]
  # match (1.5)            [0 0 0 1 1 1 2 2 9 3 3 3 4 4 4]
  #
  # $x                     [0 0 0 1 1 1 2 2 2 3 3 3 4 4 4]
  # bin_inclusive (2)      [0 0 0 1 1 1 2 2 9 3 3 3 4 4 4]
  # bin_inclusive (1.5)    [0 0 0 1 1 9 2 2 2 3 3 3 4 4 4]
  #
  # $x                     [0 0 0 1 1 1 2 2 2 3 3 3 4 4 4]
  # bin_exclusive (2)      [0 0 0 1 1 9 2 2 2 3 3 3 4 4 4]
  # bin_exclusive (1.5)    [0 0 0 1 1 9 2 2 2 3 3 3 4 4 4]

Also see
L<B<vsearch_sample>|/vsearch_sample>,
L<B<vsearch_insert_leftmost>|/vsearch_insert_leftmost>,
L<B<vsearch_insert_rightmost>|/vsearch_insert_rightmost>,
L<B<vsearch_match>|/vsearch_match>,
L<B<vsearch_bin_inclusive>|/vsearch_bin_inclusive>, and
L<B<vsearch_bin_exclusive>|/vsearch_bin_exclusive>

=cut

sub vsearch {
    my $opt = 'HASH' eq ref $_[-1]
            ? pop
	    : { mode => 'sample' };

    croak( "unknown options to vsearch\n" )
	if ( ! defined $opt->{mode} && keys %$opt )
	|| keys %$opt > 1;

    my $mode = $opt->{mode};
    goto
        $mode eq 'sample'           ? \&vsearch_sample
      : $mode eq 'insert_leftmost'  ? \&vsearch_insert_leftmost
      : $mode eq 'insert_rightmost' ? \&vsearch_insert_rightmost
      : $mode eq 'match'            ? \&vsearch_match
      : $mode eq 'bin_inclusive'    ? \&vsearch_bin_inclusive
      : $mode eq 'bin_exclusive'    ? \&vsearch_bin_exclusive
      :                               croak( "unknown vsearch mode: $mode\n" );
}

*PDL::vsearch = \&vsearch;
#line 2819 "lib/PDL/Primitive.pm"


=head2 vsearch_sample

=for sig

 Signature: (vals(); x(n); indx [o]idx())
 Types: (float double ldouble)

=for ref

Search for values in a sorted array, return index appropriate for sampling from a distribution

=for usage

  $idx = vsearch_sample($vals, $x);

C<$x> must be sorted, but may be in decreasing or increasing
order.  if C<$x> is empty, then all values in C<$idx> will be
set to the bad value.

B<vsearch_sample> returns an index I<I> for each value I<V> of C<$vals> appropriate
for sampling C<$vals>

                   

I<I> has the following properties:

=over

=item *

if C<$x> is sorted in increasing order

          V <= x[0]  : I = 0
  x[0]  < V <= x[-1] : I s.t. x[I-1] < V <= x[I]
  x[-1] < V          : I = $x->nelem -1

=item *

if C<$x> is sorted in decreasing order

           V > x[0]  : I = 0
  x[0]  >= V > x[-1] : I s.t. x[I] >= V > x[I+1]
  x[-1] >= V         : I = $x->nelem - 1

=back

If all elements of C<$x> are equal, I<< I = $x->nelem - 1 >>.

If C<$x> contains duplicated elements, I<I> is the index of the
leftmost (by position in array) duplicate if I<V> matches.

=for example

This function is useful e.g. when you have a list of probabilities
for events and want to generate indices to events:

 $x = pdl(.01,.86,.93,1); # Barnsley IFS probabilities cumulatively
 $y = random 20;
 $c = vsearch_sample($y, $x); # Now, $c will have the appropriate distr.

It is possible to use the L<cumusumover|PDL::Ufunc/cumusumover>
function to obtain cumulative probabilities from absolute probabilities.

=pod

Broadcasts over its inputs.

=for bad

bad values in vals() result in bad values in idx()

=cut




*vsearch_sample = \&PDL::vsearch_sample;






=head2 vsearch_insert_leftmost

=for sig

 Signature: (vals(); x(n); indx [o]idx())
 Types: (float double ldouble)

=for ref

Determine the insertion point for values in a sorted array, inserting before duplicates.

=for usage

  $idx = vsearch_insert_leftmost($vals, $x);

C<$x> must be sorted, but may be in decreasing or increasing
order.  if C<$x> is empty, then all values in C<$idx> will be
set to the bad value.

B<vsearch_insert_leftmost> returns an index I<I> for each value I<V> of
C<$vals> equal to the leftmost position (by index in array) within
C<$x> that I<V> may be inserted and still maintain the order in
C<$x>.

Insertion at index I<I> involves shifting elements I<I> and higher of
C<$x> to the right by one and setting the now empty element at index
I<I> to I<V>.

                   

I<I> has the following properties:

=over

=item *

if C<$x> is sorted in increasing order

          V <= x[0]  : I = 0
  x[0]  < V <= x[-1] : I s.t. x[I-1] < V <= x[I]
  x[-1] < V          : I = $x->nelem

=item *

if C<$x> is sorted in decreasing order

           V >  x[0]  : I = -1
  x[0]  >= V >= x[-1] : I s.t. x[I] >= V > x[I+1]
  x[-1] >= V          : I = $x->nelem -1

=back

If all elements of C<$x> are equal,

    i = 0

If C<$x> contains duplicated elements, I<I> is the index of the
leftmost (by index in array) duplicate if I<V> matches.

=pod

Broadcasts over its inputs.

=for bad

bad values in vals() result in bad values in idx()

=cut




*vsearch_insert_leftmost = \&PDL::vsearch_insert_leftmost;






=head2 vsearch_insert_rightmost

=for sig

 Signature: (vals(); x(n); indx [o]idx())
 Types: (float double ldouble)

=for ref

Determine the insertion point for values in a sorted array, inserting after duplicates.

=for usage

  $idx = vsearch_insert_rightmost($vals, $x);

C<$x> must be sorted, but may be in decreasing or increasing
order.  if C<$x> is empty, then all values in C<$idx> will be
set to the bad value.

B<vsearch_insert_rightmost> returns an index I<I> for each value I<V> of
C<$vals> equal to the rightmost position (by index in array) within
C<$x> that I<V> may be inserted and still maintain the order in
C<$x>.

Insertion at index I<I> involves shifting elements I<I> and higher of
C<$x> to the right by one and setting the now empty element at index
I<I> to I<V>.

                   

I<I> has the following properties:

=over

=item *

if C<$x> is sorted in increasing order

           V < x[0]  : I = 0
  x[0]  <= V < x[-1] : I s.t. x[I-1] <= V < x[I]
  x[-1] <= V         : I = $x->nelem

=item *

if C<$x> is sorted in decreasing order

          V >= x[0]  : I = -1
  x[0]  > V >= x[-1] : I s.t. x[I] >= V > x[I+1]
  x[-1] > V          : I = $x->nelem -1

=back

If all elements of C<$x> are equal,

    i = $x->nelem - 1

If C<$x> contains duplicated elements, I<I> is the index of the
leftmost (by index in array) duplicate if I<V> matches.

=pod

Broadcasts over its inputs.

=for bad

bad values in vals() result in bad values in idx()

=cut




*vsearch_insert_rightmost = \&PDL::vsearch_insert_rightmost;






=head2 vsearch_match

=for sig

 Signature: (vals(); x(n); indx [o]idx())
 Types: (float double ldouble)

=for ref

Match values against a sorted array.

=for usage

  $idx = vsearch_match($vals, $x);

C<$x> must be sorted, but may be in decreasing or increasing
order.  if C<$x> is empty, then all values in C<$idx> will be
set to the bad value.

B<vsearch_match> returns an index I<I> for each value I<V> of
C<$vals>.  If I<V> matches an element in C<$x>, I<I> is the
index of that element, otherwise it is I<-( insertion_point + 1 )>,
where I<insertion_point> is an index in C<$x> where I<V> may be
inserted while maintaining the order in C<$x>.  If C<$x> has
duplicated values, I<I> may refer to any of them.

                   

=pod

Broadcasts over its inputs.

=for bad

bad values in vals() result in bad values in idx()

=cut




*vsearch_match = \&PDL::vsearch_match;






=head2 vsearch_bin_inclusive

=for sig

 Signature: (vals(); x(n); indx [o]idx())
 Types: (float double ldouble)

=for ref

Determine the index for values in a sorted array of bins, lower bound inclusive.

=for usage

  $idx = vsearch_bin_inclusive($vals, $x);

C<$x> must be sorted, but may be in decreasing or increasing
order.  if C<$x> is empty, then all values in C<$idx> will be
set to the bad value.

C<$x> represents the edges of contiguous bins, with the first and
last elements representing the outer edges of the outer bins, and the
inner elements the shared bin edges.

The lower bound of a bin is inclusive to the bin, its outer bound is exclusive to it.
B<vsearch_bin_inclusive> returns an index I<I> for each value I<V> of C<$vals>

                   

I<I> has the following properties:

=over

=item *

if C<$x> is sorted in increasing order

           V < x[0]  : I = -1
  x[0]  <= V < x[-1] : I s.t. x[I] <= V < x[I+1]
  x[-1] <= V         : I = $x->nelem - 1

=item *

if C<$x> is sorted in decreasing order

           V >= x[0]  : I = 0
  x[0]  >  V >= x[-1] : I s.t. x[I+1] > V >= x[I]
  x[-1] >  V          : I = $x->nelem

=back

If all elements of C<$x> are equal,

    i = $x->nelem - 1

If C<$x> contains duplicated elements, I<I> is the index of the
righmost (by index in array) duplicate if I<V> matches.

=pod

Broadcasts over its inputs.

=for bad

bad values in vals() result in bad values in idx()

=cut




*vsearch_bin_inclusive = \&PDL::vsearch_bin_inclusive;






=head2 vsearch_bin_exclusive

=for sig

 Signature: (vals(); x(n); indx [o]idx())
 Types: (float double ldouble)

=for ref

Determine the index for values in a sorted array of bins, lower bound exclusive.

=for usage

  $idx = vsearch_bin_exclusive($vals, $x);

C<$x> must be sorted, but may be in decreasing or increasing
order.  if C<$x> is empty, then all values in C<$idx> will be
set to the bad value.

C<$x> represents the edges of contiguous bins, with the first and
last elements representing the outer edges of the outer bins, and the
inner elements the shared bin edges.

The lower bound of a bin is exclusive to the bin, its upper bound is inclusive to it.
B<vsearch_bin_exclusive> returns an index I<I> for each value I<V> of C<$vals>.

                   

I<I> has the following properties:

=over

=item *

if C<$x> is sorted in increasing order

           V <= x[0]  : I = -1
  x[0]  <  V <= x[-1] : I s.t. x[I] < V <= x[I+1]
  x[-1] <  V          : I = $x->nelem - 1

=item *

if C<$x> is sorted in decreasing order

           V >  x[0]  : I = 0
  x[0]  >= V >  x[-1] : I s.t. x[I-1] >= V > x[I]
  x[-1] >= V          : I = $x->nelem

=back

If all elements of C<$x> are equal,

    i = $x->nelem - 1

If C<$x> contains duplicated elements, I<I> is the index of the
righmost (by index in array) duplicate if I<V> matches.

=pod

Broadcasts over its inputs.

=for bad

bad values in vals() result in bad values in idx()

=cut




*vsearch_bin_exclusive = \&PDL::vsearch_bin_exclusive;






=head2 interpolate

=for sig

 Signature: (!complex xi(); !complex x(n); y(n); [o] yi(); int [o] err())
 Types: (float ldouble cfloat cdouble cldouble double)

=for usage

 ($yi, $err) = interpolate($xi, $x, $y);
 interpolate($xi, $x, $y, $yi, $err);    # all arguments given
 ($yi, $err) = $xi->interpolate($x, $y); # method call
 $xi->interpolate($x, $y, $yi, $err);

=for ref

routine for 1D linear interpolation

Given a set of points C<($x,$y)>, use linear interpolation
to find the values C<$yi> at a set of points C<$xi>.

C<interpolate> uses a binary search to find the suspects, er...,
interpolation indices and therefore abscissas (ie C<$x>)
have to be I<strictly> ordered (increasing or decreasing).
For interpolation at lots of
closely spaced abscissas an approach that uses the last index found as
a start for the next search can be faster (compare Numerical Recipes
C<hunt> routine). Feel free to implement that on top of the binary
search if you like. For out of bounds values it just does a linear
extrapolation and sets the corresponding element of C<$err> to 1,
which is otherwise 0.

See also L</interpol>, which uses the same routine,
differing only in the handling of extrapolation - an error message
is printed rather than returning an error ndarray.

Note that C<interpolate> can use complex values for C<$y> and C<$yi> but
C<$x> and C<$xi> must be real.

=pod

Broadcasts over its inputs.

=for bad

needs major (?) work to handles bad values

=cut




*interpolate = \&PDL::interpolate;





#line 2987 "lib/PDL/Primitive.pd"

=head2 interpol

=for sig

 Signature: (xi(); x(n); y(n); [o] yi())

=for ref

routine for 1D linear interpolation

=for usage

 $yi = interpol($xi, $x, $y)

C<interpol> uses the same search method as L</interpolate>,
hence C<$x> must be I<strictly> ordered (either increasing or decreasing).
The difference occurs in the handling of out-of-bounds values; here
an error message is printed.

=cut

# kept in for backwards compatibility
sub interpol ($$$;$) {
    my $xi = shift;
    my $x  = shift;
    my $y  = shift;
    my $yi = @_ == 1 ? $_[0] : PDL->null;
    interpolate( $xi, $x, $y, $yi, my $err = PDL->null );
    print "some values had to be extrapolated\n"
	if any $err;
    return $yi if @_ == 0;
} # sub: interpol()
*PDL::interpol = \&interpol;

#line 3025 "lib/PDL/Primitive.pd"

=head2 interpND

=for ref

Interpolate values from an N-D ndarray, with switchable method

=for example

  $source = 10*xvals(10,10) + yvals(10,10);
  $index = pdl([[2.2,3.5],[4.1,5.0]],[[6.0,7.4],[8,9]]);
  print $source->interpND( $index );

InterpND acts like L<indexND|PDL::Slices/indexND>,
collapsing C<$index> by lookup
into C<$source>; but it does interpolation rather than direct sampling.
The interpolation method and boundary condition are switchable via
an options hash.

By default, linear or sample interpolation is used, with constant
value outside the boundaries of the source pdl.  No dataflow occurs,
because in general the output is computed rather than indexed.

All the interpolation methods treat the pixels as value-centered, so
the C<sample> method will return C<< $a->(0) >> for coordinate values on
the set [-0.5,0.5], and all methods will return C<< $a->(1) >> for
a coordinate value of exactly 1.

Recognized options:

=over 3

=item method

Values can be:

=over 3

=item * 0, s, sample, Sample (default for integer source types)

The nearest value is taken. Pixels are regarded as centered on their
respective integer coordinates (no offset from the linear case).

=item * 1, l, linear, Linear (default for floating point source types)

The values are N-linearly interpolated from an N-dimensional cube of size 2.

=item * 3, c, cube, cubic, Cubic

The values are interpolated using a local cubic fit to the data.  The
fit is constrained to match the original data and its derivative at the
data points.  The second derivative of the fit is not continuous at the
data points.  Multidimensional datasets are interpolated by the
successive-collapse method.

(Note that the constraint on the first derivative causes a small amount
of ringing around sudden features such as step functions).

=item * f, fft, fourier, Fourier

The source is Fourier transformed, and the interpolated values are
explicitly calculated from the coefficients.  The boundary condition
option is ignored -- periodic boundaries are imposed.

If you pass in the option "fft", and it is a list (ARRAY) ref, then it
is a stash for the magnitude and phase of the source FFT.  If the list
has two elements then they are taken as already computed; otherwise
they are calculated and put in the stash.

=back

=item b, bound, boundary, Boundary

This option is passed unmodified into L<indexND|PDL::Slices/indexND>,
which is used as the indexing engine for the interpolation.
Some current allowed values are 'extend', 'periodic', 'truncate', and 'mirror'
(default is 'truncate').

=item bad

contains the fill value used for 'truncate' boundary.  (default 0)

=item fft

An array ref whose associated list is used to stash the FFT of the source
data, for the FFT method.

=back

=cut

*interpND = *PDL::interpND;
sub PDL::interpND {
  my $source = shift;
  my $index = shift;
  my $options = shift;

  barf 'Usage: interpND($source,$index[,{%options}])'
    if(defined $options   and    ref $options ne 'HASH');

  my $opt = defined $options ? $options : {};

  my $method = $opt->{m} || $opt->{meth} || $opt->{method} || $opt->{Method};
  $method //= $source->type->integer ? 'sample' : 'linear';

  my $boundary = $opt->{b} || $opt->{boundary} || $opt->{Boundary} || $opt->{bound} || $opt->{Bound} || 'extend';
  my $bad = $opt->{bad} || $opt->{Bad} || 0.0;

  return $source->range(PDL::Math::floor($index+0.5),0,$boundary)
    if $method =~ m/^s(am(p(le)?)?)?/i;

  if (($method eq 1) || $method =~ m/^l(in(ear)?)?/i) {
    ## key: (ith = index broadcast; cth = cube broadcast; sth = source broadcast)
    my $d = $index->dim(0);
    my $di = $index->ndims - 1;

    # Grab a 2-on-a-side n-cube around each desired pixel
    my $samp = $source->range($index->floor,2,$boundary); # (ith, cth, sth)

    # Reorder to put the cube dimensions in front and convert to a list
    $samp = $samp->reorder( $di .. $di+$d-1,
			    0 .. $di-1,
			    $di+$d .. $samp->ndims-1) # (cth, ith, sth)
                  ->clump($d); # (clst, ith, sth)

    # Enumerate the corners of an n-cube and convert to a list
    # (the 'x' is the normal perl repeat operator)
    my $crnr = PDL::Basic::ndcoords( (2) x $index->dim(0) ) # (index,cth)
             ->mv(0,-1)->clump($index->dim(0))->mv(-1,0); # (index, clst)
    # a & b are the weighting coefficients.
    my($x,$y);
    $index->where( 0 * $index ) .= -10; # Change NaN to invalid
    {
      my $bb = PDL::Math::floor($index);
      $x = ($index - $bb)     -> dummy(1,$crnr->dim(1)); # index, clst, ith
      $y = ($bb + 1 - $index) -> dummy(1,$crnr->dim(1)); # index, clst, ith
    }

    # Use 1/0 corners to select which multiplier happens, multiply
    # 'em all together to get sample weights, and sum to get the answer.
    my $out0 =  ( ($x * ($crnr==1) + $y * ($crnr==0)) #index, clst, ith
		 -> prodover                          #clst, ith
		 );

    my $out = ($out0 * $samp)->sumover; # ith, sth

    # Work around BAD-not-being-contagious bug in PDL <= 2.6 bad handling code  --CED 3-April-2013
    if ($source->badflag) {
	my $baddies = $samp->isbad->orover;
	$out = $out->setbadif($baddies);
    }

    $out = $out->convert($source->type->enum) if $out->type != $source->type;
    return $out;

  } elsif(($method eq 3) || $method =~ m/^c(u(b(e|ic)?)?)?/i) {

      my ($d,@di) = $index->dims;
      my $di = $index->ndims - 1;

      # Grab a 4-on-a-side n-cube around each desired pixel
      my $samp = $source->range($index->floor - 1,4,$boundary) #ith, cth, sth
	  ->reorder( $di .. $di+$d-1, 0..$di-1, $di+$d .. $source->ndims-1 );
	                   # (cth, ith, sth)

      # Make a cube of the subpixel offsets, and expand its dims to
      # a 4-on-a-side N-1 cube, to match the slices of $samp (used below).
      my $y = $index - $index->floor;
      for my $i(1..$d-1) {
	  $y = $y->dummy($i,4);
      }

      # Collapse by interpolation, one dimension at a time...
      for my $i(0..$d-1) {
	  my $a0 = $samp->slice("(1)");    # Just-under-sample
	  my $a1 = $samp->slice("(2)");    # Just-over-sample
	  my $a1a0 = $a1 - $a0;

	  my $gradient = 0.5 * ($samp->slice("2:3")-$samp->slice("0:1"));
	  my $s0 = $gradient->slice("(0)");   # Just-under-gradient
	  my $s1 = $gradient->slice("(1)");   # Just-over-gradient

	  my $bb = $y->slice("($i)");

	  # Collapse the sample...
	  $samp = ( $a0 +
		    $bb * (
			   $s0  +
			   $bb * ( (3 * $a1a0 - 2*$s0 - $s1) +
				   $bb * ( $s1 + $s0 - 2*$a1a0 )
				   )
			   )
		    );

	  # "Collapse" the subpixel offset...
	  $y = $y->slice(":,($i)");
      }

      $samp = $samp->convert($source->type->enum) if $samp->type != $source->type;
      return $samp;

  } elsif($method =~ m/^f(ft|ourier)?/i) {

     require PDL::FFT;
     my $fftref = $opt->{fft};
     $fftref = [] unless(ref $fftref eq 'ARRAY');
     if(@$fftref != 2) {
	 my $x = $source->copy;
	 my $y = zeroes($source);
	 PDL::FFT::fftnd($x,$y);
	 $fftref->[0] = sqrt($x*$x+$y*$y) / $x->nelem;
	 $fftref->[1] = - atan2($y,$x);
     }

     my $i;
     my $c = PDL::Basic::ndcoords($source);               # (dim, source-dims)
     for $i(1..$index->ndims-1) {
	 $c = $c->dummy($i,$index->dim($i))
     }
     my $id = $index->ndims-1;
     my $phase = (($c * $index * 3.14159 * 2 / pdl($source->dims))
		  ->sumover) # (index-dims, source-dims)
 	          ->reorder($id..$id+$source->ndims-1,0..$id-1); # (src, index)

     my $phref = $fftref->[1]->copy;        # (source-dims)
     my $mag = $fftref->[0]->copy;          # (source-dims)

     for $i(1..$index->ndims-1) {
	 $phref = $phref->dummy(-1,$index->dim($i));
	 $mag = $mag->dummy(-1,$index->dim($i));
     }
     my $out = cos($phase + $phref ) * $mag;
     $out = $out->clump($source->ndims)->sumover;
     $out = $out->convert($source->type->enum) if $out->type != $source->type;
     return $out;
 }  else {
     barf("interpND: unknown method '$method'; valid ones are 'linear' and 'sample'.\n");
 }
}

#line 3272 "lib/PDL/Primitive.pd"

=head2 one2nd

=for ref

Converts a one dimensional index ndarray to a set of ND coordinates

=for usage

 @coords=one2nd($x, $indices)

returns an array of ndarrays containing the ND indexes corresponding to
the one dimensional list indices. The indices are assumed to
correspond to array C<$x> clumped using C<clump(-1)>. This routine is
used in the old vector form of L</whichND>, but is useful on
its own occasionally.

Returned ndarrays have the L<indx|PDL::Core/indx> datatype.  C<$indices> can have
values larger than C<< $x->nelem >> but negative values in C<$indices>
will not give the answer you expect.

=for example

 pdl> $x=pdl [[[1,2],[-1,1]], [[0,-3],[3,2]]]; $c=$x->clump(-1)
 pdl> $maxind=maximum_ind($c); p $maxind;
 6
 pdl> print one2nd($x, maximum_ind($c))
 0 1 1
 pdl> p $x->at(0,1,1)
 3

=cut

*one2nd = \&PDL::one2nd;
sub PDL::one2nd {
  barf "Usage: one2nd \$array, \$indices\n" if @_ != 2;
  my ($x, $ind)=@_;
  my @dimension=$x->dims;
  $ind = indx($ind);
  my(@index);
  my $count=0;
  foreach (@dimension) {
    $index[$count++]=$ind % $_;
    $ind /= $_;
  }
  return @index;
}
#line 3648 "lib/PDL/Primitive.pm"


=head2 which

=for sig

 Signature: (mask(n); indx [o] inds(n); indx [o]lastout())
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble cfloat cdouble cldouble)

=for ref

Returns indices of non-zero values from a 1-D PDL

=for usage

 $i = which($mask);

returns a pdl with indices for all those elements that are nonzero in
the mask. Note that the returned indices will be 1D. If you feed in a
multidimensional mask, it will be flattened before the indices are
calculated.  See also L</whichND> for multidimensional masks.

If you want to index into the original mask or a similar ndarray
with output from C<which>, remember to flatten it before calling index:

  $data = random 5, 5;
  $idx = which $data > 0.5; # $idx is now 1D
  $bigsum = $data->flat->index($idx)->sum;  # flatten before indexing

Compare also L</where> for similar functionality.

SEE ALSO:

L</which_both> returns separately the indices of both nonzero and zero
values in the mask.

L</where_both> returns separately slices of both nonzero and zero
values in the mask.

L</where> returns associated values from a data PDL, rather than
indices into the mask PDL.

L</whichND> returns N-D indices into a multidimensional PDL.

=for example

 pdl> $x = sequence(10); p $x
 [0 1 2 3 4 5 6 7 8 9]
 pdl> $indx = which($x>6); p $indx
 [7 8 9]

=pod

Broadcasts over its inputs.

=for bad

C<which> processes bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut





#line 3405 "lib/PDL/Primitive.pd"
   sub which { my ($this,$out) = @_;
		$this = $this->flat;
		$out //= $this->nullcreate;
		PDL::_which_int($this,$out,my $lastout = $this->nullcreate);
		my $lastoutmax = $lastout->max->sclr;
		$lastoutmax ? $out->slice('0:'.($lastoutmax-1))->sever : empty(indx);
   }
   *PDL::which = \&which;
#line 3725 "lib/PDL/Primitive.pm"

*which = \&PDL::which;






=head2 which_both

=for sig

 Signature: (mask(n); indx [o] inds(n); indx [o]notinds(n); indx [o]lastout(); indx [o]lastoutn())
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble cfloat cdouble cldouble)

=for ref

Returns indices of nonzero and zero values in a mask PDL

=for usage

 ($i, $c_i) = which_both($mask);

This works just as L</which>, but the complement of C<$i> will be in
C<$c_i>.

=for example

 pdl> p $x = sequence(10)
 [0 1 2 3 4 5 6 7 8 9]
 pdl> ($big, $small) = which_both($x >= 5); p "$big\n$small"
 [5 6 7 8 9]
 [0 1 2 3 4]

See also L</whichND_both> for the n-dimensional version.

=pod

Broadcasts over its inputs.

=for bad

C<which_both> processes bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut





#line 3422 "lib/PDL/Primitive.pd"
   sub which_both { my ($this,$outi,$outni) = @_;
		$this = $this->flat;
		$outi //= $this->nullcreate;
		$outni //= $this->nullcreate;
		PDL::_which_both_int($this,$outi,$outni,my $lastout = $this->nullcreate,my $lastoutn = $this->nullcreate);
		my $lastoutmax = $lastout->max->sclr;
		$outi = $lastoutmax ? $outi->slice('0:'.($lastoutmax-1))->sever : empty(indx);
		return $outi if !wantarray;
		my $lastoutnmax = $lastoutn->max->sclr;
		($outi, $lastoutnmax ? $outni->slice('0:'.($lastoutnmax-1))->sever : empty(indx));
   }
   *PDL::which_both = \&which_both;
#line 3791 "lib/PDL/Primitive.pm"

*which_both = \&PDL::which_both;






=head2 whichover

=for sig

 Signature: (a(n); [o]o(n))
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble cfloat cdouble cldouble)

=for usage

 $o = whichover($a);
 whichover($a, $o);      # all arguments given
 $o = $a->whichover;     # method call
 $a->whichover($o);
 $a->inplace->whichover; # can be used inplace
 whichover($a->inplace);

=for ref

Collects the coordinates of non-zero, non-bad values in each 1D mask in
ndarray at the start of the output, and fills the rest with -1.

By using L<PDL::Slices/xchg> etc. it is possible to use I<any> dimension.

=for example

  my $a = pdl q[3 4 2 3 2 3 1];
  my $b = $a->uniq;
  my $c = +($a->dummy(0) == $b)->transpose;
  print $c, $c->whichover;
  # [
  #  [0 0 0 0 0 0 1]
  #  [0 0 1 0 1 0 0]
  #  [1 0 0 1 0 1 0]
  #  [0 1 0 0 0 0 0]
  # ]
  # [
  #  [ 6 -1 -1 -1 -1 -1 -1]
  #  [ 2  4 -1 -1 -1 -1 -1]
  #  [ 0  3  5 -1 -1 -1 -1]
  #  [ 1 -1 -1 -1 -1 -1 -1]
  # ]

=pod

Broadcasts over its inputs.

=for bad

C<whichover> processes bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*whichover = \&PDL::whichover;






=head2 approx_artol

=for sig

 Signature: (got(); expected(); sbyte [o] result(); double atol; double rtol)
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble cfloat cdouble cldouble)

=for usage

 $result = approx_artol($got, $expected);               # using defaults of atol=1e-06, rtol=0
 $result = approx_artol($got, $expected, $atol);
 $result = approx_artol($got, $expected, $atol, $rtol);
 approx_artol($got, $expected, $atol, $rtol, $result);  # all arguments given
 $result = $got->approx_artol($expected);               # method call
 $result = $got->approx_artol($expected, $atol);
 $result = $got->approx_artol($expected, $atol, $rtol);
 $got->approx_artol($expected, $atol, $rtol, $result);

=for ref

Returns C<sbyte> mask whether C<< abs($got()-$expected())> <= >> either
absolute or relative (C<rtol> * C<$expected()>) tolerances.

Relative tolerance defaults to zero, and absolute tolerance defaults to
C<1e-6>, for compatibility with L<PDL::Core/approx>.

Works with complex numbers, and to avoid expensive C<sqrt>ing uses the
squares of the input quantities and differences. Bear this in mind for
numbers outside the range (for C<double>) of about C<1e-154..1e154>.

Handles C<NaN>s by showing them approximately equal (i.e. true in the
output) if both values are C<NaN>, and not otherwise.

Adapted from code by Edward Baudrez, test changed from C<< < >> to C<< <= >>.

=pod

Broadcasts over its inputs.

=for bad

Handles bad values similarly to C<NaN>s, above. This includes if only
one of the two input ndarrays has their badflag true.

=cut




*approx_artol = \&PDL::approx_artol;





#line 3554 "lib/PDL/Primitive.pd"

=head2 where

=for ref

Use a mask to select values from one or more data PDLs

C<where> accepts one or more data ndarrays and a mask ndarray.  It
returns a list of output ndarrays, corresponding to the input data
ndarrays.  Each output ndarray is a 1-dimensional list of values in its
corresponding data ndarray. The values are drawn from locations where
the mask is nonzero.

The output PDLs are still connected to the original data PDLs, for the
purpose of dataflow.

C<where> combines the functionality of L</which> and L<index|PDL::Slices/index>
into a single operation.

BUGS:

While C<where> works OK for most N-dimensional cases, it does not
broadcast properly over (for example) the (N+1)th dimension in data
that is compared to an N-dimensional mask.  Use C<whereND> for that.

=for example

 $i = $x->where($x+5 > 0); # $i contains those elements of $x
                           # where mask ($x+5 > 0) is 1
 $i .= -5;  # Set those elements (of $x) to -5. Together, these
            # commands clamp $x to a maximum of -5.

It is also possible to use the same mask for several ndarrays with
the same call:

 ($i,$j,$k) = where($x,$y,$z, $x+5>0);

Note: C<$i> is always 1-D, even if C<$x> is E<gt>1-D.

WARNING: The first argument
(the values) and the second argument (the mask) currently have to have
the exact same dimensions (or horrible things happen). You *cannot*
broadcast over a smaller mask, for example.

=cut

sub PDL::where :lvalue {
  barf "Usage: where( \$pdl1, ..., \$pdlN, \$mask )\n" if @_ == 1;
  my $mask = pop->flat->which;
  @_ == 1 ? $_[0]->flat->index($mask) : map $_->flat->index($mask), @_;
}
*where = \&PDL::where;

#line 3610 "lib/PDL/Primitive.pd"

=head2 where_both

=for ref

Returns slices (non-zero in mask, zero) of an ndarray according to a mask

=for usage

 ($match_vals, $non_match_vals) = where_both($pdl, $mask);

This works like L</which_both>, but (flattened) data-flowing slices
rather than index-sets are returned.

=for example

 pdl> p $x = sequence(10) + 2
 [2 3 4 5 6 7 8 9 10 11]
 pdl> ($big, $small) = where_both($x, $x > 5); p "$big\n$small"
 [6 7 8 9 10 11]
 [2 3 4 5]
 pdl> p $big += 2, $small -= 1
 [8 9 10 11 12 13] [1 2 3 4]
 pdl> p $x
 [1 2 3 4 8 9 10 11 12 13]

=cut

sub PDL::where_both {
  barf "Usage: where_both(\$pdl, \$mask)\n" if @_ != 2;
  my ($arr, $mask) = @_;  # $mask has 0==false, 1==true
  my $arr_flat = $arr->flat;
  map $arr_flat->index1d($_), PDL::which_both($mask);
}
*where_both = \&PDL::where_both;

#line 3648 "lib/PDL/Primitive.pd"

=head2 whereND

=for ref

C<where> with support for ND masks and broadcasting

C<whereND> accepts one or more data ndarrays and a
mask ndarray.  It returns a list of output ndarrays,
corresponding to the input data ndarrays.  The values
are drawn from locations where the mask is nonzero.

C<whereND> differs from C<where> in that the mask
dimensionality is preserved which allows for
proper broadcasting of the selection operation over
higher dimensions.

As with C<where> the output PDLs are still connected
to the original data PDLs, for the purpose of dataflow.

=for usage

  $sdata = whereND $data, $mask
  ($s1, $s2, ..., $sn) = whereND $d1, $d2, ..., $dn, $mask

where

    $data is M dimensional
    $mask is N < M dimensional
    dims($data) 1..N == dims($mask) 1..N
    with broadcasting over N+1 to M dimensions

=for example

  $data   = sequence(4,3,2);   # example data array
  $mask4  = (random(4)>0.5);   # example 1-D mask array, has $n4 true values
  $mask43 = (random(4,3)>0.5); # example 2-D mask array, has $n43 true values
  $sdat4  = whereND $data, $mask4;   # $sdat4 is a [$n4,3,2] pdl
  $sdat43 = whereND $data, $mask43;  # $sdat43 is a [$n43,2] pdl

Just as with C<where>, you can use the returned value in an
assignment. That means that both of these examples are valid:

  # Used to create a new slice stored in $sdat4:
  $sdat4 = $data->whereND($mask4);
  $sdat4 .= 0;
  # Used in lvalue context:
  $data->whereND($mask4) .= 0;

SEE ALSO:

L</whichND> returns N-D indices into a multidimensional PDL, from a mask.

=cut

sub PDL::whereND :lvalue {
   barf "Usage: whereND( \$pdl1, ..., \$pdlN, \$mask )\n" if @_ == 1;
   my $mask = pop @_;  # $mask has 0==false, 1==true
   my @to_return;
   my $n = PDL::sum($mask);
   my $maskndims = $mask->ndims;
   foreach my $arr (@_) {
      # count the number of dims in $mask and $arr
      # $mask = a b c d e f.....
      my @idims = dims($arr);
      splice @idims, 0, $maskndims; # pop off the number of dims in $mask
      if (!$n or $arr->isempty) {
        push @to_return, PDL->zeroes($arr->type, $n, @idims);
        next;
      }
      my $sub_i = $mask * ones($arr);
      my $where_sub_i = PDL::where($arr, $sub_i);
      my $ndim = 0;
      foreach my $id ($n, @idims[0..($#idims-1)]) {
         $where_sub_i = $where_sub_i->splitdim($ndim++,$id) if $n>0;
      }
      push @to_return, $where_sub_i;
   }
   return (@to_return == 1) ? $to_return[0] : @to_return;
}
*whereND = \&PDL::whereND;

=head2 whereND_both

=for ref

C<where_both> with support for ND masks and broadcasting

This works like L</whichND_both>, but data-flowing slices
rather than index-sets are returned.

C<whereND_both> differs from C<where_both> in that the mask
dimensionality is preserved which allows for
proper broadcasting of the selection operation over
higher dimensions.

As with C<where_both> the output PDLs are still connected
to the original data PDLs, for the purpose of dataflow.

=for usage

 ($match_vals, $non_match_vals) = whereND_both($pdl, $mask);

=cut

sub PDL::whereND_both :lvalue {
  barf "Usage: whereND_both(\$pdl, \$mask)\n" if @_ != 2;
  my ($arr, $mask) = @_;  # $mask has 0==false, 1==true
  map $arr->indexND($_), PDL::whichND_both($mask);
}
*whereND_both = \&PDL::whereND_both;

#line 3762 "lib/PDL/Primitive.pd"

=head2 whichND

=for ref

Return the coordinates of non-zero values in a mask.

=for usage

WhichND returns the N-dimensional coordinates of each nonzero value in
a mask PDL with any number of dimensions.  The returned values arrive
as an array-of-vectors suitable for use in
L<indexND|PDL::Slices/indexND> or L<range|PDL::Slices/range>.

 $coords = whichND($mask);

returns a PDL containing the coordinates of the elements that are non-zero
in C<$mask>, suitable for use in L<PDL::Slices/indexND>. The 0th dimension contains the
full coordinate listing of each point; the 1st dimension lists all the points.
For example, if $mask has rank 4 and 100 matching elements, then $coords has
dimension 4x100.

If no such elements exist, then whichND returns a structured empty PDL:
an Nx0 PDL that contains no values (but matches, broadcasting-wise, with
the vectors that would be produced if such elements existed).

DEPRECATED BEHAVIOR IN LIST CONTEXT:

whichND once delivered different values in list context than in scalar
context, for historical reasons.  In list context, it returned the
coordinates transposed, as a collection of 1-PDLs (one per dimension)
in a list.  This usage is deprecated in PDL 2.4.10, and will cause a
warning to be issued every time it is encountered.  To avoid the
warning, you can set the global variable "$PDL::whichND" to 's' to
get scalar behavior in all contexts, or to 'l' to get list behavior in
list context.

In later versions of PDL, the deprecated behavior will disappear.  Deprecated
list context whichND expressions can be replaced with:

    @list = $x->whichND->mv(0,-1)->dog;

SEE ALSO:

L</which> finds coordinates of nonzero values in a 1-D mask.

L</where> extracts values from a data PDL that are associated
with nonzero values in a mask PDL.

L<PDL::Slices/indexND> can be fed the coordinates to return the values.

=for example

 pdl> $s=sequence(10,10,3,4)
 pdl> ($x, $y, $z, $w)=whichND($s == 203); p $x, $y, $z, $w
 [3] [0] [2] [0]
 pdl> print $s->at(list(cat($x,$y,$z,$w)))
 203

=cut

sub _one2nd {
  my ($mask, $ind) = @_;
  my $ndims = my @mdims = $mask->dims;
  # In the empty case, explicitly return the correct type of structured empty
  return PDL->new_from_specification(indx, $ndims, 0) if !$ind->nelem;
  my $mult = ones(indx, $ndims);
  $mult->index($_+1) .= $mult->index($_) * $mdims[$_] for 0..$#mdims-1;
  for my $i (0..$#mdims) {
    my $s = $ind->index($i);
    $s /= $mult->index($i);
    $s %= $mdims[$i];
  }
  $ind;
}

*whichND = \&PDL::whichND;
sub PDL::whichND {
  my $mask = PDL->topdl(shift);

  # List context: generate a perl list by dimension
  if(wantarray) {
      if(!defined($PDL::whichND)) {
	  printf STDERR "whichND: WARNING - list context deprecated. Set \$PDL::whichND. Details in pod.";
      } elsif($PDL::whichND =~ m/l/i) {
	  # old list context enabled by setting $PDL::whichND to 'l'
	  return $mask->one2nd($mask->flat->which);
      }
      # if $PDL::whichND does not contain 'l' or 'L', fall through to scalar context
  }

  # Scalar context: generate an N-D index ndarray
  my $ndims = $mask->getndims;
  return PDL->new_from_specification(indx,$ndims,0) if !$mask->nelem;
  return $mask ? pdl(indx,0) : PDL->new_from_specification(indx,0) if !$ndims;
  _one2nd($mask, $mask->flat->which->dummy(0,$ndims)->sever);
}

=head2 whichND_both

=for ref

Return the coordinates of non-zero values in a mask.

=for usage

Like L</which_both>, but returns the N-dimensional coordinates (like
L</whichND>) of the nonzero, zero values in the mask PDL. The
returned values arrive as an array-of-vectors suitable for use in
L<indexND|PDL::Slices/indexND> or L<range|PDL::Slices/range>.
Added in 2.099.

 ($nonzero_coords, $zero_coords) = whichND_both($mask);

SEE ALSO:

L</which> finds coordinates of nonzero values in a 1-D mask.

L</where> extracts values from a data PDL that are associated
with nonzero values in a mask PDL.

L<PDL::Slices/indexND> can be fed the coordinates to return the values.

=for example

 pdl> $s=sequence(10,10,3,4)
 pdl> ($x, $y, $z, $w)=whichND($s == 203); p $x, $y, $z, $w
 [3] [0] [2] [0]
 pdl> print $s->at(list(cat($x,$y,$z,$w)))
 203

=cut

*whichND_both = \&PDL::whichND_both;
sub PDL::whichND_both {
  my $mask = PDL->topdl(shift);
  return ((PDL->new_from_specification(indx,$mask->ndims,0))x2) if !$mask->nelem;
  my $ndims = $mask->getndims;
  if (!$ndims) {
    my ($t, $f) = (pdl(indx,0), PDL->new_from_specification(indx,0));
    return $mask ? ($t,$f) : ($f,$t);
  }
  map _one2nd($mask, $_->dummy(0,$ndims)->sever), $mask->flat->which_both;
}

#line 3913 "lib/PDL/Primitive.pd"

=head2 setops

=for ref

Implements simple set operations like union and intersection

=for usage

   Usage: $set = setops($x, <OPERATOR>, $y);

The operator can be C<OR>, C<XOR> or C<AND>. This is then applied
to C<$x> viewed as a set and C<$y> viewed as a set. Set theory says
that a set may not have two or more identical elements, but setops
takes care of this for you, so C<$x=pdl(1,1,2)> is OK. The functioning
is as follows:

=over

=item C<OR>

The resulting vector will contain the elements that are either in C<$x>
I<or> in C<$y> or both. This is the union in set operation terms

=item C<XOR>

The resulting vector will contain the elements that are either in C<$x>
or C<$y>, but not in both. This is

     Union($x, $y) - Intersection($x, $y)

in set operation terms.

=item C<AND>

The resulting vector will contain the intersection of C<$x> and C<$y>, so
the elements that are in both C<$x> and C<$y>. Note that for convenience
this operation is also aliased to L</intersect>.

=back

It should be emphasized that these routines are used when one or both of
the sets C<$x>, C<$y> are hard to calculate or that you get from a separate
subroutine.

Finally IDL users might be familiar with Craig Markwardt's C<cmset_op.pro>
routine which has inspired this routine although it was written independently
However the present routine has a few less options (but see the examples)

=for example

You will very often use these functions on an index vector, so that is
what we will show here. We will in fact something slightly silly. First
we will find all squares that are also cubes below 10000.

Create a sequence vector:

  pdl> $x = sequence(10000)

Find all odd and even elements:

  pdl> ($even, $odd) = which_both( ($x % 2) == 0)

Find all squares

  pdl> $squares= which(ceil(sqrt($x)) == floor(sqrt($x)))

Find all cubes (being careful with roundoff error!)

  pdl> $cubes= which(ceil($x**(1.0/3.0)) == floor($x**(1.0/3.0)+1e-6))

Then find all squares that are cubes:

  pdl> $both = setops($squares, 'AND', $cubes)

And print these (assumes that C<PDL::NiceSlice> is loaded!)

  pdl> p $x($both)
   [0 1 64 729 4096]

Then find all numbers that are either cubes or squares, but not both:

  pdl> $cube_xor_square = setops($squares, 'XOR', $cubes)

  pdl> p $cube_xor_square->nelem()
   112

So there are a total of 112 of these!

Finally find all odd squares:

  pdl> $odd_squares = setops($squares, 'AND', $odd)

Another common occurrence is to want to get all objects that are
in C<$x> and in the complement of C<$y>. But it is almost always best
to create the complement explicitly since the universe that both are
taken from is not known. Thus use L</which_both> if possible
to keep track of complements.

If this is impossible the best approach is to make a temporary:

This creates an index vector the size of the universe of the sets and
set all elements in C<$y> to 0

  pdl> $tmp = ones($n_universe); $tmp($y) .= 0;

This then finds the complement of C<$y>

  pdl> $C_b = which($tmp == 1);

and this does the final selection:

  pdl> $set = setops($x, 'AND', $C_b)

=cut

*setops = \&PDL::setops;

sub PDL::setops {

  my ($x, $op, $y)=@_;

  # Check that $x and $y are 1D.
  if ($x->ndims() > 1 || $y->ndims() > 1) {
     warn 'setops: $x and $y must be 1D - flattening them!'."\n";
     $x = $x->flat;
     $y = $y->flat;
  }

  #Make sure there are no duplicate elements.
  $x=$x->uniq;
  $y=$y->uniq;

  my $result;

  if ($op eq 'OR') {
    # Easy...
    $result = uniq(append($x, $y));
  } elsif ($op eq 'XOR') {
    # Make ordered list of set union.
    my $union = append($x, $y)->qsort;
    # Index lists.
    my $s1=zeroes(byte, $union->nelem());
    my $s2=zeroes(byte, $union->nelem());

    # Find indices which are duplicated - these are to be excluded
    #
    # We do this by comparing x with x shifted each way.
    my $i1 = which($union != rotate($union, 1));
    my $i2 = which($union != rotate($union, -1));
    #
    # We then mark/mask these in the s1 and s2 arrays to indicate which ones
    # are not equal to their neighbours.
    #
    my $ts;
    ($ts = $s1->index($i1)) .= byte(1) if $i1->nelem() > 0;
    ($ts = $s2->index($i2)) .= byte(1) if $i2->nelem() > 0;

    my $inds=which($s1 == $s2);

    if ($inds->nelem() > 0) {
      return $union->index($inds);
    } else {
      return $inds;
    }

  } elsif ($op eq 'AND') {
    # The intersection of the arrays.
    return $x if $x->isempty;
    return $y if $y->isempty;
    # Make ordered list of set union.
    my $union = append($x, $y)->qsort;
    return $union->where($union == rotate($union, -1))->uniq;
  } else {
    print "The operation $op is not known!";
    return -1;
  }

}

#line 4096 "lib/PDL/Primitive.pd"

=head2 intersect

=for ref

Calculate the intersection of two ndarrays

=for usage

   Usage: $set = intersect($x, $y);

This routine is merely a simple interface to L</setops>. See
that for more information

=for example

Find all numbers less that 100 that are of the form 2*y and 3*x

 pdl> $x=sequence(100)
 pdl> $factor2 = which( ($x % 2) == 0)
 pdl> $factor3 = which( ($x % 3) == 0)
 pdl> $ii=intersect($factor2, $factor3)
 pdl> p $x($ii)
 [0 6 12 18 24 30 36 42 48 54 60 66 72 78 84 90 96]

=cut

*intersect = \&PDL::intersect;

sub PDL::intersect { setops($_[0], 'AND', $_[1]) }
#line 4482 "lib/PDL/Primitive.pm"


=head2 pchip_chim

=for sig

 Signature: (x(n); f(n); [o]d(n); indx [o]ierr())
 Types: (sbyte byte short ushort long ulong indx ulonglong longlong
   float double ldouble)

=for usage

 ($d, $ierr) = pchip_chim($x, $f);
 pchip_chim($x, $f, $d, $ierr);    # all arguments given
 ($d, $ierr) = $x->pchip_chim($f); # method call
 $x->pchip_chim($f, $d, $ierr);

=for ref

Calculate the derivatives of (x,f(x)) using cubic Hermite interpolation.

Calculate the derivatives needed to determine a monotone piecewise
cubic Hermite interpolant to the given set of points (C<$x,$f>,
where C<$x> is strictly increasing).
The resulting set of points - C<$x,$f,$d>, referred to
as the cubic Hermite representation - can then be used in
other functions, such as L</pchip_chfe>, L</pchip_chfd>,
and L</pchip_chia>.

The boundary conditions are compatible with monotonicity,
and if the data are only piecewise monotonic, the interpolant
will have an extremum at the switch points; for more control
over these issues use L</pchip_chic>.

References:

1. F. N. Fritsch and J. Butland, A method for constructing
local monotone piecewise cubic interpolants, SIAM
Journal on Scientific and Statistical Computing 5, 2
(June 1984), pp. 300-304.

F. N. Fritsch and R. E. Carlson, Monotone piecewise
cubic interpolation, SIAM Journal on Numerical Analysis
17, 2 (April 1980), pp. 238-246.

=pod

=head3 Parameters

=over

=item x

ordinate data

=item f

array of dependent variable values to be
interpolated. F(I) is value corresponding to
X(I). C<pchip_chim> is designed for monotonic data, but it will
work for any F-array.  It will force extrema at points where
monotonicity switches direction. If some other treatment of
switch points is desired, DPCHIC should be used instead.

=item d

array of derivative values at the data
points.  If the data are monotonic, these values will
determine a monotone cubic Hermite function.

=item ierr

Error status:

=over

=item *

0 if successful.

=item *

E<gt> 0 if there were C<ierr> switches in the direction of
monotonicity (data still valid).

=item *

-1 if C<dim($x, 0) E<lt> 2>.

=item *

-3 if C<$x> is not strictly increasing.

=back

(The D-array has not been changed in any of these cases.)
NOTE: The above errors are checked in the order listed,
and following arguments have B<NOT> been validated.

=back

Broadcasts over its inputs.

=for bad

C<pchip_chim> does not process bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*pchip_chim = \&PDL::pchip_chim;






=head2 pchip_chic

=for sig

 Signature: (sbyte ic(two=2); vc(two=2); mflag(); x(n); f(n);
    [o]d(n); indx [o]ierr();
    [t]h(nless1=CALC($SIZE(n)-1)); [t]slope(nless1);)
 Types: (float double ldouble)

=for usage

 ($d, $ierr) = pchip_chic($ic, $vc, $mflag, $x, $f);
 pchip_chic($ic, $vc, $mflag, $x, $f, $d, $ierr);    # all arguments given
 ($d, $ierr) = $ic->pchip_chic($vc, $mflag, $x, $f); # method call
 $ic->pchip_chic($vc, $mflag, $x, $f, $d, $ierr);

=for ref

Set derivatives needed to determine a piecewise monotone piecewise
cubic Hermite interpolant to given data. User control is available
over boundary conditions and/or treatment of points where monotonicity
switches direction.

Calculate the derivatives needed to determine a piecewise monotone piecewise
cubic interpolant to the data given in (C<$x,$f>,
where C<$x> is strictly increasing).
Control over the boundary conditions is given by the
C<$ic> and C<$vc> ndarrays, and the value of C<$mflag> determines
the treatment of points where monotonicity switches
direction. A simpler, more restricted, interface is available
using L</pchip_chim>.
The resulting piecewise cubic Hermite function may be evaluated
by L</pchip_chfe> or L</pchip_chfd>.

References:

1. F. N. Fritsch, Piecewise Cubic Hermite Interpolation
Package, Report UCRL-87285, Lawrence Livermore National
Laboratory, July 1982.  [Poster presented at the
SIAM 30th Anniversary Meeting, 19-23 July 1982.]

2. F. N. Fritsch and J. Butland, A method for constructing
local monotone piecewise cubic interpolants, SIAM
Journal on Scientific and Statistical Computing 5, 2
(June 1984), pp. 300-304.

3. F. N. Fritsch and R. E. Carlson, Monotone piecewise
cubic interpolation, SIAM Journal on Numerical
Analysis 17, 2 (April 1980), pp. 238-246.

=pod

=head3 Parameters

=over

=item ic

The first and second elements of C<$ic> determine the boundary
conditions at the start and end of the data respectively.
If the value is 0, then the default condition, as used by
L</pchip_chim>, is adopted.
If greater than zero, no adjustment for monotonicity is made,
otherwise if less than zero the derivative will be adjusted.
The allowed magnitudes for C<ic(0)> are:

=over

=item *

1 if first derivative at C<x(0)> is given in C<vc(0)>.

=item *

2 if second derivative at C<x(0)> is given in C<vc(0)>.

=item *

3 to use the 3-point difference formula for C<d(0)>.
(Reverts to the default b.c. if C<n E<lt> 3>)

=item *

4 to use the 4-point difference formula for C<d(0)>.
(Reverts to the default b.c. if C<n E<lt> 4>)

=item *

5 to set C<d(0)> so that the second derivative is
continuous at C<x(1)>.
(Reverts to the default b.c. if C<n E<lt> 4>)
This option is somewhat analogous to the "not a knot"
boundary condition provided by DPCHSP.

=back

The values for C<ic(1)> are the same as above, except that
the first-derivative value is stored in C<vc(1)> for cases 1 and 2.
The values of C<$vc> need only be set if options 1 or 2 are chosen
for C<$ic>. NOTES:

=over

=item *

Only in case C<$ic(n)> E<lt> 0 is it guaranteed that the interpolant
will be monotonic in the first interval. If the returned value of
D(start_or_end) lies between zero and 3*SLOPE(start_or_end), the
interpolant will be monotonic. This is B<NOT> checked if C<$ic(n)>
E<gt> 0.

=item *

If C<$ic(n)> E<lt> 0 and D(0) had to be changed to achieve monotonicity,
a warning error is returned.

=back

Set C<$mflag = 0> if interpolant is required to be monotonic in
each interval, regardless of monotonicity of data. This causes C<$d> to be
set to 0 at all switch points. NOTES:

=over

=item *

This will cause D to be set to zero at all switch points, thus
forcing extrema there.

=item *

The result of using this option with the default boundary conditions
will be identical to using DPCHIM, but will generally cost more
compute time. This option is provided only to facilitate comparison
of different switch and/or boundary conditions.

=back

=item vc

See ic for details

=item mflag

Set to non-zero to
use a formula based on the 3-point difference formula at switch
points. If C<$mflag E<gt> 0>, then the interpolant at switch points
is forced to not deviate from the data by more than C<$mflag*dfloc>,
where C<dfloc> is the maximum of the change of C<$f> on this interval
and its two immediate neighbours.
If C<$mflag E<lt> 0>, no such control is to be imposed.

=item x

array of independent variable values.  The
elements of X must be strictly increasing:

           X(I-1) .LT. X(I),  I = 2(1)N.

(Error return if not.)

=item f

array of dependent variable values to be
interpolated. F(I) is value corresponding to X(I).

=item d

array of derivative values at the data
points. These values will determine a monotone cubic
Hermite function on each subinterval on which the data
are monotonic, except possibly adjacent to switches in
monotonicity. The value corresponding to X(I) is stored in D(I).
No other entries in D are changed.

=item ierr

Error status:

=over

=item *

0 if successful.

=item *

1 if C<ic(0) E<lt> 0> and C<d(0)> had to be adjusted for
monotonicity.

=item *

2 if C<ic(1) E<lt> 0> and C<d(n-1)> had to be adjusted
for monotonicity.

=item *

3 if both 1 and 2 are true.

=item *

-1 if C<n E<lt> 2>.

=item *

-3 if C<$x> is not strictly increasing.

=item *

-4 if C<abs(ic(0)) E<gt> 5>.

=item *

-5 if C<abs(ic(1)) E<gt> 5>.

=item *

-6 if both -4 and -5  are true.

=item *

-7 if C<nwk E<lt> 2*(n-1)>.

=back

(The D-array has not been changed in any of these cases.)
NOTE:  The above errors are checked in the order listed,
and following arguments have B<NOT> been validated.

=back

Broadcasts over its inputs.

=for bad

C<pchip_chic> does not process bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*pchip_chic = \&PDL::pchip_chic;






=head2 pchip_chsp

=for sig

 Signature: (sbyte ic(two=2); vc(two=2); x(n); f(n);
    [o]d(n); indx [o]ierr();
    [t]dx(n); [t]dy_dx(n);
  )
 Types: (float double ldouble)

=for usage

 ($d, $ierr) = pchip_chsp($ic, $vc, $x, $f);
 pchip_chsp($ic, $vc, $x, $f, $d, $ierr);    # all arguments given
 ($d, $ierr) = $ic->pchip_chsp($vc, $x, $f); # method call
 $ic->pchip_chsp($vc, $x, $f, $d, $ierr);

=for ref

Calculate the derivatives of (x,f(x)) using cubic spline interpolation.

Computes the Hermite representation of the cubic spline interpolant
to the data given in (C<$x,$f>), with the specified boundary conditions.
Control over the boundary conditions is given by the
C<$ic> and C<$vc> ndarrays.
The resulting values - C<$x,$f,$d> - can
be used in all the functions which expect a cubic
Hermite function, including L</pchip_bvalu>.

References: Carl de Boor, A Practical Guide to Splines, Springer-Verlag,
New York, 1978, pp. 53-59.

=pod

=head3 Parameters

=over

=item ic

The first and second elements determine the boundary
conditions at the start and end of the data respectively.
The allowed values for C<ic(0)> are:

=over

=item *

0 to set C<d(0)> so that the third derivative is
continuous at C<x(1)>.

=item *

1 if first derivative at C<x(0)> is given in C<vc(0>).

=item *

2 if second derivative at C<x(0>) is given in C<vc(0)>.

=item *

3 to use the 3-point difference formula for C<d(0)>.
(Reverts to the default b.c. if C<n E<lt> 3>.)

=item *

4 to use the 4-point difference formula for C<d(0)>.
(Reverts to the default b.c. if C<n E<lt> 4>.)

=back

The values for C<ic(1)> are the same as above, except that
the first-derivative value is stored in C<vc(1)> for cases 1 and 2.
The values of C<$vc> need only be set if options 1 or 2 are chosen
for C<$ic>.

NOTES: For the "natural" boundary condition, use IC(n)=2 and VC(n)=0.

=item vc

See ic for details

=item ierr

Error status:

=over

=item *

0 if successful.

=item *

-1  if C<dim($x, 0) E<lt> 2>.

=item *

-3  if C<$x> is not strictly increasing.

=item *

-4  if C<ic(0) E<lt> 0> or C<ic(0) E<gt> 4>.

=item *

-5  if C<ic(1) E<lt> 0> or C<ic(1) E<gt> 4>.

=item *

-6  if both of the above are true.

=item *

-7  if C<nwk E<lt> 2*n>.

NOTE:  The above errors are checked in the order listed,
and following arguments have B<NOT> been validated.
(The D-array has not been changed in any of these cases.)

=item *

-8  in case of trouble solving the linear system
for the interior derivative values.
(The D-array may have been changed in this case. Do B<NOT> use it!)

=back

=back

Broadcasts over its inputs.

=for bad

C<pchip_chsp> does not process bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*pchip_chsp = \&PDL::pchip_chsp;






=head2 pchip_chfd

=for sig

 Signature: (x(n); f(n); d(n); xe(ne);
    [o] fe(ne); [o] de(ne); indx [o] ierr(); int [o] skip())
 Types: (float double ldouble)

=for usage

 ($fe, $de, $ierr, $skip) = pchip_chfd($x, $f, $d, $xe);
 pchip_chfd($x, $f, $d, $xe, $fe, $de, $ierr, $skip);    # all arguments given
 ($fe, $de, $ierr, $skip) = $x->pchip_chfd($f, $d, $xe); # method call
 $x->pchip_chfd($f, $d, $xe, $fe, $de, $ierr, $skip);

=for ref

Evaluate a piecewise cubic Hermite function and its first derivative
at an array of points. May be used by itself for Hermite interpolation,
or as an evaluator for DPCHIM or DPCHIC.

Given a piecewise cubic Hermite function - such as from
L</pchip_chim> - evaluate the function (C<$fe>) and
derivative (C<$de>) at a set of points (C<$xe>).
If function values alone are required, use L</pchip_chfe>.

=pod

=head3 Parameters

=over

=item xe

array of points at which the functions are to
be evaluated. NOTES:

=over

=item 1

The evaluation will be most efficient if the elements
of XE are increasing relative to X;
that is,   XE(J) .GE. X(I)
implies    XE(K) .GE. X(I),  all K.GE.J .

=item 2

If any of the XE are outside the interval [X(1),X(N)],
values are extrapolated from the nearest extreme cubic,
and a warning error is returned.

=back

=item fe

array of values of the cubic Hermite
function defined by  N, X, F, D  at the points  XE.

=item de

array of values of the first derivative of the same function at the points  XE.

=item ierr

Error status:

=over

=item *

0 if successful.

=item *

E<gt>0 if extrapolation was performed at C<ierr> points
(data still valid).

=item *

-1 if C<dim($x, 0) E<lt> 2>

=item *

-3 if C<$x> is not strictly increasing.

=item *

-4 if C<dim($xe, 0) E<lt> 1>.

=item *

-5 if an error has occurred in a lower-level routine,
which should never happen.

=back

=item skip

Set to 1 to skip checks on the input data.
This will save time in case these checks have already
been performed (say, in L</pchip_chim> or L</pchip_chic>).
Will be set to TRUE on normal return.

=back

Broadcasts over its inputs.

=for bad

C<pchip_chfd> does not process bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*pchip_chfd = \&PDL::pchip_chfd;






=head2 pchip_chfe

=for sig

 Signature: (x(n); f(n); d(n); xe(ne);
    [o] fe(ne); indx [o] ierr(); int [o] skip())
 Types: (float double ldouble)

=for usage

 ($fe, $ierr, $skip) = pchip_chfe($x, $f, $d, $xe);
 pchip_chfe($x, $f, $d, $xe, $fe, $ierr, $skip);    # all arguments given
 ($fe, $ierr, $skip) = $x->pchip_chfe($f, $d, $xe); # method call
 $x->pchip_chfe($f, $d, $xe, $fe, $ierr, $skip);

=for ref

Evaluate a piecewise cubic Hermite function at an array of points.
May be used by itself for Hermite interpolation, or as an evaluator
for L</pchip_chim> or L</pchip_chic>.

Given a piecewise cubic Hermite function - such as from
L</pchip_chim> - evaluate the function (C<$fe>) at
a set of points (C<$xe>).
If derivative values are also required, use L</pchip_chfd>.

=pod

=head3 Parameters

=over

=item x

array of independent variable values.  The
elements of X must be strictly increasing:

           X(I-1) .LT. X(I),  I = 2(1)N.

(Error return if not.)

=item f

array of function values.  F(I) is the value corresponding to X(I).

=item d

array of derivative values.  D(I) is the value corresponding to X(I).

=item xe

array of points at which the function is to be evaluated. NOTES:

=over

=item 1

The evaluation will be most efficient if the elements
of XE are increasing relative to X;
that is,   XE(J) .GE. X(I)
implies    XE(K) .GE. X(I),  all K.GE.J .

=item 2

If any of the XE are outside the interval [X(1),X(N)],
values are extrapolated from the nearest extreme cubic,
and a warning error is returned.

=back

=item fe

array of values of the cubic Hermite
function defined by  N, X, F, D  at the points  XE.

=item ierr

Error status returned by C<$>:

=over

=item *

0 if successful.

=item *

E<gt>0 if extrapolation was performed at C<ierr> points
(data still valid).

=item *

-1 if C<dim($x, 0) E<lt> 2>

=item *

-3 if C<$x> is not strictly increasing.

=item *

-4 if C<dim($xe, 0) E<lt> 1>.

=back

(The FE-array has not been changed in any of these cases.)
NOTE:  The above errors are checked in the order listed,
and following arguments have B<NOT> been validated.

=item skip

Set to 1 to skip checks on the input data.
This will save time in case these checks have already
been performed (say, in L</pchip_chim> or L</pchip_chic>).
Will be set to TRUE on normal return.

=back

Broadcasts over its inputs.

=for bad

C<pchip_chfe> does not process bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*pchip_chfe = \&PDL::pchip_chfe;






=head2 pchip_chia

=for sig

 Signature: (x(n); f(n); d(n); la(); lb();
    [o]ans(); indx [o]ierr(); int [o]skip())
 Types: (float double ldouble)

=for usage

 ($ans, $ierr, $skip) = pchip_chia($x, $f, $d, $la, $lb);
 pchip_chia($x, $f, $d, $la, $lb, $ans, $ierr, $skip);    # all arguments given
 ($ans, $ierr, $skip) = $x->pchip_chia($f, $d, $la, $lb); # method call
 $x->pchip_chia($f, $d, $la, $lb, $ans, $ierr, $skip);

=for ref

Integrate (x,f(x)) over arbitrary limits.

Evaluate the definite integral of a piecewise
cubic Hermite function over an arbitrary interval, given by C<[$la,$lb]>.

=pod

=head3 Parameters

=over

=item x

array of independent variable values.  The elements
of X must be strictly increasing (error return if not):

           X(I-1) .LT. X(I),  I = 2(1)N.

=item f

array of function values. F(I) is the value corresponding to X(I).

=item d

should contain the derivative values, computed by L</pchip_chim>.
See L</pchip_chid> if the integration limits are data points.

=item la

The values of C<$la> and C<$lb> do not have
to lie within C<$x>, although the resulting integral
value will be highly suspect if they are not.

=item lb

See la

=item ierr

Error status:

=over

=item *

0 if successful.

=item *

1 if C<$la> lies outside C<$x>.

=item *

2 if C<$lb> lies outside C<$x>.

=item *

3 if both 1 and 2 are true. (Note that this means that either [A,B]
contains data interval or the intervals do not intersect at all.)

=item *

-1 if C<dim($x, 0) E<lt> 2>

=item *

-3 if C<$x> is not strictly increasing.

=item *

-4 if an error has occurred in a lower-level routine,
which should never happen.

=back

=item skip

Set to 1 to skip checks on the input data.
This will save time in case these checks have already
been performed (say, in L</pchip_chim> or L</pchip_chic>).
Will be set to TRUE on return with IERR E<gt>= 0.

=back

Broadcasts over its inputs.

=for bad

C<pchip_chia> does not process bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*pchip_chia = \&PDL::pchip_chia;






=head2 pchip_chid

=for sig

 Signature: (x(n); f(n); d(n);
    indx ia(); indx ib();
    [o]ans(); indx [o]ierr(); int [o]skip())
 Types: (float double ldouble)

=for usage

 ($ans, $ierr, $skip) = pchip_chid($x, $f, $d, $ia, $ib);
 pchip_chid($x, $f, $d, $ia, $ib, $ans, $ierr, $skip);    # all arguments given
 ($ans, $ierr, $skip) = $x->pchip_chid($f, $d, $ia, $ib); # method call
 $x->pchip_chid($f, $d, $ia, $ib, $ans, $ierr, $skip);

=for ref

Evaluate the definite integral of a piecewise cubic Hermite function
over an interval whose endpoints are data points.

Evaluate the definite integral of a a piecewise cubic Hermite
function between C<x($ia)> and C<x($ib)>.

See L</pchip_chia> for integration between arbitrary
limits.

=pod

=head3 Parameters

=over

=item x

array of independent variable values.  The
elements of X must be strictly increasing:

           X(I-1) .LT. X(I),  I = 2(1)N.

(Error return if not.)

It is a fatal error to pass in data with C<N> E<lt> 2.

=item f

array of function values.  F(I) is the value corresponding to X(I).

=item d

should contain the derivative values, computed by L</pchip_chim>.

=item ia

IA,IB -- (input) indices in X-array for the limits of integration.
both must be in the range [0,N-1] (this is different from the Fortran
version) - error return if not. No restrictions on their relative
values.

=item ib

See ia for details

=item ierr

Error status - this will be set, but an exception
will also be thrown:

=over

=item *

0 if successful.

=item *

-3 if C<$x> is not strictly increasing.

=item *

-4 if C<$ia> or C<$ib> is out of range.

=back

(VALUE will be zero in any of these cases.)
NOTE: The above errors are checked in the order listed, and following
arguments have B<NOT> been validated.

=item skip

Set to 1 to skip checks on the input data.
This will save time in case these checks have already
been performed (say, in L</pchip_chim> or L</pchip_chic>).
Will be set to TRUE on return with IERR of 0 or -4.

=back

Broadcasts over its inputs.

=for bad

C<pchip_chid> does not process bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*pchip_chid = \&PDL::pchip_chid;






=head2 pchip_chbs

=for sig

 Signature: (x(n); f(n); d(n); sbyte knotyp();
    [o]t(nknots=CALC(2*$SIZE(n)+4));
    [o]bcoef(ndim=CALC(2*$SIZE(n))); indx [o]ierr())
 Types: (float double ldouble)

=for usage

 ($t, $bcoef, $ierr) = pchip_chbs($x, $f, $d, $knotyp);
 pchip_chbs($x, $f, $d, $knotyp, $t, $bcoef, $ierr);    # all arguments given
 ($t, $bcoef, $ierr) = $x->pchip_chbs($f, $d, $knotyp); # method call
 $x->pchip_chbs($f, $d, $knotyp, $t, $bcoef, $ierr);

=for ref

Piecewise Cubic Hermite function to B-Spline converter.

Computes the B-spline representation of the PCH function
determined by N,X,F,D. The output is the B-representation for the
function:  NKNOTS, T, BCOEF, NDIM, KORD.

L</pchip_chic>, L</pchip_chim>, or L</pchip_chsp> can be used to
determine an interpolating PCH function from a set of data. The
B-spline routine L</pchip_bvalu> can be used to evaluate the
resulting B-spline representation of the data
(i.e. C<nknots>, C<t>, C<bcoeff>, C<ndim>, and
C<kord>).

Caution: Since it is assumed that the input PCH function has been
computed by one of the other routines in the package PCHIP,
input arguments N, X are B<not> checked for validity.

Restrictions/assumptions:

=over

=item C<1>

N.GE.2 .  (not checked)

=item C<2>

X(i).LT.X(i+1), i=1,...,N .  (not checked)

=item C<4>

KNOTYP.LE.2 .  (error return if not)

=item C<6>

T(2*k+1) = T(2*k) = X(k), k=1,...,N .  (not checked)

* Indicates this applies only if KNOTYP.LT.0 .

=back

References: F. N. Fritsch, "Representations for parametric cubic
splines," Computer Aided Geometric Design 6 (1989), pp.79-82.

=pod

=head3 Parameters

=over

=item f

the array of dependent variable values.
C<f(I)> is the value corresponding to C<x(I)>.

=item d

the array of derivative values at the data points.
C<d(I)> is the value corresponding to C<x(I)>.

=item knotyp

flag which controls the knot sequence.
The knot sequence C<t> is normally computed from C<$x>
by putting a double knot at each C<x> and setting the end knot pairs
according to the value of C<knotyp> (where C<m = ndim = 2*n>):

=over

=item *

0 -   Quadruple knots at the first and last points.

=item *

1 -   Replicate lengths of extreme subintervals:
C<t( 0 ) = t( 1 ) = x(0) - (x(1)-x(0))> and
C<t(m+3) = t(m+2) = x(n-1) + (x(n-1)-x(n-2))>

=item *

2 -   Periodic placement of boundary knots:
C<t( 0 ) = t( 1 ) = x(0) - (x(n-1)-x(n-2))> and
C<t(m+3) = t(m+2) = x(n) + (x(1)-x(0))>

=item *

E<lt>0 - Assume the C<nknots> and C<t> were set in a previous call.
This option is provided for improved efficiency when used
in a parametric setting.

=back

=item t

the array of C<2*n+4> knots for the B-representation
and may be changed by the routine.
If C<knotyp E<gt>= 0>, C<t> will be changed so that the
interior double knots are equal to the x-values and the
boundary knots set as indicated above,
otherwise it is assumed that C<t> was set by a
previous call (no check is made to verify that the data
forms a legitimate knot sequence).

=item bcoef

the array of 2*N B-spline coefficients.

=item ierr

Error status:

=over

=item *

0 if successful.

=item *

-4 if C<knotyp E<gt> 2>. (recoverable)

=item *

-5 if C<knotyp E<lt> 0> and C<nknots != 2*n + 4>. (recoverable)

=back

=back

Broadcasts over its inputs.

=for bad

C<pchip_chbs> does not process bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*pchip_chbs = \&PDL::pchip_chbs;






=head2 pchip_bvalu

=for sig

 Signature: (t(nplusk); a(n); indx ideriv(); x();
    [o]ans(); indx [o] inbv();
    [t] work(k3=CALC(3*($SIZE(nplusk)-$SIZE(n))));)
 Types: (float double ldouble)

=for usage

 ($ans, $inbv) = pchip_bvalu($t, $a, $ideriv, $x);
 pchip_bvalu($t, $a, $ideriv, $x, $ans, $inbv);    # all arguments given
 ($ans, $inbv) = $t->pchip_bvalu($a, $ideriv, $x); # method call
 $t->pchip_bvalu($a, $ideriv, $x, $ans, $inbv);

=for ref

Evaluate the B-representation of a B-spline at X for the
function value or any of its derivatives.

Evaluates the B-representation C<(T,A,N,K)> of a B-spline
at C<X> for the function value on C<IDERIV = 0> or any of its
derivatives on C<IDERIV = 1,2,...,K-1>.  Right limiting values
(right derivatives) are returned except at the right end
point C<X=T(N+1)> where left limiting values are computed.  The
spline is defined on C<T(K) .LE. X .LE. T(N+1)>.  BVALU returns
a fatal error message when C<X> is outside of this interval.

To compute left derivatives or left limiting values at a
knot C<T(I)>, replace C<N> by C<I-1> and set C<X=T(I)>, C<I=K+1,N+1>.

References: Carl de Boor, Package for calculating with B-splines,
SIAM Journal on Numerical Analysis 14, 3 (June 1977), pp. 441-472.

=pod

=head3 Parameters

=over

=item t

knot vector of length N+K

=item a

B-spline coefficient vector of length N,
the number of B-spline coefficients; N = sum of knot multiplicities-K

=item ideriv

order of the derivative, 0 .LE. IDERIV .LE. K-1

IDERIV=0 returns the B-spline value

=item x

      T(K) .LE. X .LE. T(N+1)

=item ans

value of the IDERIV-th derivative at X

=item inbv

contains information for efficient processing after the initial
call and INBV must not
be changed by the user.  Distinct splines require distinct INBV parameters.

=back

Broadcasts over its inputs.

=for bad

C<pchip_bvalu> does not process bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*pchip_bvalu = \&PDL::pchip_bvalu;







#line 6328 "lib/PDL/Primitive.pd"

=head1 AUTHOR

Copyright (C) Tuomas J. Lukka 1997 (lukka@husc.harvard.edu). Contributions
by Christian Soeller (c.soeller@auckland.ac.nz), Karl Glazebrook
(kgb@aaoepp.aao.gov.au), Craig DeForest (deforest@boulder.swri.edu)
and Jarle Brinchmann (jarle@astro.up.pt)
All rights reserved. There is no warranty. You are allowed
to redistribute this software / documentation under certain
conditions. For details, see the file COPYING in the PDL
distribution. If this file is separated from the PDL distribution,
the copyright notice should be included in the file.

Updated for CPAN viewing compatibility by David Mertens.

=cut
#line 5775 "lib/PDL/Primitive.pm"

# Exit with OK status

1;
