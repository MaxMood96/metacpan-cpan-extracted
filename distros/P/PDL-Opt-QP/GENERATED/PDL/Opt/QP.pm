#
# GENERATED WITH PDL::PP! Don't modify!
#
package PDL::Opt::QP;

our @EXPORT_OK = qw(qpgen2 qp_orig qp );
our %EXPORT_TAGS = (Func=>\@EXPORT_OK);

use PDL::Core;
use PDL::Exporter;
use DynaLoader;


   our $VERSION = '0.29';
   our @ISA = ( 'PDL::Exporter','DynaLoader' );
   push @PDL::Core::PP, __PACKAGE__;
   bootstrap PDL::Opt::QP $VERSION;






#line 19 "qp.pd"

use strict;
use warnings;
use PDL::Ufunc;
use PDL::Ops;
use PDL::NiceSlice;
use Carp;

# ABSTRACT: Quadratic programming solver for PDL

=head1 NAME

PDL::Opt::QP - Quadratic programming solver for PDL

=head1 SYNOPSIS

    use PDL;
    use PDL::NiceSlice;
    use PDL::Opt::QP;

    my $mu   = pdl(q[ 0.0427 0.0015 0.0285 ])->transpose; # [ n x 1 ]
    my $mu_0 = 0.0427;
    my $dmat = pdl q[ 0.0100 0.0018 0.0011 ;
                      0.0018 0.0109 0.0026 ;
                      0.0011 0.0026 0.0199 ];
    my $dvec = zeros(3);
    my $amat = $mu->glue( 0, ones( 1, 3 ) )->copy;
    my $bvec = pdl($mu_0)->glue( 1, ones(1) )->flat;
    my $meq  = pdl(2);

    my $sol = qp( $dmat, $dvec, $amat, $bvec, $meq );
    say "Solution: ", $sol->{x};

=head1 DESCRIPTION

This routine uses Goldfarb/Idnani algorithm to solve the
following minimization problem:

           minimize  f(x) = 0.5 * x' D x  -  d' x
              x

    optionally constrained by:

            Aeq'  x  = a_eq
            Aneq  x >= b_neq

=cut
#line 73 "QP.pm"






=head1 FUNCTIONS

=cut




#line 949 "/home/osboxes/.perlbrew/libs/perl-5.32.0@normal/lib/perl5/x86_64-linux/PDL/PP.pm"



=head2 qpgen2

=for sig

  Signature: (dmat(m,m); dvec(m);
        [o]sol(m); [o]lagr(q); [o]crval();
        amat(m,q); bvec(q); int meq();
        int [o]iact(q); int [o]nact();
        int [o]iter(s=2); [t]work(z); int [o]ierr();
    )



=for ref

This routine solves the quadratic programming optimization problem

           minimize  f(x) = 0.5 x' D x  -  d' x
              x

    optionally constrained by:

            Aeq'  x  = a_eq
            Aneq  x >= b_neq


.... more docs to come ....


=for bad

qpgen2 ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.


=cut
#line 127 "QP.pm"



#line 951 "/home/osboxes/.perlbrew/libs/perl-5.32.0@normal/lib/perl5/x86_64-linux/PDL/PP.pm"

*qpgen2 = \&PDL::qpgen2;
#line 134 "QP.pm"



#line 214 "qp.pd"


#line 215 "qp.pd"


sub qp {
  my ($Dmat, $dvec, %args) = @_;

  my $col   = 0;
  my $row   = 1;
  my $stack = 2;

  my $n = pdl $Dmat->dim($row);    # D is an [n x n] matrix
  my $s = pdl $Dmat->dim($stack);  # ... of $s stacked problems

  # Default handling for A_eq and A_neq
  my $A_eq  = exists $args{A_eq}  ? $args{A_eq}  : zeroes(0, $n);
  my $A_neq = exists $args{A_neq} ? $args{A_neq} : zeroes(0, $n);

  my $m = pdl $A_eq->dim($col);    # A is an [n x m] matrix
  my $p = pdl $A_neq->dim($col);   # A is an [n x p] matrix

  # Default handling for a_eq and a_neq
  # These have to be [?x1] matrixes to ensure threading works if glue,
  # otherwise they are relicated not just attached.
  my $a_eq  = exists $args{a_eq}  ? $args{a_eq}  : zeroes(1, $m);
  my $a_neq = exists $args{a_neq} ? $args{a_neq} : zeroes(1, $p);

  check_dimmensions( 'Dmat', $Dmat, $n, $n, $s );
  check_dimmensions( 'dvec', $dvec, $n, $s );
  check_dimmensions( 'A_eq', $A_eq, $m, $n, $s );
  check_dimmensions( 'a_eq', $a_eq, $m, $s );
  check_dimmensions( 'A_neq', $A_neq, $p, $n, $s );

  if( $p == 0 ){ # If a_neq has zero elems (per stack), then it will be [0x1]
      check_dimmensions( 'a_neq', $a_neq, 1, $p, $s );
  } else {       # otherwise it will be a [p] vector
      check_dimmensions( 'a_neq', $a_neq, $p, $s );
  }

  # Combine _eq and _neq, use meq to specifiy number of equality constratins
  my $A = $A_eq->glue( 0, $A_neq );
  my $a = $a_eq->glue( 0, $a_neq );
  my $meq = $A_eq->dim($col);

  #  Pars => 'dmat(m,m); dvec(m);
  #      [o]sol(m); [o]lagr(q); [o]crval();
  #      amat(m,q); bvec(q); int meq();
  #      int [o]iact(q); int [o]nact();
  #      int [o]iter(s=2); [t] work(z); int [io]ierr();

  my ( $sol, $lagr, $crval, $iact, $nact, $iter, $ierr ) = qpgen2(
                   $Dmat->copy, $dvec->copy,
                   $A->transpose->copy,
                   $a->copy,
                   $meq,
        );

  croak "qp: constraints are inconsistent, no solution! (ierr=$ierr)"
      if any($ierr == 1);
  croak "qp: matrix D in quadratic function is not positive definite! (ierr=$ierr)"
      if any($ierr == 2);
  croak "qp: some problem with minimization (ierr=$ierr)" if any($ierr);

  return {
    x     => $sol,
    lagr  => $lagr,
    crval => $crval,
    iact  => $iact,
    nact  => $nact,
    iter  => $iter,
    ierr  => $ierr,
  };

}

sub check_dimmensions {
    my ($name, $pdl, @dims) = @_;

    pop @dims if $dims[-1] == 1;    # remove last dim if a dimension of 1
    my $got      = pdl $pdl->dims;
    my $expected = pdl @dims;

    croak( sprintf( "dimmension check failed for %s (is %s)\nexpected [%s]\n%s",
            $name, $pdl->info, join(',',@dims), qp_usage() )
     ) unless all $got == $expected;
}

sub qp_usage {
    return q{
     usage: qp( Dmat [n x n], dvec [n], A_eq  => [n x m], a_eq  => [m],
                                        a_neq => [n x p], a_neq => [p] )
        where A_eq and a_eq are the equality constraints
          and A_neq and a_neq are the inequality constraints (>=)
     All inputs can add one addition dimmension to "stack" multiple
     Optimization problems. The returned solution (x) will have stack
     dimmensions.
    };
}
#line 313 "qp.pd"
#line 239 "QP.pm"





#line 160 "qp.pd"


sub qp_orig {
  my ($Dmat, $dvec, $Amat, $avec, $meq) = @_;

  my $n = pdl $Dmat->dim(1);    # D is an [n x n] matrix
  my $q = pdl $Amat->dim(0);    # A is an [n x q] matrix

  if( $avec->isnull ){ $avec = zeros(1,$q); }

  croak("Dmat is not square!")
    if $n != $Dmat->dim(0);               # Check D is [n x n]
  croak("Dmat and dvec are incompatible!")
    if $n != $dvec->nelem;                # Check d is [n]
  croak("Amat and dvec are incompatible!")
    if $n != $Amat->dim(1);               # Check A is [n x _]
  croak("Amat and avec are incompatible!")
    if $q != $avec->nelem;                # Check A is [_ x q]
  croak("Value of meq is invalid!")
    if ($meq > $q) || ($meq < 0 );

  #  Pars => 'dmat(m,m); dvec(m);
  #      [o]sol(m); [o]lagr(q); [o]crval();
  #      amat(m,q); bvec(q); int meq();
  #      int [o]iact(q); int [o]nact();
  #      int [o]iter(s=2); [t] work(z); int [o]ierr();

  my ( $sol, $lagr, $crval, $iact, $nact, $iter, $ierr ) = qpgen2(
                   $Dmat->copy, $dvec->copy,
                   $Amat->transpose->copy,
                   $avec->copy,
                   $meq,
        );

  croak "qp: constraints are inconsistent, no solution! (ierr=$ierr)"
      if any($ierr == 1);
  croak "qp: matrix D in quadratic function is not positive definite! (ierr=$ierr)"
      if any($ierr == 2);
  croak "qp: some problem with minimization (ierr=$ierr)" if any($ierr);

  return {
    x     => $sol,
    lagr  => $lagr,
    crval => $crval,
    iact  => $iact,
    nact  => $nact,
    iter  => $iter,
    ierr  => $ierr,
  };

}
#line 297 "QP.pm"



#line 312 "qp.pd"


=head1 SEE ALSO

L<PDL>, L<PDL::Opt::NonLinear>

=head1 BUGS

Please report any bugs or suggestions at L<http://rt.cpan.org/>

=head1 AUTHOR

Mark Grimes, E<lt>mgrimes@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Mark Grimes, E<lt>mgrimes@cpan.orgE<gt>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
#line 324 "QP.pm"




# Exit with OK status

1;
