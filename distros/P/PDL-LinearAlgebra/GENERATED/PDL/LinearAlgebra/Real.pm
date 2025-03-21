#
# GENERATED WITH PDL::PP from lib/PDL/LinearAlgebra/Real.pd! Don't modify!
#
package PDL::LinearAlgebra::Real;

our @EXPORT_OK = qw(gtsv gesvd gesdd ggsvd geev geevx ggev ggevx gees geesx gges ggesx syev syevd syevx syevr sygv sygvd sygvx gesv gesvx sysv sysvx posv posvx gels gelsy gelss gelsd gglse ggglm getrf getf2 sytrf sytf2 potrf potf2 getri sytri potri trtri trti2 getrs sytrs potrs trtrs latrs gecon sycon pocon trcon geqp3 geqrf orgqr ormqr gelqf orglq ormlq geqlf orgql ormql gerqf orgrq ormrq tzrzf ormrz gehrd orghr hseqr trevc tgevc gebal gebak lange lansy lantr gemm mmult crossprod syrk dot axpy nrm2 asum scal rot rotg lasrt lacpy laswp lamch labad cplx_eigen charpol );
our %EXPORT_TAGS = (Func=>\@EXPORT_OK);

use PDL::Core;
use PDL::Exporter;
use DynaLoader;


   our $VERSION = '0.433';
   our @ISA = ( 'PDL::Exporter','DynaLoader' );
   push @PDL::Core::PP, __PACKAGE__;
   bootstrap PDL::LinearAlgebra::Real $VERSION;







#line 83 "lib/PDL/LinearAlgebra/Real.pd"

use strict;

{
  package # hide from CPAN
    PDL;
  my $warningFlag;
  BEGIN{
    $warningFlag = $^W;
    $^W = 0;
  }

  use overload (
    'x' => sub {
      !(grep ref($_) && !$_->type->real, @_[0,1])
        ? PDL::mmult($_[0], $_[1])
        : PDL::cmmult($_[0], $_[1])
    },
  );

  BEGIN{ $^W = $warningFlag;}
}

=encoding utf8

=head1 NAME

PDL::LinearAlgebra::Real - PDL interface to the real lapack linear algebra programming library

=head1 SYNOPSIS

 use PDL::LinearAlgebra::Real;

 $a = random (100,100);
 $s = zeroes(100);
 $u = zeroes(100,100);
 $v = zeroes(100,100);
 $info = 0;
 $job = 0;
 gesdd($a, $job, $info, $s , $u, $v);

=head1 DESCRIPTION

This module provides an interface to parts of the real lapack library.
These routines accept either float or double ndarrays.

=cut
#line 74 "lib/PDL/LinearAlgebra/Real.pm"


=head1 FUNCTIONS

=cut






=head2 gtsv

=for sig

  Signature: ([io]DL(n); [io]D(n); [io]DU(n); [io]B(n,nrhs); int [o]info())

=for ref

Solves the equation

	A * X = B

where A is an C<n> by C<n> tridiagonal matrix, by Gaussian elimination with
partial pivoting, and B is an C<n> by C<nrhs> matrix.

Note that the equation C<A**T*X = B>  may be solved by interchanging the
order of the arguments DU and DL.

B<NB> This differs from the LINPACK function C<dgtsl> in that C<DL>
starts from its first element, while the LINPACK equivalent starts from
its second element.

    Arguments
    =========

    DL:   On entry, DL must contain the (n-1) sub-diagonal elements of A.

          On exit, DL is overwritten by the (n-2) elements of the
          second super-diagonal of the upper triangular matrix U from
          the LU factorization of A, in DL(1), ..., DL(n-2).

    D:    On entry, D must contain the diagonal elements of A.

          On exit, D is overwritten by the n diagonal elements of U.

    DU:   On entry, DU must contain the (n-1) super-diagonal elements of A.

          On exit, DU is overwritten by the (n-1) elements of the
          first super-diagonal of the U.

    B:    On entry, the n by nrhs matrix of right hand side matrix B.
          On exit, if info = 0, the n by nrhs solution matrix X.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value
            > 0:  if info = i, U(i,i) is exactly zero, and the solution
                  has not been computed.  The factorization has not been
                  completed unless i = n.

=for example

 $dl = random(float, 9);
 $d = random(float, 10);
 $du = random(float, 9);
 $b = random(10,5);
 gtsv($dl, $d, $du, $b, ($info=null));
 print "X is:\n$b" unless $info;

=for bad

gtsv ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*gtsv = \&PDL::gtsv;






=head2 gesvd

=for sig

  Signature: ([io]A(m,n); int jobu(); int jobvt(); [o]s(minmn=CALC(PDLMIN($SIZE(m),$SIZE(n)))); [o]U(p,p); [o]VT(s,s); int [o]info())

=for ref

Computes the singular value decomposition (SVD) of a real
M-by-N matrix A.

The SVD is written

 A = U * SIGMA * V'

where SIGMA is an M-by-N matrix which is zero except for its
min(m,n) diagonal elements, U is an M-by-M orthogonal matrix, and
V is an N-by-N orthogonal matrix.  The diagonal elements of SIGMA
are the singular values of A; they are real and non-negative, and
are returned in descending order.  The first min(m,n) columns of
U and V are the left and right singular vectors of A.

Note that the routine returns VT = V', not V.

    jobu:   Specifies options for computing all or part of the matrix U:
            = 0:  no columns of U (no left singular vectors) are
                    computed.
            = 1:  all M columns of U are returned in array U:
            = 2:  the first min(m,n) columns of U (the left singular
                    vectors) are returned in the array U;
            = 3:  the first min(m,n) columns of U (the left singular
                    vectors) are overwritten on the array A;

    jobvt:  Specifies options for computing all or part of the matrix
            V':
            = 0:  no rows of V' (no right singular vectors) are
                    computed.
            = 1:  all N rows of V' are returned in the array VT;
            = 2:  the first min(m,n) rows of V' (the right singular
                    vectors) are returned in the array VT;
            = 3:  the first min(m,n) rows of V' (the right singular
                    vectors) are overwritten on the array A;

            jobvt and jobu cannot both be 3.

    A:      On entry, the M-by-N matrix A.
            On exit,
            if jobu = 3,  A is overwritten with the first min(m,n)
                            columns of U (the left singular vectors,
                            stored columnwise);
            if jobvt = 3, A is overwritten with the first min(m,n)
                            rows of V' (the right singular vectors,
                            stored rowwise);
            if jobu != 3 and jobvt != 3, the contents of A
                            are destroyed.

    s:      The singular values of A, sorted so that s(i) >= s(i+1).

    U:      If jobu = 1, U contains the M-by-M orthogonal matrix U;
            if jobu = 3, U contains the first min(m,n) columns of U
            (the left singular vectors, stored columnwise);
            if jobu = 0 or 3, U is not referenced.
            Min size  = [1,1].

    VT:     If jobvt = 1, VT contains the N-by-N orthogonal matrix
            V';
            if jobvt = 2, VT contains the first min(m,n) rows of
            V' (the right singular vectors, stored rowwise);
            if jobvt = 0 or 3, VT is not referenced.
            Min size  = [1,1].

    info:   = 0:  successful exit.
            < 0:  if info = -i, the i-th argument had an illegal value.
            > 0:  if bdsqr did not converge, info specifies how many
                  superdiagonals of an intermediate bidiagonal form B
                  did not converge to zero.

=for example

 $a = random (float, 100,100);
 $s = zeroes(float, 100);
 $u = zeroes(float, 100,100);
 $vt = zeroes(float, 100,100);
 $info = pdl(long, 0);
 gesvd($a, 2, 2, $s , $u, $vt, $info);

=for bad

gesvd ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*gesvd = \&PDL::gesvd;






=head2 gesdd

=for sig

  Signature: ([io]A(m,n); int jobz(); [o]s(minmn=CALC(PDLMIN($SIZE(m),$SIZE(n)))); [o]U(p,p); [o]VT(s,s); int [o]info(); int [t]iwork(iworkn))

=for ref

Computes the singular value decomposition (SVD) of a real
M-by-N matrix A.

This routine use the Coppen's divide and conquer algorithm.
It is much faster than the simple driver for large matrices, but uses more workspace.

    jobz:    Specifies options for computing all or part of matrix:

            = 0:  no columns of U or rows of V' are computed;
	    = 1:  all M columns of U and all N rows of V' are
                    returned in the arrays U and VT;
            = 2:  the first min(M,N) columns of U and the first
                    min(M,N) rows of V' are returned in the arrays U
                    and VT;
            = 3:  If M >= N, the first N columns of U are overwritten
                    on the array A and all rows of V' are returned in
                    the array VT;
                    otherwise, all columns of U are returned in the
                    array U and the first M rows of V' are overwritten
                    on the array A.

    A:      On entry, the M-by-N matrix A.
            On exit,
            if jobz = 3,  A is overwritten with the first N columns
                            of U (the left singular vectors, stored
                            columnwise) if M >= N;
                            A is overwritten with the first M rows
                            of V' (the right singular vectors, stored
                            rowwise) otherwise.
            if jobz != 3, the contents of A are destroyed.

    s:      The singular values of A, sorted so that s(i) >= s(i+1).

    U:      If jobz = 1 or jobz = 3 and M < N, U contains the M-by-M
            orthogonal matrix U;
            if jobz = 2, U contains the first min(M,N) columns of U
            (the left singular vectors, stored columnwise);
            if jobz = 3 and M >= N, or jobz = 0, U is not referenced.
            Min size  = [1,1].

    VT:     If jobz = 1 or jobz = 3 and M >= N, VT contains the
            N-by-N orthogonal matrix V';
            if jobz = 2, VT contains the first min(M,N) rows of
            V' (the right singular vectors, stored rowwise);
            if jobz = 3 and M < N, or jobz = 0, VT is not referenced.
            Min size  = [1,1].

    info:   = 0:  successful exit.
            < 0:  if info = -i, the i-th argument had an illegal value.
            > 0:  bdsdc did not converge, updating process failed.

=for example

 $lines = 50;
 $columns = 100;
 $a = random (float, $lines, $columns);
 $min = $lines < $columns ? $lines : $columns;
 $s = zeroes(float, $min);
 $u = zeroes(float, $lines, $lines);
 $vt = zeroes(float, $columns, $columns);
 $info = long (0);
 gesdd($a, 1, $s , $u, $vt, $info);

=for bad

gesdd ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*gesdd = \&PDL::gesdd;






=head2 ggsvd

=for sig

  Signature: ([io]A(m,n); int jobu(); int jobv(); int jobq(); [io]B(p,n); int [o]k(); int [o]l();[o]alpha(n);[o]beta(n); [o]U(q,q); [o]V(r,r); [o]Q(s,s); int [o]iwork(n); int [o]info())

=for ref

Computes the generalized singular value decomposition (GSVD)
of an M-by-N real matrix A and P-by-N real matrix B:

	U'*A*Q = D1*( 0 R ),    V'*B*Q = D2*( 0 R )

	where U, V and Q are orthogonal matrices, and Z' is the transpose
	of Z.

Let K+L = the effective numerical rank of the matrix (A',B')',
then R is a K+L-by-K+L nonsingular upper triangular matrix, D1 and
D2 are M-by-(K+L) and P-by-(K+L) "diagonal" matrices and of the
following structures, respectively:

	If M-K-L >= 0,

                        K  L
           D1 =     K ( I  0 )
                    L ( 0  C )
                M-K-L ( 0  0 )

                      K  L
           D2 =   L ( 0  S )
                P-L ( 0  0 )

                    N-K-L  K    L
      ( 0 R ) = K (  0   R11  R12 )
                L (  0    0   R22 )

    where

      C = diag( ALPHA(K+1), ... , ALPHA(K+L) ),
      S = diag( BETA(K+1),  ... , BETA(K+L) ),
      C**2 + S**2 = I.

      R is stored in A(1:K+L,N-K-L+1:N) on exit.

    If M-K-L < 0,

                      K M-K K+L-M
           D1 =   K ( I  0    0   )
                M-K ( 0  C    0   )

                        K M-K K+L-M
           D2 =   M-K ( 0  S    0  )
                K+L-M ( 0  0    I  )
                  P-L ( 0  0    0  )

                       N-K-L  K   M-K  K+L-M
      ( 0 R ) =     K ( 0    R11  R12  R13  )
                  M-K ( 0     0   R22  R23  )
                K+L-M ( 0     0    0   R33  )

    where

      C = diag( ALPHA(K+1), ... , ALPHA(M) ),
      S = diag( BETA(K+1),  ... , BETA(M) ),
      C**2 + S**2 = I.

      (R11 R12 R13 ) is stored in A(1:M, N-K-L+1:N), and R33 is stored
      ( 0  R22 R23 )
      in B(M-K+1:L,N+M-K-L+1:N) on exit.

The routine computes C, S, R, and optionally the orthogonal
transformation matrices U, V and Q.

In particular, if B is an N-by-N nonsingular matrix, then the GSVD of
A and B implicitly gives the SVD of A*inv(B):

                         A*inv(B) = U*(D1*inv(D2))*V'.

If ( A',B')' has orthonormal columns, then the GSVD of A and B is
also equal to the CS decomposition of A and B. Furthermore, the GSVD
can be used to derive the solution of the eigenvalue problem:

                         A'*A x = lambda* B'*B x.

In some literature, the GSVD of A and B is presented in the form

                     U'*A*X = ( 0 D1 ),   V'*B*X = ( 0 D2 )
                     where U and V are orthogonal and X is nonsingular, D1 and D2 are "diagonal".

The former GSVD form can be converted to the latter
form by taking the nonsingular matrix X as

                         X = Q*( I   0    )
                               ( 0 inv(R) ).

    Arguments
    =========

    jobu:   = 0:  U is not computed.
	    = 1:  Orthogonal matrix U is computed;

    jobv:   = 0:  V is not computed.
            = 1:  Orthogonal matrix V is computed;

    jobq:   = 0:  Q is not computed.
            = 1:  Orthogonal matrix Q is computed;

    k:
    l:      On exit, k and l specify the dimension of the subblocks
            described in the Purpose section.
            k + l = effective numerical rank of (A',B')'.

    A:      On entry, the M-by-N matrix A.
            On exit, A contains the triangular matrix R, or part of R.

    B:      On entry, the P-by-N matrix B.
            On exit, B contains the triangular matrix R if M-k-l < 0.

    alpha:
    beta:   On exit, alpha and beta contain the generalized singular
            value pairs of A and B;
              alpha(1:k) = 1,
              beta(1:k)  = 0,
            and if M-k-l >= 0,
              alpha(k+1:k+l) = C,
              beta(k+1:k+l)  = S,
            or if M-k-l < 0,
              alpha(k+1:M)=C, alpha(M+1:k+l)=0
              beta(k+1:M) =S, beta(M+1:k+l) =1
            and
              alpha(k+l+1:N) = 0
              beta(k+l+1:N)  = 0

    U:      If jobu = 1, U contains the M-by-M orthogonal matrix U.
            If jobu = 0, U is not referenced.
	    Need a minimum array of (1,1) if jobu = 0;

    V:      If jobv = 1, V contains the P-by-P orthogonal matrix V.
            If jobv = 0, V is not referenced.
	    Need a minimum array of (1,1) if jobv = 0;

    Q:      If jobq = 1, Q contains the N-by-N orthogonal matrix Q.
            If jobq = 0, Q is not referenced.
	    Need a minimum array of (1,1) if jobq = 0;

    iwork:  On exit, iwork stores the sorting information. More
            precisely, the following loop will sort alpha
               for I = k+1, min(M,k+l)
                   swap alpha(I) and alpha(iwork(I))
               endfor
            such that alpha(1) >= alpha(2) >= ... >= alpha(N).

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value.
            > 0:  if info = 1, the Jacobi-type procedure failed to
                  converge.  For further details, see subroutine tgsja.

=for example

 $k = null;
 $l = null;
 $A = random(5,6);
 $B = random(7,6);
 $alpha = zeroes(6);
 $beta = zeroes(6);
 $U = zeroes(5,5);
 $V = zeroes(7,7);
 $Q = zeroes(6,6);
 $iwork = zeroes(long, 6);
 $info = null;
 ggsvd($A,1,1,1,$B,$k,$l,$alpha, $beta,$U, $V, $Q, $iwork,$info);

=for bad

ggsvd ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*ggsvd = \&PDL::ggsvd;






=head2 geev

=for sig

  Signature: ([io]A(n,n); int jobvl(); int jobvr(); [o]wr(n); [o]wi(n); [o]vl(m,m); [o]vr(p,p); int [o]info())

=for ref

Computes for an N-by-N real nonsymmetric matrix A, the
eigenvalues and, optionally, the left and/or right eigenvectors.

The right eigenvector v(j) of A satisfies:
 A * v(j) = lambda(j) * v(j)
where lambda(j) is its eigenvalue.

The left eigenvector u(j) of A satisfies:
 u(j)**H * A = lambda(j) * u(j)**H
where u(j)**H denotes the conjugate transpose of u(j).

The computed eigenvectors are normalized to have Euclidean norm
equal to 1 and largest component real.

    Arguments
    =========

    jobvl:  = 0: left eigenvectors of A are not computed;
            = 1: left eigenvectors of A are computed.

    jobvr:  = 0: right eigenvectors of A are not computed;
            = 1: right eigenvectors of A are computed.

    A:      A is overwritten.

    wr:
    wi:     wr and wi contain the real and imaginary parts,
            respectively, of the computed eigenvalues.  Complex
            conjugate pairs of eigenvalues appear consecutively
            with the eigenvalue having the positive imaginary part
            first.

    vl:     If jobvl = 1, the left eigenvectors u(j) are stored one
            after another in the columns of vl, in the same order
            as their eigenvalues else  vl is not referenced.
            If the j-th eigenvalue is real, then u(j) = vl(:,j),
            the j-th column of vl.
            If the j-th and (j+1)-st eigenvalues form a complex
            conjugate pair, then u(j) = vl(:,j) + i*vl(:,j+1) and
            u(j+1) = vl(:,j) - i*vl(:,j+1).
            Min size  = [1].

    vr:     If jobvr = 1, the right eigenvectors v(j) are stored one
            after another in the columns of vr, in the same order
            as their eigenvalues else vr is not referenced.
            If the j-th eigenvalue is real, then v(j) = vr(:,j),
            the j-th column of vr.
            If the j-th and (j+1)-st eigenvalues form a complex
            conjugate pair, then v(j) = vr(:,j) + i*vr(:,j+1) and
            v(j+1) = vr(:,j) - i*vr(:,j+1).
            Min size  = [1].

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value.
            > 0:  if info = i, the QR algorithm failed to compute all the
                  eigenvalues, and no eigenvectors have been computed;
                  elements i+1:N of wr and wi contain eigenvalues which
                  have converged.

=for example

 $a = random (5, 5);
 $wr = zeroes(5);
 $wi = zeroes($wr);
 $vl = zeroes($a);
 $vr = zeroes($a);
 $info = null;
 geev($a, 1, 1, $wr, $wi, $vl, $vr, $info);

=for bad

geev ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*geev = \&PDL::geev;






=head2 geevx

=for sig

  Signature: ([io]A(n,n);  int jobvl(); int jobvr(); int balance(); int sense(); [o]wr(n); [o]wi(n); [o]vl(m,m); [o]vr(p,p); int [o]ilo(); int [o]ihi(); [o]scale(n); [o]abnrm(); [o]rconde(q); [o]rcondv(r); int [o]info(); int [t]iwork(iworkn))

=for ref

Computes for an N-by-N real nonsymmetric matrix A, the
eigenvalues and, optionally, the left and/or right eigenvectors.

Optionally also, it computes a balancing transformation to improve
the conditioning of the eigenvalues and eigenvectors (ilo, ihi,
scale, and abnrm), reciprocal condition numbers for the eigenvalues
(rconde), and reciprocal condition numbers for the right
eigenvectors (rcondv).

The right eigenvector v(j) of A satisfies:

 A * v(j) = lambda(j) * v(j)
 where lambda(j) is its eigenvalue.

The left eigenvector u(j) of A satisfies:

 u(j)**H * A = lambda(j) * u(j)**H
 where u(j)**H denotes the conjugate transpose of u(j).

The computed eigenvectors are normalized to have Euclidean norm
equal to 1 and largest component real.

Balancing a matrix means permuting the rows and columns to make it
more nearly upper triangular, and applying a diagonal similarity
transformation D * A * D**(-1), where D is a diagonal matrix, to
make its rows and columns closer in norm and the condition numbers
of its eigenvalues and eigenvectors smaller.  The computed
reciprocal condition numbers correspond to the balanced matrix.
Permuting rows and columns will not change the condition numbers
(in exact arithmetic) but diagonal scaling will.  For further
explanation of balancing, see section 4.10.2 of the LAPACK
Users' Guide.

    Arguments
    =========

    balance:
            Indicates how the input matrix should be diagonally scaled
            and/or permuted to improve the conditioning of its
            eigenvalues.
            = 0: Do not diagonally scale or permute;
            = 1: Perform permutations to make the matrix more nearly
                   upper triangular. Do not diagonally scale;
            = 2: Diagonally scale the matrix, i.e. replace A by
                   D*A*D**(-1), where D is a diagonal matrix chosen
                   to make the rows and columns of A more equal in
                   norm. Do not permute;
            = 3: Both diagonally scale and permute A.

            Computed reciprocal condition numbers will be for the matrix
            after balancing and/or permuting. Permuting does not change
            condition numbers (in exact arithmetic), but balancing does.

    jobvl:   = 0: left eigenvectors of A are not computed;
            = 1: left eigenvectors of A are computed.
            If sense = 1 or 3, jobvl must = 1.

    jobvr;  = 0: right eigenvectors of A are not computed;
            = 1: right eigenvectors of A are computed.
            If sense = 1 or 3, jobvr must = 1.

    sense:  Determines which reciprocal condition numbers are computed.
            = 0: None are computed;
            = 1: Computed for eigenvalues only;
            = 2: Computed for right eigenvectors only;
            = 3: Computed for eigenvalues and right eigenvectors.

            If sense = 1 or 3, both left and right eigenvectors
            must also be computed (jobvl = 1 and jobvr = 1).

    A:      The N-by-N matrix.
            It is overwritten.  If jobvl = 1 or
            jobvr = 1, A contains the real Schur form of the balanced
            version of the input matrix A.

    wr
    wi:     wr and wi contain the real and imaginary parts,
            respectively, of the computed eigenvalues.  Complex
            conjugate pairs of eigenvalues will appear consecutively
            with the eigenvalue having the positive imaginary part
            first.

    vl:     If jobvl = 1, the left eigenvectors u(j) are stored one
            after another in the columns of vl, in the same order
            as their eigenvalues else vl is not referenced.
            If the j-th eigenvalue is real, then u(j) = vl(:,j),
            the j-th column of vl.
            If the j-th and (j+1)-st eigenvalues form a complex
            conjugate pair, then u(j) = vl(:,j) + i*vl(:,j+1) and
            u(j+1) = vl(:,j) - i*vl(:,j+1).
            Min size  = [1].

    vr:     If jobvr = 1, the right eigenvectors v(j) are stored one
            after another in the columns of vr, in the same order
            as their eigenvalues else vr is not referenced.
            If the j-th eigenvalue is real, then v(j) = vr(:,j),
            the j-th column of vr.
            If the j-th and (j+1)-st eigenvalues form a complex
            conjugate pair, then v(j) = vr(:,j) + i*vr(:,j+1) and
            v(j+1) = vr(:,j) - i*vr(:,j+1).
            Min size  = [1].

    ilo,ihi:Integer values determined when A was
            balanced.  The balanced A(i,j) = 0 if I > J and
            J = 1,...,ilo-1 or I = ihi+1,...,N.

    scale:  Details of the permutations and scaling factors applied
            when balancing A.  If P(j) is the index of the row and column
            interchanged with row and column j, and D(j) is the scaling
            factor applied to row and column j, then
            scale(J) = P(J),    for J = 1,...,ilo-1
                     = D(J),    for J = ilo,...,ihi
                     = P(J)     for J = ihi+1,...,N.
            The order in which the interchanges are made is N to ihi+1,
            then 1 to ilo-1.

    abnrm:  The one-norm of the balanced matrix (the maximum
            of the sum of absolute values of elements of any column).

    rconde: rconde(j) is the reciprocal condition number of the j-th
            eigenvalue.

    rcondv: rcondv(j) is the reciprocal condition number of the j-th
            right eigenvector.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value.
            > 0:  if info = i, the QR algorithm failed to compute all the
                  eigenvalues, and no eigenvectors or condition numbers
                  have been computed; elements 1:ilo-1 and i+1:N of wr
                  and wi contain eigenvalues which have converged.

=for example

 $a = random (5,5);
 $wr = zeroes(5);
 $wi = zeroes(5);
 $vl = zeroes(5,5);
 $vr = zeroes(5,5);
 $ilo = null;
 $ihi = null;
 $scale  = zeroes(5);
 $abnrm = null;
 $rconde = zeroes(5);
 $rcondv = zeroes(5);
 $info = null;
 geevx($a, 1,1,3,3,$wr, $wi, $vl, $vr, $ilo, $ihi, $scale, $abnrm,$rconde, $rcondv, $info);

=for bad

geevx ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*geevx = \&PDL::geevx;






=head2 ggev

=for sig

  Signature: ([io]A(n,n); int jobvl();int jobvr();[io]B(n,n);[o]alphar(n);[o]alphai(n);[o]beta(n);[o]VL(m,m);[o]VR(p,p);int [o]info())

=for ref

Computes for a pair of N-by-N real nonsymmetric matrices (A,B)
the generalized eigenvalues, and optionally, the left and/or right
generalized eigenvectors.

A generalized eigenvalue for a pair of matrices (A,B) is a scalar
lambda or a ratio alpha/beta = lambda, such that A - lambda*B is
singular. It is usually represented as the pair (alpha,beta), as
there is a reasonable interpretation for beta=0, and even for both
being zero.

The right eigenvector v(j) corresponding to the eigenvalue lambda(j)
of (A,B) satisfies

	A * v(j) = lambda(j) * B * v(j).

The left eigenvector u(j) corresponding to the eigenvalue lambda(j)
of (A,B) satisfies

	u(j)**H * A  = lambda(j) * u(j)**H * B .

	where u(j)**H is the conjugate-transpose of u(j).

    Arguments
    =========

    jobvl:  = 0:  do not compute the left generalized eigenvectors;
            = 1:  compute the left generalized eigenvectors.

    jobvr:  = 0:  do not compute the right generalized eigenvectors;
            = 1:  compute the right generalized eigenvectors.

    A:      On entry, the matrix A in the pair (A,B).
            On exit, A has been overwritten.

    B:      On entry, the matrix B in the pair (A,B).
            On exit, B has been overwritten.

    alphar:
    alphai:
    beta:   On exit, (alphar(j) + alphai(j)*i)/beta(j), j=1,...,N, will
            be the generalized eigenvalues.  If alphai(j) is zero, then
            the j-th eigenvalue is real; if positive, then the j-th and
            (j+1)-st eigenvalues are a complex conjugate pair, with
            alphai(j+1) negative.

            Note: the quotients alphar(j)/beta(j) and alphai(j)/beta(j)
            may easily over- or underflow, and beta(j) may even be zero.
            Thus, the user should avoid naively computing the ratio
            alpha/beta.  However, alphar and alphai will be always less
            than and usually comparable with norm(A) in magnitude, and
            beta always less than and usually comparable with norm(B).

    VL:     If jobvl = 1, the left eigenvectors u(j) are stored one
            after another in the columns of VL, in the same order as
            their eigenvalues. If the j-th eigenvalue is real, then
            u(j) = VL(:,j), the j-th column of VL. If the j-th and
            (j+1)-th eigenvalues form a complex conjugate pair, then
            u(j) = VL(:,j)+i*VL(:,j+1) and u(j+1) = VL(:,j)-i*VL(:,j+1).
            Each eigenvector will be scaled so the largest component have
            abs(real part)+abs(imag. part)=1.
            Not referenced if jobvl = 0.

    VR:     If jobvr = 1, the right eigenvectors v(j) are stored one
            after another in the columns of VR, in the same order as
            their eigenvalues. If the j-th eigenvalue is real, then
            v(j) = VR(:,j), the j-th column of VR. If the j-th and
            (j+1)-th eigenvalues form a complex conjugate pair, then
            v(j) = VR(:,j)+i*VR(:,j+1) and v(j+1) = VR(:,j)-i*VR(:,j+1).
            Each eigenvector will be scaled so the largest component have
            abs(real part)+abs(imag. part)=1.
            Not referenced if jobvr = 0.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value.
            = 1,...,N:
                  The QZ iteration failed.  No eigenvectors have been
                  calculated, but alphar(j), alphai(j), and beta(j)
                  should be correct for j=info+1,...,N.
            > N:  =N+1: other than QZ iteration failed in hgeqz.
                  =N+2: error return from tgevc.

=for example

 $a = random(5,5);
 $b = random(5,5);
 $alphar = zeroes(5);
 $alphai = zeroes(5);
 $beta = zeroes(5);
 $vl = zeroes(5,5);
 $vr = zeroes(5,5);
 ggev($a, 1, 1, $b, $alphar, $alphai, $beta, $vl, $vr, ($info=null));

=for bad

ggev ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*ggev = \&PDL::ggev;






=head2 ggevx

=for sig

  Signature: ([io]A(n,n);int balanc();int jobvl();int jobvr();int sense();[io]B(n,n);[o]alphar(n);[o]alphai(n);[o]beta(n);[o]VL(m,m);[o]VR(p,p);int [o]ilo();int [o]ihi();[o]lscale(n);[o]rscale(n);[o]abnrm();[o]bbnrm();[o]rconde(r);[o]rcondv(s);int [o]info(); int [t]bwork(bworkn); int [t]iwork(iworkn))

=for ref

Computes for a pair of N-by-N real nonsymmetric matrices (A,B)
the generalized eigenvalues, and optionally, the left and/or right
generalized eigenvectors.

Optionally also, it computes a balancing transformation to improve
the conditioning of the eigenvalues and eigenvectors (ilo, ihi,
lscale, rscale, abnrm, and bbnrm), reciprocal condition numbers for
the eigenvalues (rconde), and reciprocal condition numbers for the
right eigenvectors (rcondv).

A generalized eigenvalue for a pair of matrices (A,B) is a scalar
lambda or a ratio alpha/beta = lambda, such that A - lambda*B is
singular. It is usually represented as the pair (alpha,beta), as
there is a reasonable interpretation for beta=0, and even for both
being zero.

The right eigenvector v(j) corresponding to the eigenvalue lambda(j)
of (A,B) satisfies

	A * v(j) = lambda(j) * B * v(j) .

The left eigenvector u(j) corresponding to the eigenvalue lambda(j)
of (A,B) satisfies

	u(j)**H * A  = lambda(j) * u(j)**H * B.

	where u(j)**H is the conjugate-transpose of u(j).

Further Details
===============

Balancing a matrix pair (A,B) includes, first, permuting rows and
columns to isolate eigenvalues, second, applying diagonal similarity
transformation to the rows and columns to make the rows and columns
as close in norm as possible. The computed reciprocal condition
numbers correspond to the balanced matrix. Permuting rows and columns
will not change the condition numbers (in exact arithmetic) but
diagonal scaling will.  For further explanation of balancing, see
section 4.11.1.2 of LAPACK Users' Guide.

An approximate error bound on the chordal distance between the i-th
computed generalized eigenvalue w and the corresponding exact
eigenvalue lambda is

	chord(w, lambda) <= EPS * norm(abnrm, bbnrm) / rconde(I)

An approximate error bound for the angle between the i-th computed
eigenvector vl(i) or vr(i) is given by

	EPS * norm(abnrm, bbnrm) / DIF(i).

For further explanation of the reciprocal condition numbers rconde
and rcondv, see section 4.11 of LAPACK User's Guide.

    Arguments
    =========

    balanc: Specifies the balance option to be performed.
            = 0:  do not diagonally scale or permute;
            = 1:  permute only;
            = 2:  scale only;
            = 3:  both permute and scale.
            Computed reciprocal condition numbers will be for the
            matrices after permuting and/or balancing. Permuting does
            not change condition numbers (in exact arithmetic), but
            balancing does.

    jobvl:  = 0:  do not compute the left generalized eigenvectors;
            = 1:  compute the left generalized eigenvectors.

    jobvr:  = 0:  do not compute the right generalized eigenvectors;
            = 1:  compute the right generalized eigenvectors.

    sense:  Determines which reciprocal condition numbers are computed.
            = 0: none are computed;
            = 1: computed for eigenvalues only;
            = 2: computed for eigenvectors only;
            = 3: computed for eigenvalues and eigenvectors.

    A:      On entry, the matrix A in the pair (A,B).
            On exit, A has been overwritten. If jobvl=1 or jobvr=1
            or both, then A contains the first part of the real Schur
            form of the "balanced" versions of the input A and B.

    B:      On entry, the matrix B in the pair (A,B).
            On exit, B has been overwritten. If jobvl=1 or jobvr=1
            or both, then B contains the second part of the real Schur
            form of the "balanced" versions of the input A and B.

    alphar:
    alphai:
    beta:   On exit, (alphar(j) + alphai(j)*i)/beta(j), j=1,...,N, will
            be the generalized eigenvalues.  If alphai(j) is zero, then
            the j-th eigenvalue is real; if positive, then the j-th and
            (j+1)-st eigenvalues are a complex conjugate pair, with
            alphai(j+1) negative.

            Note: the quotients alphar(j)/beta(j) and alphai(j)/beta(j)
            may easily over- or underflow, and beta(j) may even be zero.
            Thus, the user should avoid naively computing the ratio
            ALPHA/beta. However, alphar and alphai will be always less
            than and usually comparable with norm(A) in magnitude, and
            beta always less than and usually comparable with norm(B).

    vl:     If jobvl = 1, the left eigenvectors u(j) are stored one
            after another in the columns of vl, in the same order as
            their eigenvalues. If the j-th eigenvalue is real, then
            u(j) = vl(:,j), the j-th column of vl. If the j-th and
            (j+1)-th eigenvalues form a complex conjugate pair, then
            u(j) = vl(:,j)+i*vl(:,j+1) and u(j+1) = vl(:,j)-i*vl(:,j+1).
            Each eigenvector will be scaled so the largest component have
            abs(real part) + abs(imag. part) = 1.
            Not referenced if jobvl = 0.

    vr:     If jobvr = 1, the right eigenvectors v(j) are stored one
            after another in the columns of vr, in the same order as
            their eigenvalues. If the j-th eigenvalue is real, then
            v(j) = vr(:,j), the j-th column of vr. If the j-th and
            (j+1)-th eigenvalues form a complex conjugate pair, then
            v(j) = vr(:,j)+i*vr(:,j+1) and v(j+1) = vr(:,j)-i*vr(:,j+1).
            Each eigenvector will be scaled so the largest component have
            abs(real part) + abs(imag. part) = 1.
            Not referenced if jobvr = 0.

    ilo,ihi:ilo and ihi are integer values such that on exit
            A(i,j) = 0 and B(i,j) = 0 if i > j and
            j = 1,...,ilo-1 or i = ihi+1,...,N.
            If balanc = 0 or 2, ilo = 1 and ihi = N.

    lscale: Details of the permutations and scaling factors applied
            to the left side of A and B.  If PL(j) is the index of the
            row interchanged with row j, and DL(j) is the scaling
            factor applied to row j, then
              lscale(j) = PL(j)  for j = 1,...,ilo-1
                        = DL(j)  for j = ilo,...,ihi
                        = PL(j)  for j = ihi+1,...,N.
            The order in which the interchanges are made is N to ihi+1,
            then 1 to ilo-1.

    rscale: Details of the permutations and scaling factors applied
            to the right side of A and B.  If PR(j) is the index of the
            column interchanged with column j, and DR(j) is the scaling
            factor applied to column j, then
              rscale(j) = PR(j)  for j = 1,...,ilo-1
                        = DR(j)  for j = ilo,...,ihi
                        = PR(j)  for j = ihi+1,...,N
            The order in which the interchanges are made is N to ihi+1,
            then 1 to ilo-1.

    abnrm:  The one-norm of the balanced matrix A.

    bbnrm:  The one-norm of the balanced matrix B.

    rconde: If sense = 1 or 3, the reciprocal condition numbers of
            the selected eigenvalues, stored in consecutive elements of
            the array. For a complex conjugate pair of eigenvalues two
            consecutive elements of rconde are set to the same value.
            Thus rconde(j), rcondv(j), and the j-th columns of vl and vr
            all correspond to the same eigenpair (but not in general the
            j-th eigenpair, unless all eigenpairs are selected).
            If sense = 2, rconde is not referenced.

    rcondv: If sense = 2 or 3, the estimated reciprocal condition
            numbers of the selected eigenvectors, stored in consecutive
            elements of the array. For a complex eigenvector two
            consecutive elements of rcondv are set to the same value. If
            the eigenvalues cannot be reordered to compute rcondv(j),
            rcondv(j) is set to 0; this can only occur when the true
            value would be very small anyway.
            If sense = 1, rcondv is not referenced.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value.
            = 1,...,N:
                  The QZ iteration failed.  No eigenvectors have been
                  calculated, but alphar(j), alphai(j), and beta(j)
                  should be correct for j=info+1,...,N.
            > N:  =N+1: other than QZ iteration failed in hgeqz.
                  =N+2: error return from tgevc.

=for example

 $a = random(5,5);
 $b = random(5,5);
 $alphar = zeroes(5);
 $alphai = zeroes(5);
 $beta = zeroes(5);
 $vl = zeroes(5,5);
 $vr = zeroes(5,5);
 $lscale = zeroes(5);
 $rscale = zeroes(5);
 $ilo = null;
 $ihi = null;
 $abnrm = null;
 $bbnrm = null;
 $rconde = zeroes(5);
 $rcondv = zeroes(5);
 ggevx($a, 3, 1, 1, 3, $b, $alphar, $alphai, $beta, $vl, $vr,
 $ilo, $ihi, $lscale, $rscale, $abnrm, $bbnrm, $rconde,$rcondv,($info=null));

=for bad

ggevx ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*ggevx = \&PDL::ggevx;






=head2 gees

=for sig

  Signature: ([io]A(n,n);  int jobvs(); int sort(); [o]wr(n); [o]wi(n); [o]vs(p,p); int [o]sdim(); int [o]info(); int [t]bwork(bworkn); SV* select_func)

=for ref

Computes for an N-by-N real nonsymmetric matrix A, the
eigenvalues, the real Schur form T, and, optionally, the matrix of
Schur vectors Z.  This gives the Schur factorization A = Z*T*Z'.

Optionally, it also orders the eigenvalues on the diagonal of the
real Schur form so that selected eigenvalues are at the top left.
The leading columns of Z then form an orthonormal basis for the
invariant subspace corresponding to the selected eigenvalues.

A matrix is in real Schur form if it is upper quasi-triangular with
1-by-1 and 2-by-2 blocks. 2-by-2 blocks will be standardized in the
form

	[  a  b  ]
	[  c  a  ]
        where b*c < 0.

The eigenvalues of such a block are a +- sqrt(bc).

    Arguments
    =========

    jobvs:  = 0: Schur vectors are not computed;
            = 1: Schur vectors are computed.

    sort:   Specifies whether or not to order the eigenvalues on the
            diagonal of the Schur form.
            = 0: Eigenvalues are not ordered;
            = 1: Eigenvalues are ordered (see select_func).

    select_func:
            If sort = 1, select_func is used to select eigenvalues to sort
            to the top left of the Schur form.
            If sort = 0, select_func is not referenced.
            An eigenvalue wr(j)+sqrt(-1)*wi(j) is selected if
            select_func(SCALAR(wr(j)), SCALAR(wi(j))) is true; i.e.,
	    if either one of a complex conjugate pair of eigenvalues
	    is selected, then both complex eigenvalues are selected.
            Note that a selected complex eigenvalue may no longer
            satisfy select_func(wr(j),wi(j)) = 1 after ordering, since
            ordering may change the value of complex eigenvalues
            (especially if the eigenvalue is ill-conditioned); in this
            case info is set to N+2 (see info below).

    A:	    The N-by-N matrix A.
            On exit, A has been overwritten by its real Schur form T.

    sdim:   If sort = 0, sdim = 0.
            If sort = 1, sdim = number of eigenvalues (after sorting)
                           for which select_func is true. (Complex conjugate
                           pairs for which select_func is true for either
                           eigenvalue count as 2.)

    wr:
    wi:     wr and wi contain the real and imaginary parts,
            respectively, of the computed eigenvalues in the same order
            that they appear on the diagonal of the output Schur form T.
            Complex conjugate pairs of eigenvalues will appear
            consecutively with the eigenvalue having the positive
            imaginary part first.

    vs:     If jobvs = 1, vs contains the orthogonal matrix Z of Schur
            vectors else vs is not referenced.

    info    = 0: successful exit
            < 0: if info = -i, the i-th argument had an illegal value.
            > 0: if info = i, and i is
               <= N: the QR algorithm failed to compute all the
                     eigenvalues; elements 1:ILO-1 and i+1:N of wr and wi
                     contain those eigenvalues which have converged; if
                     jobvs = 1, vs contains the matrix which reduces A
                     to its partially converged Schur form.
               = N+1: the eigenvalues could not be reordered because some
                     eigenvalues were too close to separate (the problem
                     is very ill-conditioned);
               = N+2: after reordering, roundoff changed values of some
                     complex eigenvalues so that leading eigenvalues in
                     the Schur form no longer satisfy select_func = 1  This
                     could also be caused by underflow due to scaling.

=for example

 sub select_function{
	my ($a, $b ) = @_;
	# Stable "continuous time" eigenspace
	return $a < 0 ? 1 : 0;
 }
 $A = random (5,5);
 $wr= zeroes(5);
 $wi = zeroes(5);
 $vs = zeroes(5,5);
 $sdim  = null;
 $info = null;
 gees($A, 1,1, $wr, $wi, $vs, $sdim, $info,\&select_function);

=for bad

gees ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*gees = \&PDL::gees;






=head2 geesx

=for sig

  Signature: ([io]A(n,n);  int jobvs(); int sort(); int sense(); [o]wr(n); [o]wi(n); [o]vs(p,p); int [o]sdim(); [o]rconde();[o]rcondv(); int [o]info(); int [t]bwork(bworkn); SV* select_func)

=for ref

Computes for an N-by-N real nonsymmetric matrix A, the
eigenvalues, the real Schur form T, and, optionally, the matrix of
Schur vectors Z.  This gives the Schur factorization A = Z*T*Z'.

Optionally, it also orders the eigenvalues on the diagonal of the
real Schur form so that selected eigenvalues are at the top left;
computes a reciprocal condition number for the average of the
selected eigenvalues (rconde); and computes a reciprocal condition
number for the right invariant subspace corresponding to the
selected eigenvalues (rcondv).  The leading columns of Z form an
orthonormal basis for this invariant subspace.

For further explanation of the reciprocal condition numbers rconde
and rcondv, see Section 4.10 of the LAPACK Users' Guide (where
these quantities are called s and sep respectively).

A real matrix is in real Schur form if it is upper quasi-triangular
with 1-by-1 and 2-by-2 blocks. 2-by-2 blocks will be standardized in
the form

	[  a  b  ]
	[  c  a  ]
        where b*c < 0. The eigenvalues of such a block are a +- sqrt(bc).

    Arguments
    =========

    jobvs:  = 0: Schur vectors are not computed;
            = 1: Schur vectors are computed.

    sort:   Specifies whether or not to order the eigenvalues on the
            diagonal of the Schur form.
            = 0: Eigenvalues are not ordered;
            = 1: Eigenvalues are ordered (see select_func).

    select_func:
            If sort = 1, select_func is used to select eigenvalues to sort
            to the top left of the Schur form else select_func is not referenced.
            An eigenvalue wr(j)+sqrt(-1)*wi(j) is selected if
            select_func(wr(j),wi(j)) is true; i.e., if either one of a
            complex conjugate pair of eigenvalues is selected, then both
            are.  Note that a selected complex eigenvalue may no longer
            satisfy select_func(wr(j),wi(j)) = 1 after ordering, since
            ordering may change the value of complex eigenvalues
            (especially if the eigenvalue is ill-conditioned); in this
            case info may be set to N+3 (see info below).

    sense:  Determines which reciprocal condition numbers are computed.
            = 0: None are computed;
            = 1: Computed for average of selected eigenvalues only;
            = 2: Computed for selected right invariant subspace only;
            = 3: Computed for both.
            If sense = 1, 2 or 3, sort must equal 1.

    A:      On entry, the N-by-N matrix A.
            On exit, A is overwritten by its real Schur form T.

    sdim:   If sort = 0, sdim = 0.
            If sort = 1, sdim = number of eigenvalues (after sorting)
                           for which select_func is 1. (Complex conjugate
                           pairs for which select_func is 1 for either
                           eigenvalue count as 2.)

    wr:
    wi:     wr and wi contain the real and imaginary parts, respectively,
            of the computed eigenvalues, in the same order that they
            appear on the diagonal of the output Schur form T.  Complex
            conjugate pairs of eigenvalues appear consecutively with the
            eigenvalue having the positive imaginary part first.

    vs      If jobvs = 1, vs contains the orthogonal matrix Z of Schur
            vectors else vs is not referenced.

    rconde: If sense = 1 or 3, rconde contains the reciprocal
            condition number for the average of the selected eigenvalues.
            Not referenced if sense = 0 or 2.

    rcondv: If sense = 2 or 3, rcondv contains the reciprocal
            condition number for the selected right invariant subspace.
            Not referenced if sense = 0 or 1.

    info:   = 0: successful exit
            < 0: if info = -i, the i-th argument had an illegal value.
            > 0: if info = i, and i is
               <= N: the QR algorithm failed to compute all the
                     eigenvalues; elements 1:ilo-1 and i+1:N of wr and wi
                     contain those eigenvalues which have converged; if
                     jobvs = 1, vs contains the transformation which
                     reduces A to its partially converged Schur form.
               = N+1: the eigenvalues could not be reordered because some
                     eigenvalues were too close to separate (the problem
                     is very ill-conditioned);
               = N+2: after reordering, roundoff changed values of some
                     complex eigenvalues so that leading eigenvalues in
                     the Schur form no longer satisfy select_func=1  This
                     could also be caused by underflow due to scaling.

=for example

 sub select_function{
	my ($a, $b) = @_;
	# Stable "discrete time" eigenspace
	return sqrt($a**2 + $b**2) < 1 ? 1 : 0;
 }
 $A = random (5,5);
 $wr= zeroes(5);
 $wi = zeroes(5);
 $vs = zeroes(5,5);
 $sdim  = null;
 $rconde = null;
 $rcondv = null;
 $info = null;
 geesx($A, 1,1, 3, $wr, $wi, $vs, $sdim, $rconde, $rcondv, $info, \&select_function);

=for bad

geesx ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*geesx = \&PDL::geesx;






=head2 gges

=for sig

  Signature: ([io]A(n,n); int jobvsl();int jobvsr();int sort();[io]B(n,n);[o]alphar(n);[o]alphai(n);[o]beta(n);[o]VSL(m,m);[o]VSR(p,p);int [o]sdim();int [o]info(); int [t]bwork(bworkn); SV* select_func)

=for ref

Computes for a pair of N-by-N real nonsymmetric matrices (A,B),
the generalized eigenvalues, the generalized real Schur form (S,T),
optionally, the left and/or right matrices of Schur vectors (VSL and
VSR). This gives the generalized Schur factorization

	(A,B) = ( (VSL)*S*(VSR)', (VSL)*T*(VSR)' )

Optionally, it also orders the eigenvalues so that a selected cluster
of eigenvalues appears in the leading diagonal blocks of the upper
quasi-triangular matrix S and the upper triangular matrix T.The
leading columns of VSL and VSR then form an orthonormal basis for the
corresponding left and right eigenspaces (deflating subspaces).

(If only the generalized eigenvalues are needed, use the driver
ggev instead, which is faster.)

A generalized eigenvalue for a pair of matrices (A,B) is a scalar w
or a ratio alpha/beta = w, such that  A - w*B is singular.  It is
usually represented as the pair (alpha,beta), as there is a
reasonable interpretation for beta=0 or both being zero.

A pair of matrices (S,T) is in generalized real Schur form if T is
upper triangular with non-negative diagonal and S is block upper
triangular with 1-by-1 and 2-by-2 blocks.  1-by-1 blocks correspond
to real generalized eigenvalues, while 2-by-2 blocks of S will be
"standardized" by making the corresponding elements of T have the
form:

	[  a  0  ]
	[  0  b  ]

and the pair of corresponding 2-by-2 blocks in S and T will have a
complex conjugate pair of generalized eigenvalues.

    Arguments
    =========

    jobvsl: = 0:  do not compute the left Schur vectors;
            = 1:  compute the left Schur vectors.

    jobvsr: = 0:  do not compute the right Schur vectors;
            = 1:  compute the right Schur vectors.

    sort:   Specifies whether or not to order the eigenvalues on the
            diagonal of the generalized Schur form.
            = 0:  Eigenvalues are not ordered;
            = 1:  Eigenvalues are ordered (see delztg);

    delztg: If sort = 0, delztg is not referenced.
            If sort = 1, delztg is used to select eigenvalues to sort
            to the top left of the Schur form.
            An eigenvalue (alphar(j)+alphai(j))/beta(j) is selected if
            delztg(alphar(j),alphai(j),beta(j)) is true; i.e. if either
            one of a complex conjugate pair of eigenvalues is selected,
            then both complex eigenvalues are selected.

            Note that in the ill-conditioned case, a selected complex
            eigenvalue may no longer satisfy delztg(alphar(j),alphai(j),
            beta(j)) = 1 after ordering. info is to be set to N+2
            in this case.

    A:      On entry, the first of the pair of matrices.
            On exit, A has been overwritten by its generalized Schur
            form S.

    B:      On entry, the second of the pair of matrices.
            On exit, B has been overwritten by its generalized Schur
            form T.

    sdim:   If sort = 0, sdim = 0.
            If sort = 1, sdim = number of eigenvalues (after sorting)
            for which delztg is true.  (Complex conjugate pairs for which
            delztg is true for either eigenvalue count as 2.)

    alphar:
    alphai:
    beta:   On exit, (alphar(j) + alphai(j)*i)/beta(j), j=1,...,N, will
            be the generalized eigenvalues.  alphar(j) + alphai(j)*i,
            and  beta(j),j=1,...,N are the diagonals of the complex Schur
            form (S,T) that would result if the 2-by-2 diagonal blocks of
            the real Schur form of (A,B) were further reduced to
            triangular form using 2-by-2 complex unitary transformations.
            If alphai(j) is zero, then the j-th eigenvalue is real; if
            positive, then the j-th and (j+1)-st eigenvalues are a
            complex conjugate pair, with alphai(j+1) negative.

            Note: the quotients alphar(j)/beta(j) and alphai(j)/beta(j)
            may easily over- or underflow, and beta(j) may even be zero.
            Thus, the user should avoid naively computing the ratio.
            However, alphar and alphai will be always less than and
            usually comparable with norm(A) in magnitude, and beta always
            less than and usually comparable with norm(B).

    VSL:    If jobvsl = 1, VSL will contain the left Schur vectors.
            Not referenced if jobvsl = 0.
            The leading dimension must always be >=1.

    VSR:    If jobvsr = 1, VSR will contain the right Schur vectors.
            Not referenced if jobvsr = 0.
            The leading dimension must always be >=1.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value.
            = 1,...,N:
                  The QZ iteration failed.  (A,B) are not in Schur
                  form, but alphar(j), alphai(j), and beta(j) should
                  be correct for j=info+1,...,N.
            > N:  =N+1: other than QZ iteration failed in hgeqz.
                  =N+2: after reordering, roundoff changed values of
                        some complex eigenvalues so that leading
                        eigenvalues in the Generalized Schur form no
                        longer satisfy delztg=1  This could also
                        be caused due to scaling.
                  =N+3: reordering failed in tgsen.

=for example

 sub my_select{
	my ($zr, $zi, $d) = @_;
	# stable generalized eigenvalues for continuous time
	return ( ($zr < 0 && $d > 0 ) || ($zr > 0 && $d < 0) ) ?  1 : 0;
 }
 $a = random(5,5);
 $b = random(5,5);
 $sdim = null;
 $alphar = zeroes(5);
 $alphai = zeroes(5);
 $beta = zeroes(5);
 $vsl = zeroes(5,5);
 $vsr = zeroes(5,5);
 gges($a, 1, 1, 1, $b, $alphar, $alphai, $beta, $vsl, $vsr, $sdim,($info=null), \&my_select);

=for bad

gges ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*gges = \&PDL::gges;






=head2 ggesx

=for sig

  Signature: ([io]A(n,n); int jobvsl();int jobvsr();int sort();int sense();[io]B(n,n);[o]alphar(n);[o]alphai(n);[o]beta(n);[o]VSL(m,m);[o]VSR(p,p);int [o]sdim();[o]rconde(q=2);[o]rcondv(q=2);int [o]info(); int [t]bwork(bworkn); int [t]iwork(iworkn); SV* select_func)

=for ref

Computes for a pair of N-by-N real nonsymmetric matrices
(A,B), the generalized eigenvalues, the real Schur form (S,T), and,
optionally, the left and/or right matrices of Schur vectors (VSL and
VSR).  This gives the generalized Schur factorization

	(A,B) = ( (VSL) S (VSR)', (VSL) T (VSR)' )

Optionally, it also orders the eigenvalues so that a selected cluster
of eigenvalues appears in the leading diagonal blocks of the upper
quasi-triangular matrix S and the upper triangular matrix T; computes
a reciprocal condition number for the average of the selected
eigenvalues (RCONDE); and computes a reciprocal condition number for
the right and left deflating subspaces corresponding to the selected
eigenvalues (RCONDV). The leading columns of VSL and VSR then form
an orthonormal basis for the corresponding left and right eigenspaces
(deflating subspaces).

A generalized eigenvalue for a pair of matrices (A,B) is a scalar w
or a ratio alpha/beta = w, such that  A - w*B is singular.  It is
usually represented as the pair (alpha,beta), as there is a
reasonable interpretation for beta=0 or for both being zero.

A pair of matrices (S,T) is in generalized real Schur form if T is
upper triangular with non-negative diagonal and S is block upper
triangular with 1-by-1 and 2-by-2 blocks.  1-by-1 blocks correspond
to real generalized eigenvalues, while 2-by-2 blocks of S will be
"standardized" by making the corresponding elements of T have the
form:

	[  a  0  ]
	[  0  b  ]

and the pair of corresponding 2-by-2 blocks in S and T will have a
complex conjugate pair of generalized eigenvalues.

Further details
===============

An approximate (asymptotic) bound on the average absolute error of
the selected eigenvalues is

	EPS * norm((A, B)) / RCONDE( 1 ).

An approximate (asymptotic) bound on the maximum angular error in
the computed deflating subspaces is

	EPS * norm((A, B)) / RCONDV( 2 ).

See LAPACK User's Guide, section 4.11 for more information.

    Arguments
    =========

    jobvsl: = 0:  do not compute the left Schur vectors;
            = 1:  compute the left Schur vectors.

    jobvsr: = 0:  do not compute the right Schur vectors;
            = 1:  compute the right Schur vectors.

    sort:   Specifies whether or not to order the eigenvalues on the
            diagonal of the generalized Schur form.
            = 0:  Eigenvalues are not ordered;
            = 1:  Eigenvalues are ordered (see delztg);

    delztg: If sort = 0, delztg is not referenced.
            If sort = 1, delztg is used to select eigenvalues to sort
            to the top left of the Schur form.
            An eigenvalue (alphar(j)+alphai(j))/beta(j) is selected if
            delztg(alphar(j),alphai(j),beta(j)) is true; i.e. if either
            one of a complex conjugate pair of eigenvalues is selected,
            then both complex eigenvalues are selected.

            Note that in the ill-conditioned case, a selected complex
            eigenvalue may no longer satisfy delztg(alphar(j),alphai(j),
            beta(j)) = 1 after ordering. info is to be set to N+2
            in this case.

    sense:  Determines which reciprocal condition numbers are computed.
            = 0 : None are computed;
            = 1 : Computed for average of selected eigenvalues only;
            = 2 : Computed for selected deflating subspaces only;
            = 3 : Computed for both.
            If sense = 1, 2, or 3, sort must equal 1.

    A:      On entry, the first of the pair of matrices.
            On exit, A has been overwritten by its generalized Schur
            form S.

    B:      On entry, the second of the pair of matrices.
            On exit, B has been overwritten by its generalized Schur
            form T.

    sdim:   If sort = 0, sdim = 0.
            If sort = 1, sdim = number of eigenvalues (after sorting)
            for which delztg is true.  (Complex conjugate pairs for which
            delztg is true for either eigenvalue count as 2.)

    alphar:
    alphai:
    beta:   On exit, (alphar(j) + alphai(j)*i)/beta(j), j=1,...,N, will
            be the generalized eigenvalues.  alphar(j) + alphai(j)*i,
            and  beta(j),j=1,...,N are the diagonals of the complex Schur
            form (S,T) that would result if the 2-by-2 diagonal blocks of
            the real Schur form of (A,B) were further reduced to
            triangular form using 2-by-2 complex unitary transformations.
            If alphai(j) is zero, then the j-th eigenvalue is real; if
            positive, then the j-th and (j+1)-st eigenvalues are a
            complex conjugate pair, with alphai(j+1) negative.

            Note: the quotients alphar(j)/beta(j) and alphai(j)/beta(j)
            may easily over- or underflow, and beta(j) may even be zero.
            Thus, the user should avoid naively computing the ratio.
            However, alphar and alphai will be always less than and
            usually comparable with norm(A) in magnitude, and beta always
            less than and usually comparable with norm(B).

    VSL:    If jobvsl = 1, VSL will contain the left Schur vectors.
            Not referenced if jobvsl = 0.
            The leading dimension must always be >=1.

    VSR:    If jobvsr = 1, VSR will contain the right Schur vectors.
            Not referenced if jobvsr = 0.
            The leading dimension must always be >=1.

    rconde: If sense = 1 or 3, rconde(1) and rconde(2) contain the
            reciprocal condition numbers for the average of the selected
            eigenvalues.
            Not referenced if sense = 0 or 2.

    rcondv: If sense = 2 or 3, rcondv(1) and rcondv(2) contain the
            reciprocal condition numbers for the selected deflating
            subspaces.
            Not referenced if sense = 0 or 1.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value.
            = 1,...,N:
                  The QZ iteration failed.  (A,B) are not in Schur
                  form, but alphar(j), alphai(j), and beta(j) should
                  be correct for j=info+1,...,N.
            > N:  =N+1: other than QZ iteration failed in hgeqz.
                  =N+2: after reordering, roundoff changed values of
                        some complex eigenvalues so that leading
                        eigenvalues in the Generalized Schur form no
                        longer satisfy delztg=1  This could also
                        be caused due to scaling.
                  =N+3: reordering failed in tgsen.

=for example

 sub my_select{
	my ($zr, $zi, $d) = @_;
	# Eigenvalue : (ZR/D) + sqrt(-1)*(ZI/D)
	# stable generalized eigenvalues for discrete time
	return (sqrt($zr**2 + $zi**2) < abs($d) ) ?  1 : 0;

 }
 $a = random(5,5);
 $b = random(5,5);
 $sdim = null;
 $alphar = zeroes(5);
 $alphai = zeroes(5);
 $beta = zeroes(5);
 $vsl = zeroes(5,5);
 $vsr = zeroes(5,5);
 $rconde = zeroes(2);
 $rcondv = zeroes(2);
 ggesx($a, 1, 1, 1, 3,$b, $alphar, $alphai, $beta, $vsl, $vsr, $sdim, $rconde, $rcondv, ($info=null), \&my_select);

=for bad

ggesx ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*ggesx = \&PDL::ggesx;






=head2 syev

=for sig

  Signature: ([io]A(n,n);  int jobz(); int uplo(); [o]w(n); int [o]info())

=for ref

Computes all eigenvalues and, optionally, eigenvectors of a
real symmetric matrix A.

    Arguments
    =========

    jobz:   = 0:  Compute eigenvalues only;
            = 1:  Compute eigenvalues and eigenvectors.

    uplo    = 0:  Upper triangle of A is stored;
            = 1:  Lower triangle of A is stored.

    A:      On entry, the symmetric matrix A.  If uplo = 0, the
            leading N-by-N upper triangular part of A contains the
            upper triangular part of the matrix A.  If uplo = 1,
            the leading N-by-N lower triangular part of A contains
            the lower triangular part of the matrix A.
            On exit, if jobz = 1, then if info = 0, A contains the
            orthonormal eigenvectors of the matrix A.
            If jobz = 0, then on exit the lower triangle (if uplo=1)
            or the upper triangle (if uplo=0) of A, including the
            diagonal, is destroyed.

    w:      If info = 0, the eigenvalues in ascending order.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value
            > 0:  if info = i, the algorithm failed to converge; i
                  off-diagonal elements of an intermediate tridiagonal
                  form did not converge to zero.

=for example

 # Assume $a is symmetric ;)
 $a = random (5,5);
 syev($a, 1,1, (my $w = zeroes(5)), (my $info=null));

=for bad

syev ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*syev = \&PDL::syev;






=head2 syevd

=for sig

  Signature: ([io]A(n,n);  int jobz(); int uplo(); [o]w(n); int [o]info())

=for ref

Computes all eigenvalues and, optionally, eigenvectors of a
real symmetric matrix A. If eigenvectors are desired, it uses a
divide and conquer algorithm.

The divide and conquer algorithm makes very mild assumptions about
floating point arithmetic. It will work on machines with a guard
digit in add/subtract, or on those binary machines without guard
digits which subtract like the Cray X-MP, Cray Y-MP, Cray C-90, or
Cray-2. It could conceivably fail on hexadecimal or decimal machines
without guard digits, but we know of none.

Because of large use of BLAS of level 3, syevd needs N**2 more
workspace than syevx.

    Arguments
    =========

    jobz:   = 0:  Compute eigenvalues only;
            = 1:  Compute eigenvalues and eigenvectors.

    uplo    = 0:  Upper triangle of A is stored;
            = 1:  Lower triangle of A is stored.

    A:      On entry, the symmetric matrix A.  If uplo = 0, the
            leading N-by-N upper triangular part of A contains the
            upper triangular part of the matrix A.  If uplo = 1,
            the leading N-by-N lower triangular part of A contains
            the lower triangular part of the matrix A.
            On exit, if jobz = 1, then if info = 0, A contains the
            orthonormal eigenvectors of the matrix A.
            If jobz = 0, then on exit the lower triangle (if uplo=1)
            or the upper triangle (if uplo=0) of A, including the
            diagonal, is destroyed.

    w:      If info = 0, the eigenvalues in ascending order.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value
            > 0:  if info = i, the algorithm failed to converge; i
                  off-diagonal elements of an intermediate tridiagonal
                  form did not converge to zero.

=for example

 # Assume $a is symmetric ;)
 $a = random (5,5);
 syevd($a, 1,1, (my $w = zeroes(5)), (my $info=null));

=for bad

syevd ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*syevd = \&PDL::syevd;






=head2 syevx

=for sig

  Signature: ([io]A(n,n);  int jobz(); int range(); int uplo(); vl(); vu(); int il(); int iu(); abstol(); int [o]m(); [o]w(n); [o]z(p,p);int [o]ifail(n); int [o]info(); int [t]iwork(iworkn=CALC(5*$SIZE(n))))

=for ref

Computes selected eigenvalues and, optionally, eigenvectors
of a real symmetric matrix A.  Eigenvalues and eigenvectors can be
selected by specifying either a range of values or a range of indices
for the desired eigenvalues.

    Arguments
    =========

    jobz:   = 0:  Compute eigenvalues only;
            = 1:  Compute eigenvalues and eigenvectors.

    range:  = 0: all eigenvalues will be found.
            = 1: all eigenvalues in the half-open interval (vl,vu]
                   will be found.
            = 1: the il-th through iu-th eigenvalues will be found.

    uplo    = 0:  Upper triangle of A is stored;
            = 1:  Lower triangle of A is stored.

    A:      On entry, the symmetric matrix A.  If uplo = 0, the
            leading N-by-N upper triangular part of A contains the
            upper triangular part of the matrix A.  If uplo = 1,
            the leading N-by-N lower triangular part of A contains
            the lower triangular part of the matrix A.
            On exit, the lower triangle (if uplo=1) or the upper
            triangle (if uplo=0) of A, including the diagonal, is
            destroyed.

    vl:
    vu:     If range=1, the lower and upper bounds of the interval to
            be searched for eigenvalues. vl < vu.
            Not referenced if range = 0 or 2.

    il:
    iu:     If range=2, the indices (in ascending order) of the
            smallest and largest eigenvalues to be returned.
            1 <= il <= iu <= N, if N > 0; il = 1 and iu = 0 if N = 0.
            Not referenced if range = 0 or 1.

    abstol: The absolute error tolerance for the eigenvalues.
            An approximate eigenvalue is accepted as converged
            when it is determined to lie in an interval [a,b]
            of width less than or equal to

                    abstol + EPS *   max( |a|,|b| ) ,

            where EPS is the machine precision.  If abstol is less than
            or equal to zero, then  EPS*|T|  will be used in its place,
            where |T| is the 1-norm of the tridiagonal matrix obtained
            by reducing A to tridiagonal form.

            Eigenvalues will be computed most accurately when abstol is
            set to twice the underflow threshold 2*lamch(1), not zero.
            If this routine returns with info>0, indicating that some
            eigenvectors did not converge, try setting abstol to
            2*lamch(1).

            See "Computing Small Singular Values of Bidiagonal Matrices
            with Guaranteed High Relative Accuracy," by Demmel and
            Kahan, LAPACK Working Note #3.

    m:      The total number of eigenvalues found.  0 <= m <= N.
            If range = 0, m = N, and if range = 2, m = iu-il+1.

    w:      On normal exit, the first M elements contain the selected
            eigenvalues in ascending order.

    z:      If jobz = 1, then if info = 0, the first m columns of z
            contain the orthonormal eigenvectors of the matrix A
            corresponding to the selected eigenvalues, with the i-th
            column of z holding the eigenvector associated with w(i).
            If an eigenvector fails to converge, then that column of z
            contains the latest approximation to the eigenvector, and the
            index of the eigenvector is returned in ifail.
            If jobz = 0, then z is not referenced.
            Note: the user must ensure that at least max(1,m) columns are
            supplied in the array z; if range = 1, the exact value of m
            is not known in advance and an upper bound must be used.

    ifail:   If jobz = 1, then if info = 0, the first m elements of
            ifail are zero.  If info > 0, then ifail contains the
            indices of the eigenvectors that failed to converge.
            If jobz = 0, then ifail is not referenced.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value
            > 0:  if info = i, then i eigenvectors failed to converge.
                  Their indices are stored in array ifail.

=for example

 # Assume $a is symmetric ;)
 $a = random (5,5);
 $unfl = lamch(1);
 $ovfl = lamch(9);
 labad($unfl, $ovfl);
 $abstol = $unfl + $unfl;
 $m = null;
 $info = null;
 $ifail = zeroes(5);
 $w = zeroes(5);
 $z = zeroes(5,5);
 syevx($a, 1,0,1,0,0,0,0,$abstol, $m, $w, $z ,$ifail, $info);

=for bad

syevx ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*syevx = \&PDL::syevx;






=head2 syevr

=for sig

  Signature: ([io]A(n,n);  int jobz(); int range(); int uplo(); vl(); vu(); int il(); int iu();abstol();int [o]m();[o]w(n); [o]z(p,q);int [o]isuppz(r); int [o]info())

=for ref

Computes selected eigenvalues and, optionally, eigenvectors
of a real symmetric matrix T.  Eigenvalues and eigenvectors can be
selected by specifying either a range of values or a range of
indices for the desired eigenvalues.

Whenever possible, syevr calls stegr to compute the
eigenspectrum using Relatively Robust Representations.  stegr
computes eigenvalues by the dqds algorithm, while orthogonal
eigenvectors are computed from various "good" L D L^T representations
(also known as Relatively Robust Representations). Gram-Schmidt
orthogonalization is avoided as far as possible. More specifically,
the various steps of the algorithm are as follows. For the i-th
unreduced block of T,

       (a) Compute T - sigma_i = L_i D_i L_i^T, such that L_i D_i L_i^T
            is a relatively robust representation,
       (b) Compute the eigenvalues, lambda_j, of L_i D_i L_i^T to high
           relative accuracy by the dqds algorithm,
       (c) If there is a cluster of close eigenvalues, "choose" sigma_i
           close to the cluster, and go to step (a),
       (d) Given the approximate eigenvalue lambda_j of L_i D_i L_i^T,
           compute the corresponding eigenvector by forming a
           rank-revealing twisted factorization.

The desired accuracy of the output can be specified by the input
parameter abstol.

For more details, see "A new O(n^2) algorithm for the symmetric
tridiagonal eigenvalue/eigenvector problem", by Inderjit Dhillon,
Computer Science Division Technical Report No. UCB//CSD-97-971,
UC Berkeley, May 1997.

Note 1 : syevr calls stegr when the full spectrum is requested
on machines which conform to the ieee-754 floating point standard.
syevr calls stebz and stein on non-ieee machines and
when partial spectrum requests are made.

Normal execution of stegr may create NaNs and infinities and
hence may abort due to a floating point exception in environments
which do not handle NaNs and infinities in the ieee standard default
manner.

    Arguments
    =========

    jobz:   = 0:  Compute eigenvalues only;
            = 1:  Compute eigenvalues and eigenvectors.

    range:  = 0: all eigenvalues will be found.
            = 1: all eigenvalues in the half-open interval (vl,vu]
                   will be found.
            = 2: the il-th through iu-th eigenvalues will be found.
   ********* For range = 1 or 2 and iu - il < N - 1, stebz and
   ********* stein are called

    uplo:   = 0:  Upper triangle of A is stored;
            = 1:  Lower triangle of A is stored.

    A:      On entry, the symmetric matrix A.  If uplo = 0, the
            leading N-by-N upper triangular part of A contains the
            upper triangular part of the matrix A.  If uplo = 1,
            the leading N-by-N lower triangular part of A contains
            the lower triangular part of the matrix A.
            On exit, the lower triangle (if uplo=1) or the upper
            triangle (if uplo=0) of A, including the diagonal, is
            destroyed.

    vl:
    vu:     If range=1, the lower and upper bounds of the interval to
            be searched for eigenvalues. vl < vu.
            Not referenced if range = 0 or 2.

    il:
    iu:     If range=2, the indices (in ascending order) of the
            smallest and largest eigenvalues to be returned.
            1 <= il <= iu <= N, if N > 0; il = 1 and iu = 0 if N = 0.
            Not referenced if range = 0 or 1.

    abstol: The absolute error tolerance for the eigenvalues.
            An approximate eigenvalue is accepted as converged
            when it is determined to lie in an interval [a,b]
            of width less than or equal to

                    abstol + EPS *   max( |a|,|b| ) ,

            where EPS is the machine precision.  If abstol is less than
            or equal to zero, then  EPS*|T|  will be used in its place,
            where |T| is the 1-norm of the tridiagonal matrix obtained
            by reducing A to tridiagonal form.

            See "Computing Small Singular Values of Bidiagonal Matrices
            with Guaranteed High Relative Accuracy," by Demmel and
            Kahan, LAPACK Working Note #3.

            If high relative accuracy is important, set abstol to
            lamch(1).  Doing so will guarantee that
            eigenvalues are computed to high relative accuracy when
            possible in future releases.  The current code does not
            make any guarantees about high relative accuracy, but
            future releases will. See J. Barlow and J. Demmel,
            "Computing Accurate Eigensystems of Scaled Diagonally
            Dominant Matrices", LAPACK Working Note #7, for a discussion
            of which matrices define their eigenvalues to high relative
            accuracy.

    m:      The total number of eigenvalues found.  0 <= m <= N.
            If range = 0, m = N, and if range = 2, m = iu-il+1.

    w:      The first m elements contain the selected eigenvalues in
            ascending order.

    z:      If jobz = 1, then if info = 0, the first m columns of z
            contain the orthonormal eigenvectors of the matrix A
            corresponding to the selected eigenvalues, with the i-th
            column of z holding the eigenvector associated with w(i).
            If jobz = 0, then z is not referenced.
            Note: the user must ensure that at least max(1,m) columns are
            supplied in the array z; if range = 1, the exact value of m
            is not known in advance and an upper bound must be used.

    isuppz: array of int, dimension ( 2*max(1,m) )
            The support of the eigenvectors in z, i.e., the indices
            indicating the nonzero elements in z. The i-th eigenvector
            is nonzero only in elements isuppz( 2*i-1 ) through
            isuppz( 2*i ).
   ********* Implemented only for range = 0 or 2 and iu - il = N - 1

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value
            > 0:  Internal error

=for example

 # Assume $a is symmetric ;)
 $a = random (5,5);
 $unfl = lamch(1);
 $ovfl = lamch(9);
 labad($unfl, $ovfl);
 $abstol = $unfl + $unfl;
 $m = null;
 $info = null;
 $isuppz = zeroes(10);
 $w = zeroes(5);
 $z = zeroes(5,5);
 syevr($a, 1,0,1,0,0,0,0,$abstol, $m, $w, $z ,$isuppz, $info);

=for bad

syevr ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*syevr = \&PDL::syevr;






=head2 sygv

=for sig

  Signature: ([io]A(n,n);int itype();int jobz(); int uplo();[io]B(n,n);[o]w(n); int [o]info())

=for ref

Computes all the eigenvalues, and optionally, the eigenvectors
of a real generalized symmetric-definite eigenproblem, of the form
A*x=(lambda)*B*x,  A*Bx=(lambda)*x,  or B*A*x=(lambda)*x.
Here A and B are assumed to be symmetric and B is also
positive definite.

    Arguments
    =========

    itype:  Specifies the problem type to be solved:
            = 1:  A*x = (lambda)*B*x
            = 2:  A*B*x = (lambda)*x
            = 3:  B*A*x = (lambda)*x

    jobz:   = 0:  Compute eigenvalues only;
            = 1:  Compute eigenvalues and eigenvectors.

    uplo:   = 0:  Upper triangles of A and B are stored;
            = 1:  Lower triangles of A and B are stored.

    A:      On entry, the symmetric matrix A.  If uplo = 0, the
            leading N-by-N upper triangular part of A contains the
            upper triangular part of the matrix A.  If uplo = 1,
            the leading N-by-N lower triangular part of A contains
            the lower triangular part of the matrix A.

            On exit, if jobz = 1, then if info = 0, A contains the
            matrix Z of eigenvectors.  The eigenvectors are normalized
            as follows:
            if itype = 1 or 2, Z'*B*Z = I;
            if itype = 3, Z'*inv(B)*Z = I.
            If jobz = 0, then on exit the upper triangle (if uplo=0)
            or the lower triangle (if uplo=1) of A, including the
            diagonal, is destroyed.

    B:      On entry, the symmetric positive definite matrix B.
            If uplo = 0, the leading N-by-N upper triangular part of B
            contains the upper triangular part of the matrix B.
            If uplo = 1, the leading N-by-N lower triangular part of B
            contains the lower triangular part of the matrix B.

            On exit, if info <= N, the part of B containing the matrix is
            overwritten by the triangular factor U or L from the Cholesky
            factorization B = U'*U or B = L*L'.

    W:      If info = 0, the eigenvalues in ascending order.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value
            > 0:  potrf or syev returned an error code:
               <= N:  if info = i, syev failed to converge;
                      i off-diagonal elements of an intermediate
                      tridiagonal form did not converge to zero;
               > N:   if info = N + i, for 1 <= i <= N, then the leading
                      minor of order i of B is not positive definite.
                      The factorization of B could not be completed and
                      no eigenvalues or eigenvectors were computed.

=for example

 # Assume $a is symmetric ;)
 $a = random (5,5);
 # Assume $a is symmetric and positive definite ;)
 $b = random (5,5);
 sygv($a, 1,1, 0, $b, (my $w = zeroes(5)), (my $info=null));

=for bad

sygv ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*sygv = \&PDL::sygv;






=head2 sygvd

=for sig

  Signature: ([io]A(n,n);int itype();int jobz(); int uplo();[io]B(n,n);[o]w(n); int [o]info())

=for ref

Computes all the eigenvalues, and optionally, the eigenvectors
of a real generalized symmetric-definite eigenproblem, of the form
A*x=(lambda)*B*x,  A*Bx=(lambda)*x,  or B*A*x=(lambda)*x.
Here A and B are assumed to be symmetric and B is also
positive definite.

The divide and conquer algorithm makes very mild assumptions about
floating point arithmetic. It will work on machines with a guard
digit in add/subtract, or on those binary machines without guard
digits which subtract like the Cray X-MP, Cray Y-MP, Cray C-90, or
Cray-2. It could conceivably fail on hexadecimal or decimal machines
without guard digits, but we know of none.

    Arguments
    =========

    itype:  Specifies the problem type to be solved:
            = 1:  A*x = (lambda)*B*x
            = 2:  A*B*x = (lambda)*x
            = 3:  B*A*x = (lambda)*x

    jobz:   = 0:  Compute eigenvalues only;
            = 1:  Compute eigenvalues and eigenvectors.

    uplo:   = 0:  Upper triangles of A and B are stored;
            = 1:  Lower triangles of A and B are stored.

    A:      On entry, the symmetric matrix A.  If uplo = 0, the
            leading N-by-N upper triangular part of A contains the
            upper triangular part of the matrix A.  If uplo = 1,
            the leading N-by-N lower triangular part of A contains
            the lower triangular part of the matrix A.

            On exit, if jobz = 1, then if info = 0, A contains the
            matrix Z of eigenvectors.  The eigenvectors are normalized
            as follows:
            if itype = 1 or 2, Z'*B*Z = I;
            if itype = 3, Z'*inv(B)*Z = I.
            If jobz = 0, then on exit the upper triangle (if uplo=0)
            or the lower triangle (if uplo=1) of A, including the
            diagonal, is destroyed.

    B:      On entry, the symmetric positive definite matrix B.
            If uplo = 0, the leading N-by-N upper triangular part of B
            contains the upper triangular part of the matrix B.
            If uplo = 1, the leading N-by-N lower triangular part of B
            contains the lower triangular part of the matrix B.

            On exit, if info <= N, the part of B containing the matrix is
            overwritten by the triangular factor U or L from the Cholesky
            factorization B = U'*U or B = L*L'.

    W:      If info = 0, the eigenvalues in ascending order.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value
            > 0:  potrf or syev returned an error code:
               <= N:  if info = i, syevd failed to converge;
                      i off-diagonal elements of an intermediate
                      tridiagonal form did not converge to zero;
               > N:   if info = N + i, for 1 <= i <= N, then the leading
                      minor of order i of B is not positive definite.
                      The factorization of B could not be completed and
                      no eigenvalues or eigenvectors were computed.

=for example

 # Assume $a is symmetric ;)
 $a = random (5,5);
 # Assume $b is symmetric positive definite ;)
 $b = random (5,5);
 sygvd($a, 1,1, 0, $b, (my $w = zeroes(5)), (my $info=null));

=for bad

sygvd ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*sygvd = \&PDL::sygvd;






=head2 sygvx

=for sig

  Signature: ([io]A(n,n); int itype(); int jobz(); int range();
	  int uplo(); [io]B(n,n); vl(); vu(); int il(); int iu(); abstol();
	  int [o]m(); [o]w(n); [o]Z(p,p); int [o]ifail(n); int [o]info();
	  int [t]iwork(iworkn=CALC(5*$SIZE(n)));
	)

=for ref

Computes selected eigenvalues, and optionally, eigenvectors
of a real generalized symmetric-definite eigenproblem, of the form
A*x=(lambda)*B*x,  A*Bx=(lambda)*x,  or B*A*x=(lambda)*x.  Here A
and B are assumed to be symmetric and B is also positive definite.
Eigenvalues and eigenvectors can be selected by specifying either a
range of values or a range of indices for the desired eigenvalues.

    Arguments
    =========

    itype:  Specifies the problem type to be solved:
            = 1:  A*x = (lambda)*B*x
            = 2:  A*B*x = (lambda)*x
            = 3:  B*A*x = (lambda)*x

    jobz:   = 0:  Compute eigenvalues only;
            = 1:  Compute eigenvalues and eigenvectors.

    range:  = 0: all eigenvalues will be found.
            = 1: all eigenvalues in the half-open interval (vl,vu]
                   will be found.
            = 2: the il-th through iu-th eigenvalues will be found.

    uplo:   = 0:  Upper triangle of A and B are stored;
            = 1:  Lower triangle of A and B are stored.

    A:      On entry, the symmetric matrix A.  If uplo = 0, the
            leading N-by-N upper triangular part of A contains the
            upper triangular part of the matrix A.  If uplo = 1,
            the leading N-by-N lower triangular part of A contains
            the lower triangular part of the matrix A.

            On exit, the lower triangle (if uplo=1) or the upper
            triangle (if uplo=0) of A, including the diagonal, is
            destroyed.

    B:      On entry, the symmetric matrix B.  If uplo = 0, the
            leading N-by-N upper triangular part of B contains the
            upper triangular part of the matrix B.  If uplo = 1,
            the leading N-by-N lower triangular part of B contains
            the lower triangular part of the matrix B.

            On exit, if info <= N, the part of B containing the matrix is
            overwritten by the triangular factor U or L from the Cholesky
            factorization B = U'*U or B = L*L'.

    vl:
    vu:     If range=1, the lower and upper bounds of the interval to
            be searched for eigenvalues. vl < vu.
            Not referenced if range = 0 or 2.

    il:
    iu:     If range=2, the indices (in ascending order) of the
            smallest and largest eigenvalues to be returned.
            1 <= il <= iu <= N, if N > 0; il = 1 and iu = 0 if N = 0.
            Not referenced if range = 0 or 1.

    abstol: The absolute error tolerance for the eigenvalues.
            An approximate eigenvalue is accepted as converged
            when it is determined to lie in an interval [a,b]
            of width less than or equal to

                    abstol + EPS *   max( |a|,|b| ) ,

            where EPS is the machine precision.  If abstol is less than
            or equal to zero, then  EPS*|T|  will be used in its place,
            where |T| is the 1-norm of the tridiagonal matrix obtained
            by reducing A to tridiagonal form.

            Eigenvalues will be computed most accurately when abstol is
            set to twice the underflow threshold 2*lamch(1), not zero.
            If this routine returns with info>0, indicating that some
            eigenvectors did not converge, try setting abstol to
            2* lamch(1).

    m:      The total number of eigenvalues found.  0 <= m <= N.
            If range = 0, m = N, and if range = 2, m = iu-il+1.

    w:      On normal exit, the first m elements contain the selected
            eigenvalues in ascending order.

    Z:      If jobz = 0, then Z is not referenced.
            If jobz = 1, then if info = 0, the first m columns of Z
            contain the orthonormal eigenvectors of the matrix A
            corresponding to the selected eigenvalues, with the i-th
            column of Z holding the eigenvector associated with w(i).
            The eigenvectors are normalized as follows:
            if itype = 1 or 2, Z'*B*Z = I;
            if itype = 3, Z'*inv(B)*Z = I.

            If an eigenvector fails to converge, then that column of Z
            contains the latest approximation to the eigenvector, and the
            index of the eigenvector is returned in ifail.
            Note: the user must ensure that at least max(1,m) columns are
            supplied in the array Z; if range = 1, the exact value of m
            is not known in advance and an upper bound must be used.

    ifail:  If jobz = 1, then if info = 0, the first M elements of
            ifail are zero.  If info > 0, then ifail contains the
            indices of the eigenvectors that failed to converge.
            If jobz = 0, then ifail is not referenced.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value
            > 0:  potrf or syevx returned an error code:
               <= N:  if info = i, syevx failed to converge;
                      i eigenvectors failed to converge.  Their indices
                      are stored in array ifail.
               > N:   if info = N + i, for 1 <= i <= N, then the leading
                      minor of order i of B is not positive definite.
                      The factorization of B could not be completed and
                      no eigenvalues or eigenvectors were computed.

=for example

 # Assume $a is symmetric ;)
 $a = random (5,5);
 # Assume $b is symmetric positive definite ;)
 $b = random (5,5);
 $unfl = lamch(1);
 $ovfl = lamch(9);
 labad($unfl, $ovfl);
 $abstol = $unfl + $unfl;
 $m = null;
 $w=zeroes(5);
 $z = zeroes(5,5);
 $ifail = zeroes(5);
 sygvx($a, 1,1, 0,0, $b, 0, 0, 0, 0, $abstol, $m, $w, $z,$ifail,(my $info=null));

=for bad

sygvx ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*sygvx = \&PDL::sygvx;






=head2 gesv

=for sig

  Signature: ([io]A(n,n);  [io]B(n,m); int [o]ipiv(n); int [o]info())

=for ref

Computes the solution to a real system of linear equations

	A * X = B,
	where A is an N-by-N matrix and X and B are N-by-NRHS matrices.

The LU decomposition with partial pivoting and row interchanges is
used to factor A as

	A = P * L * U,
	where P is a permutation matrix, L is unit lower triangular, and U is
	upper triangular.

The factored form of A is then used to solve the
system of equations A * X = B.

    Arguments
    =========

    A:      On entry, the N-by-N coefficient matrix A.
            On exit, the factors L and U from the factorization
            A = P*L*U; the unit diagonal elements of L are not stored.

    ipiv:   The pivot indices that define the permutation matrix P;
            row i of the matrix was interchanged with row ipiv(i).

    B:      On entry, the N-by-NRHS matrix of right hand side matrix B.
            On exit, if info = 0, the N-by-NRHS solution matrix X.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value
            > 0:  if info = i, U(i,i) is exactly zero.  The factorization
                  has been completed, but the factor U is exactly
                  singular, so the solution could not be computed.

=for example

 $a = random (5,5);
 $a = transpose($a);
 $b = random (5,5);
 $b = transpose($b);
 gesv($a,$b, (my $ipiv=zeroes(5)),(my $info=null));
 print "The solution matrix X is :". transpose($b)."\n" unless $info;

=for bad

gesv ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*gesv = \&PDL::gesv;






=head2 gesvx

=for sig

  Signature: ([io]A(n,n); int trans(); int fact(); [io]B(n,m); [io]af(n,n); int [io]ipiv(n); int [io]equed(); [o]r(p); [o]c(q); [o]X(n,m); [o]rcond(); [o]ferr(m); [o]berr(m);[o]rpvgrw();int [o]info(); [t]work(workn=CALC(4*$SIZE(n))); int [t]iwork(n))

=for ref

Uses the LU factorization to compute the solution to a real
system of linear equations

	A * X = B,
	where A is an N-by-N matrix and X and B are N-by-NRHS matrices.

Error bounds on the solution and a condition estimate are also
provided.

=for desc

The following steps are performed:

=over  3

=item  1

If fact = 2, real scaling factors are computed to equilibrate
the system:

	trans = 0:  diag(r)*A*diag(c)     *inv(diag(c))*X = diag(c)*B
	trans = 1: (diag(r)*A*diag(c))' *inv(diag(r))*X = diag(c)*B
	trans = 2: (diag(r)*A*diag(c))**H *inv(diag(r))*X = diag(c)*B

Whether or not the system will be equilibrated depends on the
scaling of the matrix A, but if equilibration is used, A is
overwritten by diag(r)*A*diag(c) and B by diag(r)*B (if trans=0)
or diag(c)*B (if trans = 1 or 2).

=item 2

If fact = 1 or 2, the LU decomposition is used to factor the
matrix A (after equilibration if fact = 2) as

	A = P * L * U,
	where P is a permutation matrix, L is a unit lower triangular
	matrix, and U is upper triangular.

=item 3

If some U(i,i)=0, so that U is exactly singular, then the routine
returns with info = i. Otherwise, the factored form of A is used
to estimate the condition number of the matrix A.  If the
reciprocal of the condition number is less than machine precision,
info = N+1 is returned as a warning, but the routine still goes on
to solve for X and compute error bounds as described below.

=item 4

The system of equations is solved for X using the factored form
of A.

=item 5

Iterative refinement is applied to improve the computed solution
matrix and calculate error bounds and backward error estimates
for it.

=item 6

If equilibration was used, the matrix X is premultiplied by
diag(c) (if trans = 0) or diag(r) (if trans = 1 or 2) so
that it solves the original system before equilibration.

=back

    Arguments
    =========

    fact:   Specifies whether or not the factored form of the matrix A is
            supplied on entry, and if not, whether the matrix A should be
            equilibrated before it is factored.
            = 0:  On entry, af and ipiv contain the factored form of A.
                    If equed is not 0, the matrix A has been
                    equilibrated with scaling factors given by r and c.
                    A, af, and ipiv are not modified.
            = 1:  The matrix A will be copied to af and factored.
            = 2:  The matrix A will be equilibrated if necessary, then
                    copied to af and factored.

    trans:  Specifies the form of the system of equations:
            = 0:  A * X = B     (No transpose)
            = 1:  A' * X = B  (Transpose)
            = 2:  A**H * X = B  (Transpose)

    A:      On entry, the N-by-N matrix A.  If fact = 0 and equed is
            not 0, then A must have been equilibrated by the scaling
            factors in r and/or c.  A is not modified if fact = 0 or
            1, or if fact = 2 and equed = 0 on exit.

            On exit, if equed != 0, A is scaled as follows:
            equed = 1:  A := diag(r) * A
            equed = 2:  A := A * diag(c)
            equed = 3:  A := diag(r) * A * diag(c).

    af:     If fact = 0, then af is an input argument and on entry
            contains the factors L and U from the factorization
            A = P*L*U as computed by getrf.  If equed != 0, then
            af is the factored form of the equilibrated matrix A.

            If fact = 1, then af is an output argument and on exit
            returns the factors L and U from the factorization A = P*L*U
            of the original matrix A.

            If fact = 2, then af is an output argument and on exit
            returns the factors L and U from the factorization A = P*L*U
            of the equilibrated matrix A (see the description of A for
            the form of the equilibrated matrix).

    ipiv:   If fact = 0, then ipiv is an input argument and on entry
            contains the pivot indices from the factorization A = P*L*U
            as computed by getrf; row i of the matrix was interchanged
            with row ipiv(i).

            If fact = 1, then ipiv is an output argument and on exit
            contains the pivot indices from the factorization A = P*L*U
            of the original matrix A.

            If fact = 2, then ipiv is an output argument and on exit
            contains the pivot indices from the factorization A = P*L*U
            of the equilibrated matrix A.

    equed:  Specifies the form of equilibration that was done.
            = 0:  No equilibration (always true if fact = 1).
            = 1:  Row equilibration, i.e., A has been premultiplied by
                    diag(r).
            = 2:  Column equilibration, i.e., A has been postmultiplied
                    by diag(c).
            = 3:  Both row and column equilibration, i.e., A has been
                    replaced by diag(r) * A * diag(c).
            equed is an input argument if fact = 0; otherwise, it is an
            output argument.

    r:      The row scale factors for A.  If equed = 1 or 3, A is
            multiplied on the left by diag(r); if equed = 0 or 2, r
            is not accessed.  r is an input argument if fact = 0;
            otherwise, r is an output argument.  If fact = 0 and
            equed = 1 or 3, each element of r must be positive.

    c:      The column scale factors for A.  If equed = 2 or 3, A is
            multiplied on the right by diag(c); if equed = 0 or 1, c
            is not accessed.  c is an input argument if fact = 0;
            otherwise, c is an output argument.  If fact = 0 and
            equed = 2 or 3, each element of c must be positive.

    B:      On entry, the N-by-NRHS right hand side matrix B.
            On exit,
            if equed = 0, B is not modified;
            if trans = 0 and equed = 1 or 3, B is overwritten by
            diag(r)*B;
            if trans = 1 or 2 and equed = 2 or 3, B is
            overwritten by diag(c)*B.

    X:      If info = 0 or info = N+1, the N-by-NRHS solution matrix X
            to the original system of equations.  Note that A and B are
            modified on exit if equed != 0, and the solution to the
            equilibrated system is inv(diag(c))*X if trans = 0 and
            equed = 2 or 3, or inv(diag(r))*X if trans = 1 or 2
            and equed = 1 or 3.

    rcond:  The estimate of the reciprocal condition number of the matrix
            A after equilibration (if done).  If rcond is less than the
            machine precision (in particular, if rcond = 0), the matrix
            is singular to working precision.  This condition is
            indicated by a return code of info > 0.

    ferr:   The estimated forward error bound for each solution vector
            X(j) (the j-th column of the solution matrix X).
            If XTRUE is the true solution corresponding to X(j), ferr(j)
            is an estimated upper bound for the magnitude of the largest
            element in (X(j) - XTRUE) divided by the magnitude of the
            largest element in X(j).  The estimate is as reliable as
            the estimate for rcond, and is almost always a slight
            overestimate of the true error.

    berr:   The componentwise relative backward error of each solution
            vector X(j) (i.e., the smallest relative change in
            any element of A or B that makes X(j) an exact solution).

    rpvgrw: Contains the reciprocal pivot growth factor norm(A)/norm(U).
	    The "max absolute element" norm is used. If it is much less
	    than 1, then the stability of the LU factorization of the
	    (equilibrated) matrix A could be poor. This also means that
	    the solution X, condition estimator rcond, and forward error
	    bound ferr could be unreliable. If factorization fails with
	    0<info<=N, then it contains the reciprocal pivot growth factor
	    for the leading info columns of A.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value
            > 0:  if info = i, and i is
                  <= N:  U(i,i) is exactly zero.  The factorization has
                         been completed, but the factor U is exactly
                         singular, so the solution and error bounds
                         could not be computed. rcond = 0 is returned.
                  = N+1: U is nonsingular, but rcond is less than machine
                         precision, meaning that the matrix is singular
                         to working precision.  Nevertheless, the
                         solution and error bounds are computed because
                         there are a number of situations where the
                         computed solution can be more accurate than the
                         value of rcond would suggest.

=for example

 $a= random(5,5);
 $b = random(5,5);
 $a = transpose($a);
 $b = transpose($b);
 $rcond = pdl(0);
 $rpvgrw = pdl(0);
 $equed = pdl(long,0);
 $info = pdl(long,0);
 $berr = zeroes(5);
 $ipiv = zeroes(5);
 $ferr = zeroes(5);
 $r = zeroes(5);
 $c = zeroes(5);
 $X = zeroes(5,5);
 $af = zeroes(5,5);
 gesvx($a,0, 2, $b, $af, $ipiv, $equed, $r, $c, $X, $rcond, $ferr, $berr, $rpvgrw, $info);
 print "The solution matrix X is :". transpose($X)."\n" unless $info;

=for bad

gesvx ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*gesvx = \&PDL::gesvx;






=head2 sysv

=for sig

  Signature: ([io]A(n,n);  int uplo(); [io]B(n,m); int [o]ipiv(n); int [o]info())

=for ref

Computes the solution to a real system of linear equations

	A * X = B,
	where A is an N-by-N symmetric matrix and X and B are N-by-NRHS
	matrices.

The diagonal pivoting method is used to factor A as

	A = U * D * U',  if uplo = 0, or
	A = L * D * L',  if uplo = 1,
	where U (or L) is a product of permutation and unit upper (lower)
	triangular matrices, and D is symmetric and block diagonal with
	1-by-1 and 2-by-2 diagonal blocks.

The factored form of A is then
used to solve the system of equations A * X = B.

    Arguments
    =========

    uplo:   = 0:  Upper triangle of A is stored;
            = 1:  Lower triangle of A is stored.

    A:      On entry, the symmetric matrix A.  If uplo = 0, the leading
            N-by-N upper triangular part of A contains the upper
            triangular part of the matrix A, and the strictly lower
            triangular part of A is not referenced.  If uplo = 1, the
            leading N-by-N lower triangular part of A contains the lower
            triangular part of the matrix A, and the strictly upper
            triangular part of A is not referenced.

            On exit, if info = 0, the block diagonal matrix D and the
            multipliers used to obtain the factor U or L from the
            factorization A = U*D*U' or A = L*D*L' as computed by
            sytrf.

    ipiv:   Details of the interchanges and the block structure of D, as
            determined by sytrf.  If ipiv(k) > 0, then rows and columns
            k and ipiv(k) were interchanged, and D(k,k) is a 1-by-1
            diagonal block.  If uplo = 0 and ipiv(k) = ipiv(k-1) < 0,
            then rows and columns k-1 and -ipiv(k) were interchanged and
            D(k-1:k,k-1:k) is a 2-by-2 diagonal block.  If uplo = 1 and
            ipiv(k) = ipiv(k+1) < 0, then rows and columns k+1 and
            -ipiv(k) were interchanged and D(k:k+1,k:k+1) is a 2-by-2
            diagonal block.

    B:      On entry, the N-by-NRHS right hand side matrix B.
            On exit, if info = 0, the N-by-NRHS solution matrix X.

    info:   = 0: successful exit
            < 0: if info = -i, the i-th argument had an illegal value
            > 0: if info = i, D(i,i) is exactly zero.  The factorization
                 has been completed, but the block diagonal matrix D is
                 exactly singular, so the solution could not be computed.

=for example

 # Assume $a is symmetric ;)
 $a = random (5,5);
 $a = transpose($a);
 $b = random(4,5);
 $b = transpose($b);
 sysv($a, 1, $b, (my $ipiv=zeroes(5)),(my $info=null));
 print "The solution matrix X is :". transpose($b)."\n" unless $info;

=for bad

sysv ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*sysv = \&PDL::sysv;






=head2 sysvx

=for sig

  Signature: (A(n,n); int uplo(); int fact(); B(n,m); [io]af(n,n); int [io]ipiv(n); [o]X(n,m); [o]rcond(); [o]ferr(m); [o]berr(m); int [o]info(); int [t]iwork(n))

=for ref

Uses the diagonal pivoting factorization to compute the
solution to a real system of linear equations A * X = B,
where A is an N-by-N symmetric matrix and X and B are N-by-NRHS
matrices.

Error bounds on the solution and a condition estimate are also
provided.

The following steps are performed:

=over 3

=item 1

If fact = 0, the diagonal pivoting method is used to factor A.
The form of the factorization is

	A = U * D * U',  if uplo = 0, or
	A = L * D * L',  if uplo = 1,
	where U (or L) is a product of permutation and unit upper (lower)
	triangular matrices, and D is symmetric and block diagonal with
	1-by-1 and 2-by-2 diagonal blocks.

=item 2

If some D(i,i)=0, so that D is exactly singular, then the routine
returns with info = i. Otherwise, the factored form of A is used
       to estimate the condition number of the matrix A.  If the
       reciprocal of the condition number is less than machine precision,
       info = N+1 is returned as a warning, but the routine still goes on
       to solve for X and compute error bounds as described below.

=item 3

The system of equations is solved for X using the factored form
of A.

=item 4

Iterative refinement is applied to improve the computed solution
matrix and calculate error bounds and backward error estimates
for it.

=back

    Arguments
    =========

    fact:   Specifies whether or not the factored form of A has been
            supplied on entry.
            = 0:  The matrix A will be copied to af and factored.
            = 1:  On entry, af and ipiv contain the factored form of
                    A.  af and ipiv will not be modified.

    uplo:   = 0:  Upper triangle of A is stored;
            = 1:  Lower triangle of A is stored.

    A:      The symmetric matrix A.  If uplo = 0, the leading N-by-N
            upper triangular part of A contains the upper triangular part
            of the matrix A, and the strictly lower triangular part of A
            is not referenced.  If uplo = 1, the leading N-by-N lower
            triangular part of A contains the lower triangular part of
            the matrix A, and the strictly upper triangular part of A is
            not referenced.

    af:     If fact = 1, then af is an input argument and on entry
            contains the block diagonal matrix D and the multipliers used
            to obtain the factor U or L from the factorization
            A = U*D*U' or A = L*D*L' as computed by sytrf.

            If fact = 0, then af is an output argument and on exit
            returns the block diagonal matrix D and the multipliers used
            to obtain the factor U or L from the factorization
            A = U*D*U' or A = L*D*L'.

    ipiv:   If fact = 1, then ipiv is an input argument and on entry
            contains details of the interchanges and the block structure
            of D, as determined by sytrf.
            If ipiv(k) > 0, then rows and columns k and ipiv(k) were
            interchanged and D(k,k) is a 1-by-1 diagonal block.
            If uplo = 0 and ipiv(k) = ipiv(k-1) < 0, then rows and
            columns k-1 and -ipiv(k) were interchanged and D(k-1:k,k-1:k)
            is a 2-by-2 diagonal block.  If uplo = 1 and ipiv(k) =
            ipiv(k+1) < 0, then rows and columns k+1 and -ipiv(k) were
            interchanged and D(k:k+1,k:k+1) is a 2-by-2 diagonal block.

            If fact = 0, then ipiv is an output argument and on exit
            contains details of the interchanges and the block structure
            of D, as determined by sytrf.

    B:      The N-by-NRHS right hand side matrix B.

    X:      If info = 0 or info = N+1, the N-by-NRHS solution matrix X.

    rcond:  The estimate of the reciprocal condition number of the matrix
            A.  If rcond is less than the machine precision (in
            particular, if rcond = 0), the matrix is singular to working
            precision.  This condition is indicated by a return code of
            info > 0.

    ferr:   The estimated forward error bound for each solution vector
            X(j) (the j-th column of the solution matrix X).
            If XTRUE is the true solution corresponding to X(j), ferr(j)
            is an estimated upper bound for the magnitude of the largest
            element in (X(j) - XTRUE) divided by the magnitude of the
            largest element in X(j).  The estimate is as reliable as
            the estimate for rcond, and is almost always a slight
            overestimate of the true error.

    berr:   The componentwise relative backward error of each solution
            vector X(j) (i.e., the smallest relative change in
            any element of A or B that makes X(j) an exact solution).

    info:   = 0: successful exit
            < 0: if info = -i, the i-th argument had an illegal value
            > 0: if info = i, and i is
                  <= N:  D(i,i) is exactly zero.  The factorization
                         has been completed but the factor D is exactly
                         singular, so the solution and error bounds could
                         not be computed. rcond = 0 is returned.
                  = N+1: D is nonsingular, but rcond is less than machine
                         precision, meaning that the matrix is singular
                         to working precision.  Nevertheless, the
                         solution and error bounds are computed because
                         there are a number of situations where the
                         computed solution can be more accurate than the
                         value of rcond would suggest.

=for example

 $a= random(5,5);
 $b = random(10,5);
 $a = transpose($a);
 $b = transpose($b);
 $X = zeroes($b);
 $af = zeroes($a);
 $ipiv = zeroes(long, 5);
 $rcond = pdl(0);
 $ferr = zeroes(10);
 $berr = zeroes(10);
 $info = pdl(long, 0);
 # Assume $a is  symmetric
 sysvx($a, 0, 0, $b,$af, $ipiv, $X, $rcond, $ferr, $berr,$info);
 print "The solution matrix X is :". transpose($X)."\n";

=for bad

sysvx ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*sysvx = \&PDL::sysvx;






=head2 posv

=for sig

  Signature: ([io]A(n,n);  int uplo(); [io]B(n,m); int [o]info())

=for ref

Computes the solution to a real system of linear equations

	A * X = B,
	where A is an N-by-N symmetric positive definite matrix and X and B
	are N-by-NRHS matrices.

The Cholesky decomposition is used to factor A as

	A = U'* U,  if uplo = 0, or
	A = L * L',  if uplo = 1,
	where U is an upper triangular matrix and L is a lower triangular
	matrix.

The factored form of A is then used to solve the system of
equations A * X = B.

    Arguments
    =========

    uplo:   = 0:  Upper triangle of A is stored;
            = 1:  Lower triangle of A is stored.

    A:      On entry, the symmetric matrix A.  If uplo = 0, the leading
            N-by-N upper triangular part of A contains the upper
            triangular part of the matrix A, and the strictly lower
            triangular part of A is not referenced.  If uplo = 1, the
            leading N-by-N lower triangular part of A contains the lower
            triangular part of the matrix A, and the strictly upper
            triangular part of A is not referenced.

            On exit, if info = 0, the factor U or L from the Cholesky
            factorization A = U'*U or A = L*L'.

    B:      On entry, the N-by-NRHS right hand side matrix B.
            On exit, if info = 0, the N-by-NRHS solution matrix X.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value
            > 0:  if info = i, the leading minor of order i of A is not
                  positive definite, so the factorization could not be
                  completed, and the solution has not been computed.

=for example

 # Assume $a is symmetric positive definite ;)
 $a = random (5,5);
 $a = transpose($a);
 $b = random(4,5);
 $b = transpose($b);
 posv($a, 1, $b, (my $info=null));
 print "The solution matrix X is :". transpose($b)."\n" unless $info;

=for bad

posv ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*posv = \&PDL::posv;






=head2 posvx

=for sig

  Signature: ([io]A(n,n); int uplo(); int fact(); [io]B(n,m); [io]af(n,n); int [io]equed(); [o]s(p); [o]X(n,m); [o]rcond(); [o]ferr(m); [o]berr(m); int [o]info(); int [t]iwork(n); [t]work(workn=CALC(3*$SIZE(n))))

=for ref

Uses the Cholesky factorization A = U'*U or A = L*L' to
compute the solution to a real system of linear equations

	A * X = B,
	where A is an N-by-N symmetric positive definite matrix and X and B
	are N-by-NRHS matrices.

Error bounds on the solution and a condition estimate are also
provided.

The following steps are performed:

=over 3

=item 1

If fact = 2, real scaling factors are computed to equilibrate
the system:

	diag(s) * A * diag(s) * inv(diag(s)) * X = diag(s) * B

Whether or not the system will be equilibrated depends on the
scaling of the matrix A, but if equilibration is used, A is
overwritten by diag(s)*A*diag(s) and B by diag(s)*B.

=item 2

If fact = 1 or 2, the Cholesky decomposition is used to
factor the matrix A (after equilibration if fact = 2) as

	A = U'* U,  if uplo = 0, or
	A = L * L',  if uplo = 1,
	where U is an upper triangular matrix and L is a lower triangular
	matrix.

=item 3

If the leading i-by-i principal minor is not positive definite,
then the routine returns with info = i. Otherwise, the factored
form of A is used to estimate the condition number of the matrix
A.  If the reciprocal of the condition number is less than machine
precision, info = N+1 is returned as a warning, but the routine
still goes on to solve for X and compute error bounds as
described below.

=item 4

The system of equations is solved for X using the factored form
of A.

=item 5

Iterative refinement is applied to improve the computed solution
matrix and calculate error bounds and backward error estimates
for it.

=item 6

If equilibration was used, the matrix X is premultiplied by
diag(s) so that it solves the original system before
equilibration.

=back

    Arguments
    =========

    fact:   Specifies whether or not the factored form of the matrix A is
            supplied on entry, and if not, whether the matrix A should be
            equilibrated before it is factored.
            = 0:  On entry, af contains the factored form of A.
                    If equed = 1, the matrix A has been equilibrated
                    with scaling factors given by s.  A and af will not
                    be modified.
            = 1:  The matrix A will be copied to af and factored.
            = 2:  The matrix A will be equilibrated if necessary, then
                    copied to af and factored.

    uplo:   = 0:  Upper triangle of A is stored;
            = 1:  Lower triangle of A is stored.

    A:      On entry, the symmetric matrix A, except if fact = 0 and
            equed = 1, then A must contain the equilibrated matrix
            diag(s)*A*diag(s).  If uplo = 0, the leading
            N-by-N upper triangular part of A contains the upper
            triangular part of the matrix A, and the strictly lower
            triangular part of A is not referenced.  If uplo = 1, the
            leading N-by-N lower triangular part of A contains the lower
            triangular part of the matrix A, and the strictly upper
            triangular part of A is not referenced.  A is not modified if
            fact = 0 or 1, or if fact = 2 and equed = 0 on exit.

            On exit, if fact = 2 and equed = 1, A is overwritten by
            diag(s)*A*diag(s).

    af:     If fact = 0, then af is an input argument and on entry
            contains the triangular factor U or L from the Cholesky
            factorization A = U'*U or A = L*L', in the same storage
            format as A.  If equed != 0, then af is the factored form
            of the equilibrated matrix diag(s)*A*diag(s).

            If fact = 1, then af is an output argument and on exit
            returns the triangular factor U or L from the Cholesky
            factorization A = U'*U or A = L*L' of the original
            matrix A.

            If fact = 2, then af is an output argument and on exit
            returns the triangular factor U or L from the Cholesky
            factorization A = U'*U or A = L*L' of the equilibrated
            matrix A (see the description of A for the form of the
            equilibrated matrix).

    equed:  Specifies the form of equilibration that was done.
            = 0:  No equilibration (always true if fact = 1).
            = 1:  Equilibration was done, i.e., A has been replaced by
                    diag(s) * A * diag(s).
            equed is an input argument if fact = 0; otherwise, it is an
            output argument.

    s:      The scale factors for A; not accessed if equed = 0.  s is
            an input argument if fact = 0; otherwise, s is an output
            argument.  If fact = 0 and equed = 1, each element of s
            must be positive.

    B:      On entry, the N-by-NRHS right hand side matrix B.
            On exit, if equed = 0, B is not modified; if equed = 1,
            B is overwritten by diag(s) * B.

    X:      If info = 0 or info = N+1, the N-by-NRHS solution matrix X to
            the original system of equations.  Note that if equed = 1,
            A and B are modified on exit, and the solution to the
            equilibrated system is inv(diag(s))*X.

    rcond:  The estimate of the reciprocal condition number of the matrix
            A after equilibration (if done).  If rcond is less than the
            machine precision (in particular, if rcond = 0), the matrix
            is singular to working precision.  This condition is
            indicated by a return code of info > 0.

    ferr:   The estimated forward error bound for each solution vector
            X(j) (the j-th column of the solution matrix X).
            If XTRUE is the true solution corresponding to X(j), FERR(j)
            is an estimated upper bound for the magnitude of the largest
            element in (X(j) - XTRUE) divided by the magnitude of the
            largest element in X(j).  The estimate is as reliable as
            the estimate for rcond, and is almost always a slight
            overestimate of the true error.

    berr:   The componentwise relative backward error of each solution
            vector X(j) (i.e., the smallest relative change in
            any element of A or B that makes X(j) an exact solution).

    info:   = 0: successful exit
            < 0: if info = -i, the i-th argument had an illegal value
            > 0: if info = i, and i is
                  <= N:  the leading minor of order i of A is
                         not positive definite, so the factorization
                         could not be completed, and the solution has not
                         been computed. rcond = 0 is returned.
                  = N+1: U is nonsingular, but rcond is less than machine
                         precision, meaning that the matrix is singular
                         to working precision.  Nevertheless, the
                         solution and error bounds are computed because
                         there are a number of situations where the
                         computed solution can be more accurate than the
                         value of rcond would suggest.

=for example

 $a= random(5,5);
 $b = random(5,5);
 $a = transpose($a);
 $b = transpose($b);
 # Assume $a is symmetric positive definite
 $rcond = pdl(0);
 $equed = pdl(long,0);
 $info = pdl(long,0);
 $berr = zeroes(5);
 $ferr = zeroes(5);
 $s = zeroes(5);
 $X = zeroes(5,5);
 $af = zeroes(5,5);
 posvx($a,0,2,$b,$af, $equed, $s, $X, $rcond, $ferr, $berr,$info);
 print "The solution matrix X is :". transpose($X)."\n" unless $info;

=for bad

posvx ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*posvx = \&PDL::posvx;






=head2 gels

=for sig

  Signature: ([io]A(m,n); int trans(); [io]B(p,q);int [o]info())

=for ref

Solves overdetermined or underdetermined real linear systems
involving an M-by-N matrix A, or its transpose, using a QR or LQ
factorization of A.  It is assumed that A has full rank.

The following options are provided:

=over 3

=item 1

If trans = 0 and m >= n:  find the least squares solution of
an overdetermined system, i.e., solve the least squares problem
minimize || B - A*X ||.

=item 2

If trans = 0 and m < n:  find the minimum norm solution of
an underdetermined system A * X = B.

=item 3

If trans = 1 and m >= n:  find the minimum norm solution of
an undetermined system A' * X = B.

=item 4

If trans = 1 and m < n:  find the least squares solution of
an overdetermined system, i.e., solve the least squares problem
minimize || B - A' * X ||.

=back

Several right hand side vectors b and solution vectors x can be
handled in a single call; they are stored as the columns of the
M-by-NRHS right hand side matrix B and the N-by-NRHS solution
matrix X.

    Arguments
    =========

    trans:  = 0: the linear system involves A;
            = 1: the linear system involves A'.

    A:      On entry, the M-by-N matrix A.
            On exit,
              if M >= N, A is overwritten by details of its QR
                         factorization as returned by geqrf;
              if M <  N, A is overwritten by details of its LQ
                         factorization as returned by gelqf.

    B:      On entry, the matrix B of right hand side vectors, stored
            columnwise; B is M-by-NRHS if trans = 0, or N-by-NRHS
            if trans = 1.
            On exit, B is overwritten by the solution vectors, stored
            columnwise:
            if trans = 0 and m >= n, rows 1 to n of B contain the least
            squares solution vectors; the residual sum of squares for the
            solution in each column is given by the sum of squares of
            elements N+1 to M in that column;
            if trans = 0 and m < n, rows 1 to N of B contain the
            minimum norm solution vectors;
            if trans = 1 and m >= n, rows 1 to M of B contain the
            minimum norm solution vectors;
            if trans = 1 and m < n, rows 1 to M of B contain the
            least squares solution vectors; the residual sum of squares
            for the solution in each column is given by the sum of
            squares of elements M+1 to N in that column.
            The leading dimension of the array B >= max(1,M,N).

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value

=for example

 $a= random(7,5);
 # $b will contain X
 # TODO better example with slice
 $b = random(7,6);
 gels($a, 1, $b, ($info = null));

=for bad

gels ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*gels = \&PDL::gels;






=head2 gelsy

=for sig

  Signature: ([io]A(m,n); [io]B(p,q); rcond(); int [io]jpvt(n); int [o]rank();int [o]info())

=for ref

Computes the minimum-norm solution to a real linear least
squares problem:

	minimize || A * X - B ||

using a complete orthogonal factorization of A.

A is an M-by-N matrix which may be rank-deficient.

Several right hand side vectors b and solution vectors x can be
handled in a single call; they are stored as the columns of the
M-by-NRHS right hand side matrix B and the N-by-NRHS solution
matrix X.

The routine first computes a QR factorization with column pivoting:

	A * P = Q * [ R11 R12 ]
		    [  0  R22 ]

	with R11 defined as the largest leading submatrix whose estimated
	condition number is less than 1/rcond.  The order of R11, rank,
	is the effective rank of A.

Then, R22 is considered to be negligible, and R12 is annihilated
by orthogonal transformations from the right, arriving at the
complete orthogonal factorization:

	A * P = Q * [ T11 0 ] * Z
		    [  0  0 ]

The minimum-norm solution is then

	X = P * Z' [ inv(T11)*Q1'*B ]
		   [	     0	    ]
	where Q1 consists of the first rank columns of Q.

    Arguments
    =========

    A:      On entry, the M-by-N matrix A.
            On exit, A has been overwritten by details of its
            complete orthogonal factorization.

    B:      On entry, the M-by-NRHS right hand side matrix B.
            On exit, the N-by-NRHS solution matrix X.
            The leading dimension of the array B >= max(1,M,N).

    jpvt:   On entry, if jpvt(i) != 0, the i-th column of A is permuted
            to the front of AP, otherwise column i is a free column.
            On exit, if jpvt(i) = k, then the i-th column of AP
            was the k-th column of A.

    rcond:  rcond is used to determine the effective rank of A, which
            is defined as the order of the largest leading triangular
            submatrix R11 in the QR factorization with pivoting of A,
            whose estimated condition number < 1/rcond.

    rank:   The effective rank of A, i.e., the order of the submatrix
            R11.  This is the same as the order of the submatrix T11
            in the complete orthogonal factorization of A.

    info:   = 0: successful exit
            < 0: If info = -i, the i-th argument had an illegal value.

=for example

 $a= random(7,5);
 # $b will contain X
 # TODO better example with slice
 $b = random(7,6);
 $jpvt = zeroes(long, 5);
 $eps = lamch(0);
 #Threshold for rank estimation
 $rcond = sqrt($eps) - (sqrt($eps) - $eps) / 2;
 gelsy($a, $b, $rcond, $jpvt,($rank=null),($info = null));

=for bad

gelsy ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*gelsy = \&PDL::gelsy;






=head2 gelss

=for sig

  Signature: ([io]A(m,n); [io]B(p,q); rcond(); [o]s(r); int [o]rank();int [o]info())

=for ref

Computes the minimum norm solution to a real linear least
squares problem:

	Minimize 2-norm(| b - A*x |).

using the singular value decomposition (SVD) of A. A is an M-by-N
matrix which may be rank-deficient.

Several right hand side vectors b and solution vectors x can be
handled in a single call; they are stored as the columns of the
M-by-NRHS right hand side matrix B and the N-by-NRHS solution matrix
X.

The effective rank of A is determined by treating as zero those
singular values which are less than rcond times the largest singular
value.

    Arguments
    =========

    A:      On entry, the M-by-N matrix A.
            On exit, the first min(m,n) rows of A are overwritten with
            its right singular vectors, stored rowwise.

    B:      On entry, the M-by-NRHS right hand side matrix B.
            On exit, B is overwritten by the N-by-NRHS solution
            matrix X.  If m >= n and rank = n, the residual
            sum-of-squares for the solution in the i-th column is given
            by the sum of squares of elements n+1:m in that column.
	    The leading dimension of the array B >= max(1,M,N).

    s:      The singular values of A in decreasing order.
            The condition number of A in the 2-norm = s(1)/s(min(m,n)).

    rcond:  rcond is used to determine the effective rank of A.
            Singular values s(i) <= rcond*s(1) are treated as zero.
            If rcond < 0, machine precision is used instead.

    rank:   The effective rank of A, i.e., the number of singular values
            which are greater than rcond*s(1).

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value.
            > 0:  the algorithm for computing the SVD failed to converge;
                  if info = i, i off-diagonal elements of an intermediate
                  bidiagonal form did not converge to zero.

=for example

 $a= random(7,5);
 # $b will contain X
 # TODO better example with slice
 $b = random(7,6);
 $eps = lamch(0);
 $s =zeroes(5);
 #Threshold for rank estimation
 $rcond = sqrt($eps) - (sqrt($eps) - $eps) / 2;
 gelss($a, $b, $rcond, $s, ($rank=null),($info = null));

=for bad

gelss ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*gelss = \&PDL::gelss;






=head2 gelsd

=for sig

  Signature: ([io]A(m,n); [io]B(p,q); rcond(); [o]s(minmn=CALC(PDLMAX(1,PDLMIN($SIZE(m),$SIZE(n))))); int [o]rank();int [o]info(); int [t]iwork(iworkn))

=for ref

Computes the minimum-norm solution to a real linear least
squares problem:

	minimize 2-norm(| b - A*x |)

using the singular value decomposition (SVD) of A. A is an M-by-N
matrix which may be rank-deficient.

Several right hand side vectors b and solution vectors x can be
handled in a single call; they are stored as the columns of the
M-by-NRHS right hand side matrix B and the N-by-NRHS solution
matrix X.

The problem is solved in three steps:

=over 3

=item 1

Reduce the coefficient matrix A to bidiagonal form with
Householder transformations, reducing the original problem
into a "bidiagonal least squares problem" (BLS)

=item 2

Solve the BLS using a divide and conquer approach.

=item 3

Apply back all the Householder transformations to solve
the original least squares problem.

=back

The effective rank of A is determined by treating as zero those
singular values which are less than rcond times the largest singular
value.

The divide and conquer algorithm makes very mild assumptions about
floating point arithmetic. It will work on machines with a guard
digit in add/subtract, or on those binary machines without guard
digits which subtract like the Cray X-MP, Cray Y-MP, Cray C-90, or
Cray-2. It could conceivably fail on hexadecimal or decimal machines
without guard digits, but we know of none.

    Arguments
    =========

    A:      On entry, the M-by-N matrix A.
            On exit, A has been destroyed.

    B:      On entry, the M-by-NRHS right hand side matrix B.
            On exit, B is overwritten by the N-by-NRHS solution
            matrix X.  If m >= n and rank = n, the residual
            sum-of-squares for the solution in the i-th column is given
            by the sum of squares of elements n+1:m in that column.
	    The leading dimension of the array B >= max(1,M,N).

    s:      The singular values of A in decreasing order.
            The condition number of A in the 2-norm = s(1)/s(min(m,n)).

    rcond:  rcond is used to determine the effective rank of A.
            Singular values s(i) <= rcond*s(1) are treated as zero.
            If rcond < 0, machine precision is used instead.

    rank:   The effective rank of A, i.e., the number of singular values
            which are greater than rcond*s(1).

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value.
            > 0:  the algorithm for computing the SVD failed to converge;
                  if info = i, i off-diagonal elements of an intermediate
                  bidiagonal form did not converge to zero.

=for example

 $a= random(7,5);
 # $b will contain X
 # TODO better example with slice
 $b = random(7,6);
 $eps = lamch(0);
 $s =zeroes(5);
 #Threshold for rank estimation
 $rcond = sqrt($eps) - (sqrt($eps) - $eps) / 2;
 gelsd($a, $b, $rcond, $s, ($rank=null),($info = null));

=for bad

gelsd ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*gelsd = \&PDL::gelsd;






=head2 gglse

=for sig

  Signature: ([io]A(m,n); [io]B(p,n);[io]c(m);[io]d(p);[o]x(n);int [o]info())

=for ref

Solves the linear equality-constrained least squares (LSE)
problem:

	minimize || c - A*x ||_2   subject to   B*x = d

	where A is an M-by-N matrix, B is a P-by-N matrix, c is a given
	M-vector, and d is a given P-vector. It is assumed that
	P <= N <= M+P, and

             rank(B) = P and  rank( ( A ) ) = N.
                                  ( ( B ) )

These conditions ensure that the LSE problem has a unique solution,
which is obtained using a GRQ factorization of the matrices B and A.

    Arguments
    =========

    A:      On entry, the M-by-N matrix A.
            On exit, A is destroyed.

    B:      On entry, the P-by-N matrix B.
            On exit, B is destroyed.

    c:      On entry, c contains the right hand side vector for the
            least squares part of the LSE problem.
            On exit, the residual sum of squares for the solution
            is given by the sum of squares of elements N-P+1 to M of
            vector c.

    d:      On entry, d contains the right hand side vector for the
            constrained equation.
            On exit, d is destroyed.

    x:      On exit, x is the solution of the LSE problem.

    info:   = 0:  successful exit.
            < 0:  if info = -i, the i-th argument had an illegal value.

=for example

 $a = random(7,5);
 $b = random(4,5);
 $c = random(7);
 $d = random(4);
 $x = zeroes(5);
 gglse($a, $b, $c, $d, $x, ($info=null));

=for bad

gglse ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*gglse = \&PDL::gglse;






=head2 ggglm

=for sig

  Signature: ([io]A(n,m); [io]B(n,p);[io]d(n);[o]x(m);[o]y(p);int [o]info())

=for ref

Solves a general Gauss-Markov linear model (GLM) problem:

	minimize || y ||_2   subject to   d = A*x + B*y
	   x

	where A is an N-by-M matrix, B is an N-by-P matrix, and d is a
	given N-vector. It is assumed that M <= N <= M+P, and

               rank(A) = M    and    rank( A B ) = N.

Under these assumptions, the constrained equation is always
consistent, and there is a unique solution x and a minimal 2-norm
solution y, which is obtained using a generalized QR factorization
of A and B.

In particular, if matrix B is square nonsingular, then the problem
GLM is equivalent to the following weighted linear least squares
problem

	minimize || inv(B)*(d-A*x) ||_2
	   x

	where inv(B) denotes the inverse of B.

    Arguments
    =========

    A:      On entry, the N-by-M matrix A.
            On exit, A is destroyed.

    B:      On entry, the N-by-P matrix B.
            On exit, B is destroyed.

    d:      On entry, d is the left hand side of the GLM equation.
            On exit, d is destroyed.

    x:
    y:      On exit, x and y are the solutions of the GLM problem.

    info:   = 0:  successful exit.
            < 0:  if info = -i, the i-th argument had an illegal value.

=for example

 $a = random(7,5);
 $b = random(7,4);
 $d = random(7);
 $x = zeroes(5);
 $y = zeroes(4);
 ggglm($a, $b, $d, $x, $y,($info=null));

=for bad

ggglm ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*ggglm = \&PDL::ggglm;






=head2 getrf

=for sig

  Signature: ([io]A(m,n); int [o]ipiv(p=CALC(PDLMIN($SIZE(m),$SIZE(n)))); int [o]info())

=for ref

Computes an LU factorization of a general M-by-N matrix A
using partial pivoting with row interchanges.

The factorization has the form

	A = P * L * U

	where P is a permutation matrix, L is lower triangular with unit
	diagonal elements (lower trapezoidal if m > n), and U is upper
	triangular (upper trapezoidal if m < n).

This is the right-looking Level 3 BLAS version of the algorithm.

    Arguments
    =========

    A:      On entry, the M-by-N matrix to be factored.
            On exit, the factors L and U from the factorization
            A = P*L*U; the unit diagonal elements of L are not stored.

    ipiv:  The pivot indices; for 1 <= i <= min(M,N), row i of the
            matrix was interchanged with row ipiv(i).

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value
            > 0:  if info = i, U(i,i) is exactly zero. The factorization
                  has been completed, but the factor U is exactly
                  singular, and division by zero will occur if it is used
                  to solve a system of equations.

=for example

 $a = random (float, 100,50);
 $ipiv = zeroes(long, 50);
 $info = null;
 getrf($a, $ipiv, $info);

=for bad

getrf ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*getrf = \&PDL::getrf;






=head2 getf2

=for sig

  Signature: ([io]A(m,n); int [o]ipiv(p=CALC(PDLMIN($SIZE(m),$SIZE(n)))); int [o]info())

=for ref

Computes an LU factorization of a general M-by-N matrix A
using partial pivoting with row interchanges.

The factorization has the form

	A = P * L * U

	where P is a permutation matrix, L is lower triangular with unit
	diagonal elements (lower trapezoidal if m > n), and U is upper
	triangular (upper trapezoidal if m < n).

This is the right-looking Level 2 BLAS version of the algorithm.

    Arguments
    =========

    A:      On entry, the M-by-N matrix to be factored.
            On exit, the factors L and U from the factorization
            A = P*L*U; the unit diagonal elements of L are not stored.

    ipiv:  The pivot indices; for 1 <= i <= min(M,N), row i of the
            matrix was interchanged with row ipiv(i).

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value
            > 0:  if info = i, U(i,i) is exactly zero. The factorization
                  has been completed, but the factor U is exactly
                  singular, and division by zero will occur if it is used
                  to solve a system of equations.

=for example

 $a = random (float, 100,50);
 $ipiv = zeroes(long, 50);
 $info = null;
 getf2($a, $ipiv, $info);

=for bad

getf2 ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*getf2 = \&PDL::getf2;






=head2 sytrf

=for sig

  Signature: ([io]A(n,n); int uplo(); int [o]ipiv(n); int [o]info())

=for ref

Computes the factorization of a real symmetric matrix A using
the Bunch-Kaufman diagonal pivoting method.  The form of the
factorization is

	A = U*D*U'  or  A = L*D*L'
	where U (or L) is a product of permutation and unit upper (lower)
	triangular matrices, and D is symmetric and block diagonal with
	1-by-1 and 2-by-2 diagonal blocks.

This is the blocked version of the algorithm, calling Level 3 BLAS.

    Arguments
    =========

    uplo:   = 0:  Upper triangle of A is stored;
            = 1:  Lower triangle of A is stored.

    A:      On entry, the symmetric matrix A.  If uplo = 0, the leading
            N-by-N upper triangular part of A contains the upper
            triangular part of the matrix A, and the strictly lower
            triangular part of A is not referenced.  If uplo = 1, the
            leading N-by-N lower triangular part of A contains the lower
            triangular part of the matrix A, and the strictly upper
            triangular part of A is not referenced.

            On exit, the block diagonal matrix D and the multipliers used
            to obtain the factor U or L (see below for further details).

    ipiv:   Details of the interchanges and the block structure of D.
            If ipiv(k) > 0, then rows and columns k and ipiv(k) were
            interchanged and D(k,k) is a 1-by-1 diagonal block.
            If uplo = 0 and ipiv(k) = ipiv(k-1) < 0, then rows and
            columns k-1 and -ipiv(k) were interchanged and D(k-1:k,k-1:k)
            is a 2-by-2 diagonal block.  If uplo = 1 and ipiv(k) =
            ipiv(k+1) < 0, then rows and columns k+1 and -ipiv(k) were
            interchanged and D(k:k+1,k:k+1) is a 2-by-2 diagonal block.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value
            > 0:  if info = i, D(i,i) is exactly zero.  The factorization
                  has been completed, but the block diagonal matrix D is
                  exactly singular, and division by zero will occur if it
                  is used to solve a system of equations.

    Further Details
    ===============

    If uplo = 0, then A = U*D*U', where
       U = P(n)*U(n)* ... *P(k)U(k)* ...,
    i.e., U is a product of terms P(k)*U(k), where k decreases from n to
    1 in steps of 1 or 2, and D is a block diagonal matrix with 1-by-1
    and 2-by-2 diagonal blocks D(k).  P(k) is a permutation matrix as
    defined by ipiv(k), and U(k) is a unit upper triangular matrix, such
    that if the diagonal block D(k) is of order s (s = 1 or 2), then

               (   I    v    0   )   k-s
       U(k) =  (   0    I    0   )   s
               (   0    0    I   )   n-k
                  k-s   s   n-k

    If s = 1, D(k) overwrites A(k,k), and v overwrites A(1:k-1,k).
    If s = 2, the upper triangle of D(k) overwrites A(k-1,k-1), A(k-1,k),
    and A(k,k), and v overwrites A(1:k-2,k-1:k).

    If uplo = 1, then A = L*D*L', where
       L = P(1)*L(1)* ... *P(k)*L(k)* ...,
    i.e., L is a product of terms P(k)*L(k), where k increases from 1 to
    n in steps of 1 or 2, and D is a block diagonal matrix with 1-by-1
    and 2-by-2 diagonal blocks D(k).  P(k) is a permutation matrix as
    defined by ipiv(k), and L(k) is a unit lower triangular matrix, such
    that if the diagonal block D(k) is of order s (s = 1 or 2), then

               (   I    0     0   )  k-1
       L(k) =  (   0    I     0   )  s
               (   0    v     I   )  n-k-s+1
                  k-1   s  n-k-s+1

    If s = 1, D(k) overwrites A(k,k), and v overwrites A(k+1:n,k).
    If s = 2, the lower triangle of D(k) overwrites A(k,k), A(k+1,k),
    and A(k+1,k+1), and v overwrites A(k+2:n,k:k+1).

=for example

 $a = random(100,100);
 $ipiv = zeroes(100);
 $info = null;
 # Assume $a is symmetric
 sytrf($a, 0, $ipiv, $info);

=for bad

sytrf ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*sytrf = \&PDL::sytrf;






=head2 sytf2

=for sig

  Signature: ([io]A(n,n); int uplo(); int [o]ipiv(n); int [o]info())

=for ref

Computes the factorization of a real symmetric matrix A using
the Bunch-Kaufman diagonal pivoting method.  The form of the
factorization is

	A = U*D*U'  or  A = L*D*L'
	where U (or L) is a product of permutation and unit upper (lower)
	triangular matrices, and D is symmetric and block diagonal with
	1-by-1 and 2-by-2 diagonal blocks.

This is the unblocked version of the algorithm, calling Level 2 BLAS.

    Arguments
    =========

    uplo:   = 0:  Upper triangle of A is stored;
            = 1:  Lower triangle of A is stored.

    A:      On entry, the symmetric matrix A.  If uplo = 0, the leading
            N-by-N upper triangular part of A contains the upper
            triangular part of the matrix A, and the strictly lower
            triangular part of A is not referenced.  If uplo = 1, the
            leading N-by-N lower triangular part of A contains the lower
            triangular part of the matrix A, and the strictly upper
            triangular part of A is not referenced.

            On exit, the block diagonal matrix D and the multipliers used
            to obtain the factor U or L (see below for further details).

    ipiv:   Details of the interchanges and the block structure of D.
            If ipiv(k) > 0, then rows and columns k and ipiv(k) were
            interchanged and D(k,k) is a 1-by-1 diagonal block.
            If uplo = 0 and ipiv(k) = ipiv(k-1) < 0, then rows and
            columns k-1 and -ipiv(k) were interchanged and D(k-1:k,k-1:k)
            is a 2-by-2 diagonal block.  If uplo = 1 and ipiv(k) =
            ipiv(k+1) < 0, then rows and columns k+1 and -ipiv(k) were
            interchanged and D(k:k+1,k:k+1) is a 2-by-2 diagonal block.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value
            > 0:  if info = i, D(i,i) is exactly zero.  The factorization
                  has been completed, but the block diagonal matrix D is
                  exactly singular, and division by zero will occur if it
                  is used to solve a system of equations.

    For further details see sytrf

=for example

 $a = random(100,100);
 $ipiv = zeroes(100);
 $info = null;
 # Assume $a is symmetric
 sytf2($a, 0, $ipiv, $info);

=for bad

sytf2 ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*sytf2 = \&PDL::sytf2;






=head2 potrf

=for sig

  Signature: ([io]A(n,n); int uplo(); int [o]info())

=for ref

Computes the Cholesky factorization of a real symmetric
positive definite matrix A.

The factorization has the form

	A = U' * U,  if uplo = 0, or
	A = L  * L',  if uplo = 1,
	where U is an upper triangular matrix and L is lower triangular.

This is the block version of the algorithm, calling Level 3 BLAS.

    Arguments
    =========

    uplo:   = 0:  Upper triangle of A is stored;
            = 1:  Lower triangle of A is stored.

    A:      On entry, the symmetric matrix A.  If uplo = 0, the leading
            N-by-N upper triangular part of A contains the upper
            triangular part of the matrix A, and the strictly lower
            triangular part of A is not referenced.  If uplo = 1, the
            leading N-by-N lower triangular part of A contains the lower
            triangular part of the matrix A, and the strictly upper
            triangular part of A is not referenced.

            On exit, if info = 0, the factor U or L from the Cholesky
            factorization A = U'*U or A = L*L'.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value
            > 0:  if info = i, the leading minor of order i is not
                  positive definite, and the factorization could not be
                  completed.

=for example

 $a = random(100,100);
 # Assume $a is symmetric positive definite
 potrf($a, 0, ($info = null));

=for bad

potrf ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*potrf = \&PDL::potrf;






=head2 potf2

=for sig

  Signature: ([io]A(n,n); int uplo(); int [o]info())

=for ref

Computes the Cholesky factorization of a real symmetric
positive definite matrix A.

The factorization has the form

	A = U' * U,  if uplo = 0, or
	A = L  * L',  if uplo = 1,
	where U is an upper triangular matrix and L is lower triangular.

This is the unblocked version of the algorithm, calling Level 2 BLAS.

    Arguments
    =========

    uplo:   = 0:  Upper triangle of A is stored;
            = 1:  Lower triangle of A is stored.

    A:      On entry, the symmetric matrix A.  If uplo = 0, the leading
            N-by-N upper triangular part of A contains the upper
            triangular part of the matrix A, and the strictly lower
            triangular part of A is not referenced.  If uplo = 1, the
            leading N-by-N lower triangular part of A contains the lower
            triangular part of the matrix A, and the strictly upper
            triangular part of A is not referenced.

            On exit, if info = 0, the factor U or L from the Cholesky
            factorization A = U'*U or A = L*L'.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value
            > 0:  if info = i, the leading minor of order i is not
                  positive definite, and the factorization could not be
                  completed.

=for example

 $a = random(100,100);
 # Assume $a is symmetric positive definite
 potf2($a, 0, ($info = null));

=for bad

potf2 ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*potf2 = \&PDL::potf2;






=head2 getri

=for sig

  Signature: ([io]A(n,n); int ipiv(n); int [o]info())

=for ref

Computes the inverse of a matrix using the LU factorization
computed by C<getrf>.

This method inverts U and then computes inv(A) by solving the system

    inv(A)*L = inv(U) for inv(A).

    Arguments
    =========

    A:      On entry, the factors L and U from the factorization
            A = P*L*U as computed by getrf.
            On exit, if info = 0, the inverse of the original matrix A.

    ipiv:   The pivot indices from getrf; for 1<=i<=N, row i of the
            matrix was interchanged with row ipiv(i).

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value
            > 0:  if info = i, U(i,i) is exactly zero; the matrix is
                  singular and its inverse could not be computed.

=for example

 $a = random (float, 100, 100);
 $ipiv = zeroes(long, 100);
 $info = null;
 getrf($a, $ipiv, $info);
 if ($info == 0){
	getri($a, $ipiv, $info);
 }
 print "Inverse of \$a is :\n $a" unless $info;

=for bad

getri ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*getri = \&PDL::getri;






=head2 sytri

=for sig

  Signature: ([io]A(n,n); int uplo(); int ipiv(n); int [o]info(); [t]work(n))

=for ref

Computes the inverse of a real symmetric indefinite matrix
A using the factorization A = U*D*U' or A = L*D*L' computed by
C<sytrf>.

    Arguments
    =========

    uplo:   Specifies whether the details of the factorization are stored
            as an upper or lower triangular matrix.
            = 0:  Upper triangular, form is A = U*D*U';
            = 1:  Lower triangular, form is A = L*D*L'.

    A:      On entry, the block diagonal matrix D and the multipliers
            used to obtain the factor U or L as computed by sytrf.

            On exit, if info = 0, the (symmetric) inverse of the original
            matrix.  If uplo = 0, the upper triangular part of the
            inverse is formed and the part of A below the diagonal is not
            referenced; if uplo = 1 the lower triangular part of the
            inverse is formed and the part of A above the diagonal is
            not referenced.

    ipiv:   Details of the interchanges and the block structure of D
            as determined by sytrf.

    info:   = 0: successful exit
            < 0: if info = -i, the i-th argument had an illegal value
            > 0: if info = i, D(i,i) = 0; the matrix is singular and its
                 inverse could not be computed.

=for example

 $a = random (float, 100, 100);
 # assume $a is symmetric
 $ipiv = zeroes(long, 100);
 sytrf($a, 0, $ipiv, ($info=null));
 if ($info == 0){
	sytri($a, 0, $ipiv, $info);
 }
 print "Inverse of \$a is :\n $a" unless $info;

=for bad

sytri ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*sytri = \&PDL::sytri;






=head2 potri

=for sig

  Signature: ([io]A(n,n); int uplo(); int [o]info())

=for ref

Computes the inverse of a real symmetric positive definite
matrix A using the Cholesky factorization A = U'*U or A = L*L'
computed by C<potrf>.

    Arguments
    =========

    uplo:   = 0:  Upper triangle of A is stored;
            = 1:  Lower triangle of A is stored.

    A:      On entry, the triangular factor U or L from the Cholesky
            factorization A = U'*U or A = L*L', as computed by
            potrf.
            On exit, the upper or lower triangle of the (symmetric)
            inverse of A, overwriting the input factor U or L.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value
            > 0:  if info = i, the (i,i) element of the factor U or L is
                  zero, and the inverse could not be computed.

=for example

 $a = random (float, 100, 100);
 # Assume $a is symmetric positive definite
 potrf($a, 0, ($info = null));
 if ($info == 0){ # Hum... is it positive definite????
	potri($a, 0,$info);
 }
 print "Inverse of \$a is :\n $a" unless $info;

=for bad

potri ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*potri = \&PDL::potri;






=head2 trtri

=for sig

  Signature: ([io]A(n,n); int uplo(); int diag(); int [o]info())

=for ref

Computes the inverse of a real upper or lower triangular
matrix A.

This is the Level 3 BLAS version of the algorithm.

    Arguments
    =========

    uplo:   = 0:  A is upper triangular;
            = 1:  A is lower triangular.

    diag:   = 0:  A is non-unit triangular;
            = 1:  A is unit triangular.

    A:      On entry, the triangular matrix A.  If uplo = 0, the
            leading N-by-N upper triangular part of the array A contains
            the upper triangular matrix, and the strictly lower
            triangular part of A is not referenced.  If uplo = 1, the
            leading N-by-N lower triangular part of the array A contains
            the lower triangular matrix, and the strictly upper
            triangular part of A is not referenced.  If diag = 1, the
            diagonal elements of A are also not referenced and are
            assumed to be 1.
            On exit, the (triangular) inverse of the original matrix, in
            the same storage format.

    info:   = 0: successful exit
            < 0: if info = -i, the i-th argument had an illegal value
            > 0: if info = i, A(i,i) is exactly zero.  The triangular
                 matrix is singular and its inverse can not be computed.

=for example

 $a = random (float, 100, 100);
 # assume $a is upper triangular
 trtri($a, 1, ($info=null));
 print "Inverse of \$a is :\n transpose($a)" unless $info;

=for bad

trtri ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*trtri = \&PDL::trtri;






=head2 trti2

=for sig

  Signature: ([io]A(n,n); int uplo(); int diag(); int [o]info())

=for ref

Computes the inverse of a real upper or lower triangular
matrix A.

This is the Level 2 BLAS version of the algorithm.

    Arguments
    =========

    uplo:   = 0:  A is upper triangular;
            = 1:  A is lower triangular.

    diag:   = 0:  A is non-unit triangular;
            = 1:  A is unit triangular.

    A:      On entry, the triangular matrix A.  If uplo = 0, the
            leading N-by-N upper triangular part of the array A contains
            the upper triangular matrix, and the strictly lower
            triangular part of A is not referenced.  If uplo = 1, the
            leading N-by-N lower triangular part of the array A contains
            the lower triangular matrix, and the strictly upper
            triangular part of A is not referenced.  If diag = 1, the
            diagonal elements of A are also not referenced and are
            assumed to be 1.
            On exit, the (triangular) inverse of the original matrix, in
            the same storage format.

    info:   = 0: successful exit
            < 0: if info = -i, the i-th argument had an illegal value

=for example

 $a = random (float, 100, 100);
 # assume $a is upper triangular
 trtri2($a, 1, ($info=null));
 print "Inverse of \$a is :\n transpose($a)" unless $info;

=for bad

trti2 ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*trti2 = \&PDL::trti2;






=head2 getrs

=for sig

  Signature: (A(n,n); int trans(); [io]B(n,m); int ipiv(n); int [o]info())

=for ref

Solves a system of linear equations

	A * X = B  or  A' * X = B

with a general N-by-N matrix A using the LU factorization computed
by getrf.

    Arguments
    =========

    trans:  Specifies the form of the system of equations:
            = 0:  A * X = B  (No transpose)
            = 1:  A'* X = B  (Transpose)

    A:      The factors L and U from the factorization A = P*L*U
            as computed by getrf.

    ipiv:   The pivot indices from getrf; for 1<=i<=N, row i of the
            matrix was interchanged with row ipiv(i).

    B:      On entry, the right hand side matrix B.
            On exit, the solution matrix X.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value

=for example

 $a = random (float, 100, 100);
 $ipiv = zeroes(long, 100);
 $b = random(100,50);
 getrf($a, $ipiv, ($info=null));
 if ($info == 0){
	getrs($a, 0, $b, $ipiv, $info);
 }
 print "X is :\n $b" unless $info;

=for bad

getrs ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*getrs = \&PDL::getrs;






=head2 sytrs

=for sig

  Signature: (A(n,n); int uplo();[io]B(n,m); int ipiv(n); int [o]info())

=for ref

Solves a system of linear equations A*X = B with a real
symmetric matrix A using the factorization A = U*D*U' or
A = L*D*L' computed by C<sytrf>.

    Arguments
    =========

    uplo:   Specifies whether the details of the factorization are stored
            as an upper or lower triangular matrix.
            = 0:  Upper triangular, form is A = U*D*U';
            = 1:  Lower triangular, form is A = L*D*L'.

    A:      The block diagonal matrix D and the multipliers used to
            obtain the factor U or L as computed by sytrf.

    ipiv:   Details of the interchanges and the block structure of D
            as determined by sytrf.

    B:      On entry, the right hand side matrix B.
            On exit, the solution matrix X.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value

=for example

 $a = random (float, 100, 100);
 $b = random(50,100);
 $a = transpose($a);
 $b = transpose($b);
 # Assume $a is symmetric
 sytrf($a, 0, ($ipiv=zeroes(100)), ($info=null));
 if ($info == 0){
	sytrs($a, 0, $b, $ipiv, $info);
 }
 print("X is :\n".transpose($b))unless $info;

=for bad

sytrs ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*sytrs = \&PDL::sytrs;






=head2 potrs

=for sig

  Signature: (A(n,n); int uplo(); [io]B(n,m); int [o]info())

=for ref

Solves a system of linear equations A*X = B with a symmetric
positive definite matrix A using the Cholesky factorization
A = U'*U or A = L*L' computed by C<potrf>.

    Arguments
    =========

    uplo:   = 0:  Upper triangle of A is stored;
            = 1:  Lower triangle of A is stored.

    A:      The triangular factor U or L from the Cholesky factorization
            A = U'*U or A = L*L', as computed by potrf.

    B:      On entry, the right hand side matrix B.
            On exit, the solution matrix X.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value

=for example

 $a = random (float, 100, 100);
 $b = random(50,100);
 $a = transpose($a);
 $b = transpose($b);
 # Assume $a is symmetric positive definite
 potrf($a, 0, ($info=null));
 if ($info == 0){
	potrs($a, 0, $b, $info);
 }
 print("X is :\n".transpose($b))unless $info;

=for bad

potrs ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*potrs = \&PDL::potrs;






=head2 trtrs

=for sig

  Signature: (A(n,n); int uplo(); int trans(); int diag();[io]B(n,m); int [o]info())

=for ref

Solves a triangular system of the form

	A * X = B  or  A' * X = B,

	where A is a triangular matrix of order N, and B is an N-by-NRHS
	matrix.

A check is made to verify that A is nonsingular.

    Arguments
    =========

    uplo:   = 0:  A is upper triangular;
            = 1:  A is lower triangular.

    trans:  Specifies the form of the system of equations:
            = 0:  A * X = B  (No transpose)
            = 1:  A**T * X = B  (Transpose)

    diag:   = 0:  A is non-unit triangular;
            = 1:  A is unit triangular.

    A:      The triangular matrix A.  If uplo = 0, the leading N-by-N
            upper triangular part of the array A contains the upper
            triangular matrix, and the strictly lower triangular part of
            A is not referenced.  If uplo = 1, the leading N-by-N lower
            triangular part of the array A contains the lower triangular
            matrix, and the strictly upper triangular part of A is not
            referenced.  If diag = 1, the diagonal elements of A are
            also not referenced and are assumed to be 1.

    B:      On entry, the right hand side matrix B.
            On exit, if info = 0, the solution matrix X.

    info    = 0:  successful exit
            < 0: if info = -i, the i-th argument had an illegal value
            > 0: if info = i, the i-th diagonal element of A is zero,
                 indicating that the matrix is singular and the solutions
                 X have not been computed.

=for example

 # Assume $a is upper triangular
 $a = random (float, 100, 100);
 $b = random(50,100);
 $a = transpose($a);
 $b = transpose($b);
 $info = null;
 trtrs($a, 0, 0, 0, $b, $info);
 print("X is :\n".transpose($b))unless $info;

=for bad

trtrs ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*trtrs = \&PDL::trtrs;






=head2 latrs

=for sig

  Signature: (A(n,n); int uplo(); int trans(); int diag(); int normin();[io]x(n); [o]scale();[io]cnorm(n);int [o]info())

=for ref

Solves one of the triangular systems

	A *x = s*b  or  A'*x = s*b

with scaling to prevent overflow.  Here A is an upper or lower
triangular matrix, A' denotes the transpose of A, x and b are
n-element vectors, and s is a scaling factor, usually less than
or equal to 1, chosen so that the components of x will be less than
the overflow threshold.  If the unscaled problem will not cause
overflow, the Level 2 BLAS routine C<trsv> is called.  If the matrix A
is singular (A(j,j) = 0 for some j), then s is set to 0 and a
non-trivial solution to A*x = 0 is returned.

Further Details
======= =======

A rough bound on x is computed; if that is less than overflow, trsv
is called, otherwise, specific code is used which checks for possible
overflow or divide-by-zero at every operation.

A columnwise scheme is used for solving A*x = b.  The basic algorithm
if A is lower triangular is

         x[1:n] := b[1:n]
         for j = 1, ..., n
              x(j) := x(j) / A(j,j)
              x[j+1:n] := x[j+1:n] - x(j) * A[j+1:n,j]
         end

Define bounds on the components of x after j iterations of the loop:

       M(j) = bound on x[1:j]
       G(j) = bound on x[j+1:n]

Initially, let M(0) = 0 and G(0) = max{x(i), i=1,...,n}.

    Then for iteration j+1 we have
       M(j+1) <= G(j) / | A(j+1,j+1) |
       G(j+1) <= G(j) + M(j+1) * | A[j+2:n,j+1] |
              <= G(j) ( 1 + cnorm(j+1) / | A(j+1,j+1) | )

    where cnorm(j+1) is greater than or equal to the infinity-norm of
    column j+1 of A, not counting the diagonal.

Hence

       G(j) <= G(0) product ( 1 + cnorm(i) / | A(i,i) | )
                    1<=i<=j
    and

       |x(j)| <= ( G(0) / |A(j,j)| ) product ( 1 + cnorm(i) / |A(i,i)| )
                                     1<=i< j

Since |x(j)| <= M(j), we use the Level 2 BLAS routine DTRSV if the
reciprocal of the largest M(j), j=1,..,n, is larger than
max(underflow, 1/overflow).

The bound on x(j) is also used to determine when a step in the
columnwise method can be performed without fear of overflow.  If
the computed bound is greater than a large constant, x is scaled to
prevent overflow, but if the bound overflows, x is set to 0, x(j) to
1, and scale to 0, and a non-trivial solution to A*x = 0 is found.

Similarly, a row-wise scheme is used to solve A'*x = b.  The basic
algorithm for A upper triangular is

         for j = 1, ..., n
              x(j) := ( b(j) - A[1:j-1,j]' * x[1:j-1] ) / A(j,j)
         end

We simultaneously compute two bounds

         G(j) = bound on ( b(i) - A[1:i-1,i]' * x[1:i-1] ), 1<=i<=j
         M(j) = bound on x(i), 1<=i<=j

The initial values are G(0) = 0, M(0) = max{b(i), i=1,..,n}, and we
add the constraint G(j) >= G(j-1) and M(j) >= M(j-1) for j >= 1.
Then the bound on x(j) is

         M(j) <= M(j-1) * ( 1 + cnorm(j) ) / | A(j,j) |

              <= M(0) * product ( ( 1 + cnorm(i) ) / |A(i,i)| )
                        1<=i<=j

and we can safely call trsv if 1/M(n) and 1/G(n) are both greater
than max(underflow, 1/overflow).

    Arguments
    =========

    uplo:   Specifies whether the matrix A is upper or lower triangular.
            = 0:  Upper triangular
            = 1:  Lower triangular

    trans:  Specifies the operation applied to A.
            = 0:  Solve A * x = s*b  (No transpose)
            = 1:  Solve A'* x = s*b  (Transpose)

    diag:   Specifies whether or not the matrix A is unit triangular.
            = 0:  Non-unit triangular
            = 1:  Unit triangular

    normin: Specifies whether cnorm has been set or not.
            = 1:  cnorm contains the column norms on entry
            = 0:  cnorm is not set on entry.  On exit, the norms will
                    be computed and stored in cnorm.

    A:      The triangular matrix A.  If uplo = 0, the leading n by n
            upper triangular part of the array A contains the upper
            triangular matrix, and the strictly lower triangular part of
            A is not referenced.  If uplo = 1, the leading n by n lower
            triangular part of the array A contains the lower triangular
            matrix, and the strictly upper triangular part of A is not
            referenced.  If diag = 1, the diagonal elements of A are
            also not referenced and are assumed to be 1.

    x:      On entry, the right hand side b of the triangular system.
            On exit, x is overwritten by the solution vector x.

    scale:  The scaling factor s for the triangular system
               A * x = s*b  or  A'* x = s*b.
            If scale = 0, the matrix A is singular or badly scaled, and
            the vector x is an exact or approximate solution to A*x = 0.

    cnorm:  If normin = 0, cnorm is an output argument and cnorm(j)
            returns the 1-norm of the offdiagonal part of the j-th column
            of A.
	    If normin = 1, cnorm is an input argument and cnorm(j)
            contains the norm of the off-diagonal part of the j-th column
            of A.  If trans = 0, cnorm(j) must be greater than or equal
            to the infinity-norm, and if trans = 1, cnorm(j)
            must be greater than or equal to the 1-norm.

    info:   = 0:  successful exit
            < 0:  if info = -k, the k-th argument had an illegal value

=for example

 # Assume $a is upper triangular
 $a = random (float, 100, 100);
 $b = random(100);
 $a = transpose($a);
 $info = null;
 $scale= null;
 $cnorm = zeroes(100);
 latrs($a, 0, 0, 0, 0,$b, $scale, $cnorm,$info);

=for bad

latrs ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*latrs = \&PDL::latrs;






=head2 gecon

=for sig

  Signature: (A(n,n); int norm(); anorm(); [o]rcond();int [o]info(); int [t]iwork(n); [t]work(workn=CALC(4*$SIZE(n))))

=for ref

Estimates the reciprocal of the condition number of a general
real matrix A, in either the 1-norm or the infinity-norm, using
the LU factorization computed by C<getrf>.

An estimate is obtained for norm(inv(A)), and the reciprocal of the
condition number is computed as

       rcond = 1 / ( norm(A) * norm(inv(A)) ).

    Arguments
    =========

    norm:   Specifies whether the 1-norm condition number or the
            infinity-norm condition number is required:
            = 0:  Infinity-norm.
            = 1:  1-norm;

    A:      The factors L and U from the factorization A = P*L*U
            as computed by getrf.

    anorm:  If norm = 0, the infinity-norm of the original matrix A.
            If norm = 1, the 1-norm of the original matrix A.

    rcond:  The reciprocal of the condition number of the matrix A,
            computed as rcond = 1/(norm(A) * norm(inv(A))).

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value

=for example

 $a = random (float, 100, 100);
 $anorm  = $a->lange(1);
 $ipiv = zeroes(long, 100);
 $info = null;
 getrf($a, $ipiv, $info);
 ($rcond, $info) = gecon($a, 1, $anorm) unless $info != 0;

=for bad

gecon ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*gecon = \&PDL::gecon;






=head2 sycon

=for sig

  Signature: (A(n,n); int uplo(); int ipiv(n); anorm(); [o]rcond();int [o]info(); int [t]iwork(n); [t]work(workn=CALC(2*$SIZE(n))))

=for ref

Estimates the reciprocal of the condition number (in the
1-norm) of a real symmetric matrix A using the factorization
A = U*D*U' or A = L*D*L' computed by C<sytrf>.

An estimate is obtained for norm(inv(A)), and the reciprocal of the
condition number is computed as rcond = 1 / (anorm * norm(inv(A))).

    Arguments
    =========

    uplo:   Specifies whether the details of the factorization are stored
            as an upper or lower triangular matrix.
            = 0:  Upper triangular, form is A = U*D*U';
            = 1:  Lower triangular, form is A = L*D*L'.

    A:      The block diagonal matrix D and the multipliers used to
            obtain the factor U or L as computed by sytrf.

    ipiv:   Details of the interchanges and the block structure of D
            as determined by sytrf.

    anorm:  The 1-norm of the original matrix A.

    rcond:  The reciprocal of the condition number of the matrix A,
            computed as rcond = 1/(anorm * aimvnm), where ainvnm is an
            estimate of the 1-norm of inv(A) computed in this routine.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value.

=for example

 # Assume $a is symmetric
 $a = random (float, 100, 100);
 $anorm  = $a->lansy(1,1);
 $ipiv = zeroes(long, 100);
 $info = null;
 sytrf($a, 1,$ipiv, $info);
 ($rcond, $info) = sycon($a, 1, $anorm) unless $info != 0;

=for bad

sycon ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*sycon = \&PDL::sycon;






=head2 pocon

=for sig

  Signature: (A(n,n); int uplo(); anorm(); [o]rcond();int [o]info(); int [t]iwork(n); [t]work(workn=CALC(3*$SIZE(n))))

=for ref

Estimates the reciprocal of the condition number (in the
1-norm) of a real symmetric positive definite matrix using the
Cholesky factorization A = U'*U or A = L*L' computed by C<potrf>.

An estimate is obtained for norm(inv(A)), and the reciprocal of the
condition number is computed as rcond = 1 / (anorm * norm(inv(A))).

    Arguments
    =========

    uplo:   = 0:  Upper triangle of A is stored;
            = 1:  Lower triangle of A is stored.

    A:      The triangular factor U or L from the Cholesky factorization
            A = U'*U or A = L*L', as computed by potrf.

    anorm:  The 1-norm of the matrix A.

    rcond:  The reciprocal of the condition number of the matrix A,
            computed as rcond = 1/(anorm * ainvnm), where ainvnm is an
            estimate of the 1-norm of inv(A) computed in this routine.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value

=for example

 # Assume $a is symmetric positive definite
 $a = random (float, 100, 100);
 $anorm  = $a->lansy(1,1);
 $info = null;
 potrf($a,  0, $info);
 ($rcond, $info) = pocon($a, 1, $anorm) unless $info != 0;

=for bad

pocon ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*pocon = \&PDL::pocon;






=head2 trcon

=for sig

  Signature: (A(n,n); int norm();int uplo();int diag(); [o]rcond();int [o]info(); int [t]iwork(n); [t]work(workn=CALC(3*$SIZE(n))))

=for ref

Estimates the reciprocal of the condition number of a
triangular matrix A, in either the 1-norm or the infinity-norm.

The norm of A is computed and an estimate is obtained for
norm(inv(A)), then the reciprocal of the condition number is
computed as

	rcond = 1 / ( norm(A) * norm(inv(A)) ).

    Arguments
    =========

    norm:   Specifies whether the 1-norm condition number or the
            infinity-norm condition number is required:
            = 0:	Infinity-norm.
            = 1:	1-norm;

    uplo:   = 0:  A is upper triangular;
            = 1:  A is lower triangular.

    diag:   = 0:  A is non-unit triangular;
            = 1:  A is unit triangular.

    A:      The triangular matrix A.  If uplo = 0, the leading N-by-N
            upper triangular part of the array A contains the upper
            triangular matrix, and the strictly lower triangular part of
            A is not referenced.  If uplo = 1, the leading N-by-N lower
            triangular part of the array A contains the lower triangular
            matrix, and the strictly upper triangular part of A is not
            referenced.  If diag = 1, the diagonal elements of A are
            also not referenced and are assumed to be 1.

    rcond:  The reciprocal of the condition number of the matrix A,
            computed as rcond = 1/(norm(A) * norm(inv(A))).

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value

=for example

 # Assume $a is upper triangular
 $a = random (float, 100, 100);
 $info = null;
 ($rcond, $info) = trcon($a, 1, 1, 0) unless $info != 0;

=for bad

trcon ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*trcon = \&PDL::trcon;






=head2 geqp3

=for sig

  Signature: ([io]A(m,n); int [io]jpvt(n); [o]tau(k); int [o]info())

=for ref

geqp3 computes a QR factorization  using Level 3 BLAS with column pivoting of a
matrix A:

		A*P = Q*R

The matrix Q is represented as a product of elementary reflectors

	Q = H(1) H(2) . . . H(k), where k = min(m,n).

Each H(i) has the form

	H(i) = I - tau * v * v'

	where tau is a real/complex scalar, and v is a real/complex vector
	with v(1:i-1) = 0 and v(i) = 1; v(i+1:m) is stored on exit in
	A(i+1:m,i), and tau in tau(i).

    Arguments
    =========

    A:      On entry, the M-by-N matrix A.
            On exit, the upper triangle of the array contains the
            min(M,N)-by-N upper trapezoidal matrix R; the elements below
            the diagonal, together with the array tau, represent the
            orthogonal matrix Q as a product of min(M,N) elementary
            reflectors.

    jpvt:   On entry, if jpvt(J)!=0, the J-th column of A is permuted
            to the front of A*P (a leading column); if jpvt(J)=0,
            the J-th column of A is a free column.
            On exit, if jpvt(J)=K, then the J-th column of A*P was the
            the K-th column of A.

    tau:    The scalar factors of the elementary reflectors.

    info:   = 0: successful exit.
            < 0: if info = -i, the i-th argument had an illegal value.

=for example

 $a = random (float, 100, 50);
 $info = null;
 $tau = zeroes(float, 50);
 $jpvt = zeroes(long, 50);
 geqp3($a, $jpvt, $tau, $info);

=for bad

geqp3 ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*geqp3 = \&PDL::geqp3;






=head2 geqrf

=for sig

  Signature: ([io]A(m,n); [o]tau(k); int [o]info())

=for ref

geqrf computes a QR factorization of a
matrix A:

	A = Q * R

The matrix Q is represented as a product of elementary reflectors

	Q = H(1) H(2) . . . H(k), where k = min(m,n).

Each H(i) has the form

	H(i) = I - tau * v * v'

	where tau is a real/complex scalar, and v is a real/complex vector
	with v(1:i-1) = 0 and v(i) = 1; v(i+1:m) is stored on exit in
	A(i+1:m,i), and tau in tau(i).

    Arguments
    =========

    A:      On exit, the elements on and above the diagonal of the array
            contain the min(M,N)-by-N upper trapezoidal matrix R (R is
            upper triangular if m >= n); the elements below the diagonal,
            with the array TAU, represent the orthogonal matrix Q as a
            product of min(m,n) elementary reflectors.

    tau:    The scalar factors of the elementary reflectors.

    info:   = 0: successful exit.
            < 0: if info = -i, the i-th argument had an illegal value.

=for example

 $a = random (float, 100, 50);
 $info = null;
 $tau = zeroes(float, 50);
 geqrf($a, $tau, $info);

=for bad

geqrf ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*geqrf = \&PDL::geqrf;






=head2 orgqr

=for sig

  Signature: ([io]A(m,n); tau(k); int [o]info())

=for ref

Generates an M-by-N real matrix Q with orthonormal columns,
which is defined as the first N columns of a product of K elementary
reflectors of order M

	Q  =  H(1) H(2) . . . H(k)

	as returned by geqrf or geqp3.

    Arguments
    =========

    A:      On entry, the i-th column must contain the vector which
            defines the elementary reflector H(i), for i = 1,2,...,k, as
            returned by geqrf or geqp3 in the first k columns of its array
            argument A.
            On exit, the M-by-N matrix Q.

    tau:    tau(i) must contain the scalar factor of the elementary
            reflector H(i), as returned by geqrf or geqp3.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument has an illegal value

=for example

 $a = random (float, 100, 50);
 $info = null;
 $tau = zeroes(float, 50);
 geqrf($a, $tau, $info);
 orgqr($a, $tau, $info) unless $info != 0;

=for bad

orgqr ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*orgqr = \&PDL::orgqr;






=head2 ormqr

=for sig

  Signature: (A(p,k); int side(); int trans(); tau(k); [io]C(m,n);int [o]info())

=for ref

Overwrites the general real M-by-N matrix C with

                    side = 0     side = 1
    trans = 0:      Q * C          C * Q
    trans = 1:      Q' * C       C * Q'

    where Q is a real orthogonal matrix defined as the product of k
    elementary reflectors

          Q = H(1) H(2) . . . H(k)

	as returned by geqrf or geqp3.

Q is of order M if C<side> = 0 and of order N
if C<side> = 1.

    Arguments
    =========

    side:   = 0: apply Q or Q' from the Left;
            = 1: apply Q or Q' from the Right.

    trans:  = 0:  No transpose, apply Q;
            = 1:  Transpose, apply Q'.

    A:      The i-th column must contain the vector which defines the
            elementary reflector H(i), for i = 1,2,...,k, as returned by
            geqrf or geqp3 in the first k columns of its array argument A.
            A is modified by the routine but restored on exit.

    tau:    tau(i) must contain the scalar factor of the elementary
            reflector H(i), as returned by geqrf or geqp3.

    C:      On entry, the M-by-N matrix C.
            On exit, C is overwritten by Q*C or Q'*C or C*Q' or C*Q.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value

=for example

 $a = random (float, 50, 100);
 $a = transpose($a);
 $info = null;
 $tau = zeroes(float, 50);
 geqrf($a, $tau, $info);
 $c = random(70,50);
 # $c will contain the result
 $c->reshape(70,100);
 $c = transpose($c);
 ormqr($a, $tau, $c, $info);

=for bad

ormqr ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*ormqr = \&PDL::ormqr;






=head2 gelqf

=for sig

  Signature: ([io]A(m,n); [o]tau(k); int [o]info())

=for ref

Computes an LQ factorization of a real M-by-N matrix A:

	A = L * Q.

The matrix Q is represented as a product of elementary reflectors

       Q = H(k) . . . H(2) H(1), where k = min(m,n).

Each H(i) has the form

	H(i) = I - tau * v * v'

	where tau is a real scalar, and v is a real vector with
	v(1:i-1) = 0 and v(i) = 1; v(i+1:n) is stored on exit in A(i,i+1:n),
	and tau in tau(i).

    Arguments
    =========

    A:      On entry, the M-by-N matrix A.
            On exit, the elements on and below the diagonal of the array
            contain the m-by-min(m,n) lower trapezoidal matrix L (L is
            lower triangular if m <= n); the elements above the diagonal,
            with the array tau, represent the orthogonal matrix Q as a
            product of elementary reflectors.

    tau:    The scalar factors of the elementary reflectors.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value

=for example

 $a = random (float, 100, 50);
 $info = null;
 $tau = zeroes(float, 50);
 gelqf($a, $tau, $info);

=for bad

gelqf ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*gelqf = \&PDL::gelqf;






=head2 orglq

=for sig

  Signature: ([io]A(m,n); tau(k); int [o]info())

=for ref

Generates an M-by-N real matrix Q with orthonormal rows,
which is defined as the first M rows of a product of K elementary
reflectors of order N

	Q  =  H(k) . . . H(2) H(1)

	as returned by gelqf.

    Arguments
    =========

    A:      On entry, the i-th row must contain the vector which defines
            the elementary reflector H(i), for i = 1,2,...,k, as returned
            by gelqf in the first k rows of its array argument A.
            On exit, the M-by-N matrix Q.

    tau:    tau(i) must contain the scalar factor of the elementary
            reflector H(i), as returned by gelqf.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument has an illegal value

=for example

 $a = random (float, 100, 50);
 $info = null;
 $tau = zeroes(float, 50);
 gelqf($a, $tau, $info);
 orglq($a, $tau, $info) unless $info != 0;

=for bad

orglq ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*orglq = \&PDL::orglq;






=head2 ormlq

=for sig

  Signature: (A(k,p); int side(); int trans(); tau(k); [io]C(m,n);int [o]info())

=for ref

Overwrites the general real M-by-N matrix C with

                    side = 0     side = 1
    trans = 0:      Q * C          C * Q
    trans = 1:      Q' * C       C * Q'

    where Q is a real orthogonal matrix defined as the product of k
    elementary reflectors

          Q = H(k) . . . H(2) H(1)

    as returned by gelqf.

Q is of order M if C<side> = 0 and of order N
if C<side> = 1.

    Arguments
    =========

    side:   = 0: apply Q or Q' from the Left;
            = 1: apply Q or Q' from the Right.

    trans:  = 0:  No transpose, apply Q;
            = 1:  Transpose, apply Q'.

    A:      The i-th row must contain the vector which defines the
            elementary reflector H(i), for i = 1,2,...,k, as returned by
            gelqf in the first k rows of its array argument A.
            A is modified by the routine but restored on exit.

    tau:    tau(i) must contain the scalar factor of the elementary
            reflector H(i), as returned by gelqf.

    C:      On entry, the M-by-N matrix C.
            On exit, C is overwritten by Q*C or Q'*C or C*Q' or C*Q.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value

=for example

 $a = random (float, 50, 100);
 $a = transpose($a);
 $info = null;
 $tau = zeroes(float, 50);
 gelqf($a, $tau, $info);
 $c = random(70,50);
 # $c will contain the result
 $c->reshape(70,100);
 $c = transpose($c);
 ormlq($a, $tau, $c, $info);

=for bad

ormlq ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*ormlq = \&PDL::ormlq;






=head2 geqlf

=for sig

  Signature: ([io]A(m,n); [o]tau(k); int [o]info())

=for ref

Computes a QL factorization of a real M-by-N matrix A:

	A = Q * L

The matrix Q is represented as a product of elementary reflectors

	Q = H(k) . . . H(2) H(1), where k = min(m,n).

Each H(i) has the form

	H(i) = I - tau * v * v'

	where tau is a real scalar, and v is a real vector with
	v(m-k+i+1:m) = 0 and v(m-k+i) = 1; v(1:m-k+i-1) is stored on exit in
	A(1:m-k+i-1,n-k+i), and tau in TAU(i).

    Arguments
    =========

    A:      On entry, the M-by-N matrix A.
            On exit,
            if m >= n, the lower triangle of the subarray
            A(m-n+1:m,1:n) contains the N-by-N lower triangular matrix L;
            if m <= n, the elements on and below the (n-m)-th
            superdiagonal contain the M-by-N lower trapezoidal matrix L;
            the remaining elements, with the array tau, represent the
            orthogonal matrix Q as a product of elementary reflectors.

    tau:    The scalar factors of the elementary reflectors.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value

=for example

 $a = random (float, 100, 50);
 $info = null;
 $tau = zeroes(float, 50);
 geqlf($a, $tau, $info);

=for bad

geqlf ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*geqlf = \&PDL::geqlf;






=head2 orgql

=for sig

  Signature: ([io]A(m,n); tau(k); int [o]info())

=for ref

Generates an M-by-N real matrix Q with orthonormal columns,
which is defined as the last N columns of a product of K elementary
reflectors of order M

	Q  =  H(k) . . . H(2) H(1)

	as returned by geqlf.

    Arguments
    =========

    A:      On entry, the (n-k+i)-th column must contain the vector which
            defines the elementary reflector H(i), for i = 1,2,...,k, as
            returned by geqlf in the last k columns of its array
            argument A.
            On exit, the M-by-N matrix Q.

    tau:    tau(i) must contain the scalar factor of the elementary
            reflector H(i), as returned by geqlf.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument has an illegal value

=for example

 $a = random (float, 100, 50);
 $info = null;
 $tau = zeroes(float, 50);
 geqlf($a, $tau, $info);
 orgql($a, $tau, $info) unless $info != 0;

=for bad

orgql ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*orgql = \&PDL::orgql;






=head2 ormql

=for sig

  Signature: (A(p,k); int side(); int trans(); tau(k); [io]C(m,n);int [o]info())

=for ref

Overwrites the general real M-by-N matrix C with

                    side = 0     side = 1
    trans = 0:      Q * C          C * Q
    trans = 1:      Q' * C       C * Q'

    where Q is a real orthogonal matrix defined as the product of k
    elementary reflectors

          Q = H(k) . . . H(2) H(1)

    as returned by geqlf.

Q is of order M if C<side> = 0 and of order N
if C<side> = 1.

    Arguments
    =========

    side:   = 0: apply Q or Q' from the Left;
            = 1: apply Q or Q' from the Right.

    trans:  = 0:  No transpose, apply Q;
            = 1:  Transpose, apply Q'.

    A:      The i-th row must contain the vector which defines the
            elementary reflector H(i), for i = 1,2,...,k, as returned by
            geqlf in the last k rows of its array argument A.
            A is modified by the routine but restored on exit.

    tau:    tau(i) must contain the scalar factor of the elementary
            reflector H(i), as returned by geqlf.

    C:      On entry, the M-by-N matrix C.
            On exit, C is overwritten by Q*C or Q'*C or C*Q' or C*Q.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value

=for example

 $a = random (float, 50, 100);
 $a = transpose($a);
 $info = null;
 $tau = zeroes(float, 50);
 geqlf($a, $tau, $info);
 $c = random(70,50);
 # $c will contain the result
 $c->reshape(70,100);
 $c = transpose($c);
 ormql($a, $tau, $c, $info);

=for bad

ormql ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*ormql = \&PDL::ormql;






=head2 gerqf

=for sig

  Signature: ([io]A(m,n); [o]tau(k); int [o]info())

=for ref

Computes an RQ factorization of a real M-by-N matrix A:

	A = R * Q.

The matrix Q is represented as a product of elementary reflectors

	Q = H(1) H(2) . . . H(k), where k = min(m,n).

Each H(i) has the form

	H(i) = I - tau * v * v'

	where tau is a real scalar, and v is a real vector with
	v(n-k+i+1:n) = 0 and v(n-k+i) = 1; v(1:n-k+i-1) is stored on exit in
	A(m-k+i,1:n-k+i-1), and tau in TAU(i).

    Arguments
    =========

    A:      On entry, the M-by-N matrix A.
            On exit,
            if m <= n, the upper triangle of the subarray
            A(1:m,n-m+1:n) contains the M-by-M upper triangular matrix R;
            if m >= n, the elements on and above the (m-n)-th subdiagonal
            contain the M-by-N upper trapezoidal matrix R;
            the remaining elements, with the array tau, represent the
            orthogonal matrix Q as a product of min(m,n) elementary
            reflectors (see Further Details).

    tau:    The scalar factors of the elementary reflectors.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value

=for example

 $a = random (float, 100, 50);
 $info = null;
 $tau = zeroes(float, 50);
 gerqf($a, $tau, $info);

=for bad

gerqf ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*gerqf = \&PDL::gerqf;






=head2 orgrq

=for sig

  Signature: ([io]A(m,n); tau(k); int [o]info())

=for ref

Generates an M-by-N real matrix Q with orthonormal rows,
which is defined as the last M rows of a product of K elementary
reflectors of order N

	Q  =  H(1) H(2) . . . H(k)

	as returned by gerqf.

    Arguments
    =========

    A:      On entry, the (m-k+i)-th row must contain the vector which
            defines the elementary reflector H(i), for i = 1,2,...,k, as
            returned by gerqf in the last k rows of its array argument
            A.
            On exit, the M-by-N matrix Q.

    tau:    tau(i) must contain the scalar factor of the elementary
            reflector H(i), as returned by gerqf.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument has an illegal value

=for example

 $a = random (float, 100, 50);
 $info = null;
 $tau = zeroes(float, 50);
 gerqf($a, $tau, $info);
 orgrq($a, $tau, $info) unless $info != 0;

=for bad

orgrq ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*orgrq = \&PDL::orgrq;






=head2 ormrq

=for sig

  Signature: (A(k,p); int side(); int trans(); tau(k); [io]C(m,n);int [o]info())

=for ref

Overwrites the general real M-by-N matrix C with

                    side = 0     side = 1
    trans = 0:      Q * C          C * Q
    trans = 1:      Q' * C       C * Q'

    where Q is a real orthogonal matrix defined as the product of k
    elementary reflectors

          Q = H(1) H(2) . . . H(k)

	as returned by gerqf.

Q is of order M if C<side> = 0 and of order N
if C<side> = 1.

    Arguments
    =========

    side:   = 0: apply Q or Q' from the Left;
            = 1: apply Q or Q' from the Right.

    trans:  = 0:  No transpose, apply Q;
            = 1:  Transpose, apply Q'.

    A:      The i-th row must contain the vector which defines the
            elementary reflector H(i), for i = 1,2,...,k, as returned by
            gerqf in the last k rows of its array argument A.
            A is modified by the routine but restored on exit.

    tau:    tau(i) must contain the scalar factor of the elementary
            reflector H(i), as returned by gerqf.

    C:      On entry, the M-by-N matrix C.
            On exit, C is overwritten by Q*C or Q'*C or C*Q' or C*Q.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value

=for example

 $a = random (float, 50, 100);
 $a = transpose($a);
 $info = null;
 $tau = zeroes(float, 50);
 gerqf($a, $tau, $info);
 $c = random(70,50);
 # $c will contain the result
 $c->reshape(70,100);
 $c = transpose($c);
 ormrq($a, $tau, $c, $info);

=for bad

ormrq ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*ormrq = \&PDL::ormrq;






=head2 tzrzf

=for sig

  Signature: ([io]A(m,n); [o]tau(k); int [o]info())

=for ref

Reduces the M-by-N ( M <= N ) real upper trapezoidal matrix A
to upper triangular form by means of orthogonal transformations.

The upper trapezoidal matrix A is factored as

	A = ( R  0 ) * Z,

	where Z is an N-by-N orthogonal matrix and R is an M-by-M upper
	triangular matrix.

The factorization is obtained by Householder's method.  The kth
transformation matrix, Z( k ), which is used to introduce zeros into
the ( m - k + 1 )th row of A, is given in the form

       Z( k ) = ( I     0   ),
                ( 0  T( k ) )

    where

       T( k ) = I - tau*u( k )*u( k )',   u( k ) = (   1    ),
                                                    (   0    )
                                                    ( z( k ) )

tau is a scalar and z( k ) is an ( n - m ) element vector.
tau and z( k ) are chosen to annihilate the elements of the kth row
of X.

The scalar tau is returned in the kth element of C<tau> and the vector
u( k ) in the kth row of A, such that the elements of z( k ) are
in  a( k, m + 1 ), ..., a( k, n ). The elements of R are returned in
the upper triangular part of A.

Z is given by

       Z =  Z( 1 ) * Z( 2 ) * ... * Z( m ).

    Arguments
    =========

    A:      On entry, the leading M-by-N upper trapezoidal part of the
            array A must contain the matrix to be factorized.
            On exit, the leading M-by-M upper triangular part of A
            contains the upper triangular matrix R, and elements M+1 to
            N of the first M rows of A, with the array tau, represent the
            orthogonal matrix Z as a product of M elementary reflectors.

    tau:    The scalar factors of the elementary reflectors.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value

=for example

 $a = random (float, 50, 100);
 $info = null;
 $tau = zeroes(float, 50);
 tzrzf($a, $tau, $info);

=for bad

tzrzf ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*tzrzf = \&PDL::tzrzf;






=head2 ormrz

=for sig

  Signature: (A(k,p); int side(); int trans(); tau(k); [io]C(m,n);int [o]info())

=for ref

Overwrites the general real M-by-N matrix C with

                    side = 0     side = 1
    trans = 0:      Q * C          C * Q
    trans = 1:      Q' * C       C * Q'

    where Q is a real orthogonal matrix defined as the product of k
    elementary reflectors

          Q = H(1) H(2) . . . H(k)

    as returned by tzrzf.

Q is of order M if C<side> = 0 and of order N
if C<side> = 1.

    Arguments
    =========

    side:   = 0: apply Q or Q' from the Left;
            = 1: apply Q or Q' from the Right.

    trans:  = 0:  No transpose, apply Q;
            = 1:  Transpose, apply Q'.

    A:      The i-th row must contain the vector which defines the
            elementary reflector H(i), for i = 1,2,...,k, as returned by
            tzrzf in the last k rows of its array argument A.
            A is modified by the routine but restored on exit.

    tau:    tau(i) must contain the scalar factor of the elementary
            reflector H(i), as returned by tzrzf.

    C:      On entry, the M-by-N matrix C.
            On exit, C is overwritten by Q*C or Q'*C or C*Q' or C*Q.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value

=for example

 $a = random (float, 50, 100);
 $a = transpose($a);
 $info = null;
 $tau = zeroes(float, 50);
 tzrzf($a, $tau, $info);
 $c = random(70,50);
 # $c will contain the result
 $c->reshape(70,100);
 $c = transpose($c);
 ormrz($a, $tau, $c, $info);

=for bad

ormrz ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*ormrz = \&PDL::ormrz;






=head2 gehrd

=for sig

  Signature: ([io]A(n,n); int ilo();int ihi();[o]tau(k); int [o]info())

=for ref

Reduces a real general matrix A to upper Hessenberg form H by
an orthogonal similarity transformation:  Q' * A * Q = H .

Further Details
===============

The matrix Q is represented as a product of (ihi-ilo) elementary
reflectors

	Q = H(ilo) H(ilo+1) . . . H(ihi-1).

Each H(i) has the form

	H(i) = I - tau * v * v'
	where tau is a real scalar, and v is a real vector with
	v(1:i) = 0, v(i+1) = 1 and v(ihi+1:n) = 0; v(i+2:ihi) is stored on
	exit in A(i+2:ihi,i), and tau in tau(i).

The contents of A are illustrated by the following example, with
n = 7, ilo = 2 and ihi = 6:

	on entry,                        on exit,

	( a   a   a   a   a   a   a )    (  a   a   h   h   h   h   a )
	(     a   a   a   a   a   a )    (      a   h   h   h   h   a )
	(     a   a   a   a   a   a )    (      h   h   h   h   h   h )
	(     a   a   a   a   a   a )    (      v2  h   h   h   h   h )
	(     a   a   a   a   a   a )    (      v2  v3  h   h   h   h )
	(     a   a   a   a   a   a )    (      v2  v3  v4  h   h   h )
	(                         a )    (                          a )

	where a denotes an element of the original matrix A, h denotes a
	modified element of the upper Hessenberg matrix H, and vi denotes an
	element of the vector defining H(i).

    Arguments
    =========

    ilo:
    ihi:    It is assumed that A is already upper triangular in rows
            and columns 1:ilo-1 and ihi+1:N. ilo and ihi are normally
            set by a previous call to gebal; otherwise they should be
            set to 1 and N respectively. See Further Details.
            1 <= ilo <= ihi <= N, if N > 0; ilo=1 and ihi=0, if N=0.

    A:      On entry, the N-by-N general matrix to be reduced.
            On exit, the upper triangle and the first subdiagonal of A
            are overwritten with the upper Hessenberg matrix H, and the
            elements below the first subdiagonal, with the array tau,
            represent the orthogonal matrix Q as a product of elementary
            reflectors. See Further Details.

    tau:    The scalar factors of the elementary reflectors (see Further
            Details). Elements 1:ilo-1 and ihi:N-1 of tau are set to
            zero. (dimension (N-1))

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value.

=for example

 $a = random (50, 50);
 $info = null;
 $tau = zeroes(50);
 gehrd($a, 1, 50, $tau, $info);

=for bad

gehrd ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*gehrd = \&PDL::gehrd;






=head2 orghr

=for sig

  Signature: ([io]A(n,n); int ilo();int ihi();tau(k); int [o]info())

=for ref

Generates a real orthogonal matrix Q which is defined as the
product of ihi-ilo elementary reflectors of order N, as returned by
C<gehrd>:

	Q = H(ilo) H(ilo+1) . . . H(ihi-1).

    Arguments
    =========

    ilo:
    ihi:   ilo and ihi must have the same values as in the previous call
            of gehrd. Q is equal to the unit matrix except in the
            submatrix Q(ilo+1:ihi,ilo+1:ihi).
            1 <= ilo <= ihi <= N, if N > 0; ilo=1 and ihi=0, if N=0.

    A:      On entry, the vectors which define the elementary reflectors,
            as returned by gehrd.
            On exit, the N-by-N orthogonal matrix Q.

    tau:    tau(i) must contain the scalar factor of the elementary
            reflector H(i), as returned by gehrd.(dimension (N-1))

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value

=for example

 $a = random (50, 50);
 $info = null;
 $tau = zeroes(50);
 gehrd($a, 1, 50, $tau, $info);
 orghr($a, 1, 50, $tau, $info);

=for bad

orghr ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*orghr = \&PDL::orghr;






=head2 hseqr

=for sig

  Signature: ([io]H(n,n); int job();int compz();int ilo();int ihi();[o]wr(n); [o]wi(n);[o]Z(m,m); int [o]info())

=for ref

Computes the eigenvalues of a real upper Hessenberg matrix H
and, optionally, the matrices T and Z from the Schur decomposition
H = Z T Z**T, where T is an upper quasi-triangular matrix (the Schur
form), and Z is the orthogonal matrix of Schur vectors.

Optionally Z may be postmultiplied into an input orthogonal matrix Q,
so that this routine can give the Schur factorization of a matrix A
which has been reduced to the Hessenberg form H by the orthogonal
matrix Q:  A = Q*H*Q**T = (QZ)*T*(QZ)**T.

    Arguments
    =========

    job:    = 0:  compute eigenvalues only;
            = 1:  compute eigenvalues and the Schur form T.

    compz:  = 0:  no Schur vectors are computed;
            = 1:  Z is initialized to the unit matrix and the matrix Z
                    of Schur vectors of H is returned;
            = 2:  Z must contain an orthogonal matrix Q on entry, and
                    the product Q*Z is returned.

    ilo:
    ihi:    It is assumed that H is already upper triangular in rows
            and columns 1:ilo-1 and ihi+1:N. ilo and ihi are normally
            set by a previous call to gebal, and then passed to gehrd
            when the matrix output by gebal is reduced to Hessenberg
            form. Otherwise ilo and ihi should be set to 1 and N
            respectively.
            1 <= ilo <= ihi <= N, if N > 0; ilo=1 and ihi=0, if N=0.

    H:      On entry, the upper Hessenberg matrix H.
            On exit, if job = 1, H contains the upper quasi-triangular
            matrix T from the Schur decomposition (the Schur form);
            2-by-2 diagonal blocks (corresponding to complex conjugate
            pairs of eigenvalues) are returned in standard form, with
            H(i,i) = H(i+1,i+1) and H(i+1,i)*H(i,i+1) < 0. If job = 0,
            the contents of H are unspecified on exit.

    wr:
    wi:     The real and imaginary parts, respectively, of the computed
            eigenvalues. If two eigenvalues are computed as a complex
            conjugate pair, they are stored in consecutive elements of
            wr and wi, say the i-th and (i+1)th, with wi(i) > 0 and
            wi(i+1) < 0. If job = 1, the eigenvalues are stored in the
            same order as on the diagonal of the Schur form returned in
            H, with wr(i) = H(i,i) and, if H(i:i+1,i:i+1) is a 2-by-2
            diagonal block, wi(i) = sqrt(H(i+1,i)*H(i,i+1)) and
            wi(i+1) = -wi(i).

    Z:      If compz = 0: Z is not referenced.
            If compz = 1: on entry, Z need not be set, and on exit, Z
            contains the orthogonal matrix Z of the Schur vectors of H.
            If compz = 2: on entry Z must contain an N-by-N matrix Q,
            which is assumed to be equal to the unit matrix except for
            the submatrix Z(ilo:ihi,ilo:ihi); on exit Z contains Q*Z.
            Normally Q is the orthogonal matrix generated by orghr after
            the call to gehrd which formed the Hessenberg matrix H.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value
            > 0:  if info = i, hseqr failed to compute all of the
                  eigenvalues in a total of 30*(ihi-ilo+1) iterations;
                  elements 1:ilo-1 and i+1:n of wr and wi contain those
                  eigenvalues which have been successfully computed.

=for example

 $a = random (50, 50);
 $info = null;
 $tau = zeroes(50);
 $z= zeroes(1,1);
 gehrd($a, 1, 50, $tau, $info);
 hseqr($a,0,0,1,50,($wr=null),($wi=null),$z,$info);

=for bad

hseqr ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*hseqr = \&PDL::hseqr;






=head2 trevc

=for sig

  Signature: (T(n,n); int side();int howmny();int select(q);[o]VL(m,m); [o]VR(p,p);int [o]m(); int [o]info(); [t]work(workn=CALC(3*$SIZE(n))))

=for ref

Computes some or all of the right and/or left eigenvectors of
a real upper quasi-triangular matrix T.

The right eigenvector x and the left eigenvector y of T corresponding
to an eigenvalue w are defined by:

	T*x = w*x,     y'*T = w*y'
	where y' denotes the conjugate transpose of the vector y.

If all eigenvectors are requested, the routine may either return the
matrices X and/or Y of right or left eigenvectors of T, or the
products Q*X and/or Q*Y, where Q is an input orthogonal
matrix. If T was obtained from the real-Schur factorization of an
original matrix A = Q*T*Q', then Q*X and Q*Y are the matrices of
right or left eigenvectors of A.

T must be in Schur canonical form (as returned by hseqr), that is,
block upper triangular with 1-by-1 and 2-by-2 diagonal blocks; each
2-by-2 diagonal block has its diagonal elements equal and its
off-diagonal elements of opposite sign.  Corresponding to each 2-by-2
diagonal block is a complex conjugate pair of eigenvalues and
eigenvectors; only one eigenvector of the pair is computed, namely
the one corresponding to the eigenvalue with positive imaginary part.

Further Details
===============

The algorithm used in this program is basically backward (forward)
substitution, with scaling to make the the code robust against
possible overflow.

Each eigenvector is normalized so that the element of largest
magnitude has magnitude 1; here the magnitude of a complex number
(x,y) is taken to be |x| + |y|.

    Arguments
    =========

    side:   = 0 :  compute both right and left eigenvectors;
	    = 1 :  compute right eigenvectors only;
            = 2 :  compute left eigenvectors only.

    howmny: = 0:  compute all right and/or left eigenvectors;
            = 1:  compute all right and/or left eigenvectors,
                    and backtransform them using the input matrices
                    supplied in VR and/or VL;
            = 2:  compute selected right and/or left eigenvectors,
                    specified by the logical array select.

    select: If howmny = 2, select specifies the eigenvectors to be
            computed.
            If howmny = 0 or 1, select is not referenced.
            To select the real eigenvector corresponding to a real
            eigenvalue w(j), select(j) must be set to TRUE.  To select
            the complex eigenvector corresponding to a complex conjugate
            pair w(j) and w(j+1), either select(j) or select(j+1) must be
            set to TRUE; then on exit select(j) is TRUE and
            select(j+1) is FALSE.

    T:      The upper quasi-triangular matrix T in Schur canonical form.

    VL:     On entry, if side = 2 or 0 and howmny = 1, VL must
            contain an N-by-N matrix Q (usually the orthogonal matrix Q
            of Schur vectors returned by hseqr).
            On exit, if side = 2 or 0, VL contains:
            if howmny = 0, the matrix Y of left eigenvectors of T;
                             VL has the same quasi-lower triangular form
                             as T'. If T(i,i) is a real eigenvalue, then
                             the i-th column VL(i) of VL  is its
                             corresponding eigenvector. If T(i:i+1,i:i+1)
                             is a 2-by-2 block whose eigenvalues are
                             complex-conjugate eigenvalues of T, then
                             VL(i)+sqrt(-1)*VL(i+1) is the complex
                             eigenvector corresponding to the eigenvalue
                             with positive real part.
            if howmny = 1, the matrix Q*Y;
            if howmny = 2, the left eigenvectors of T specified by
                             select, stored consecutively in the columns
                             of VL, in the same order as their
                             eigenvalues.
            A complex eigenvector corresponding to a complex eigenvalue
            is stored in two consecutive columns, the first holding the
            real part, and the second the imaginary part.
            If side = 1, VL is not referenced.

    VR:     On entry, if side = 1 or 0 and howmny = 1, VR must
            contain an N-by-N matrix Q (usually the orthogonal matrix Q
            of Schur vectors returned by hseqr).
            On exit, if side = 1 or 0, VR contains:
            if howmny = 0, the matrix X of right eigenvectors of T;
                             VR has the same quasi-upper triangular form
                             as T. If T(i,i) is a real eigenvalue, then
                             the i-th column VR(i) of VR  is its
                             corresponding eigenvector. If T(i:i+1,i:i+1)
                             is a 2-by-2 block whose eigenvalues are
                             complex-conjugate eigenvalues of T, then
                             VR(i)+sqrt(-1)*VR(i+1) is the complex
                             eigenvector corresponding to the eigenvalue
                             with positive real part.
            if howmny = 1, the matrix Q*X;
            if howmny = 2, the right eigenvectors of T specified by
                             select, stored consecutively in the columns
                             of VR, in the same order as their
                             eigenvalues.
            A complex eigenvector corresponding to a complex eigenvalue
            is stored in two consecutive columns, the first holding the
            real part and the second the imaginary part.
            If side = 2, VR is not referenced.

    m:      The number of columns in the arrays VL and/or VR actually
            used to store the eigenvectors.
            If howmny = 0 or 1, m is set to N.
            Each selected real eigenvector occupies one column and each
            selected complex eigenvector occupies two columns.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value

=for example

 $a = random (50, 50);
 $info = null;
 $tau = zeroes(50);
 $z= zeroes(1,1);
 gehrd($a, 1, 50, $tau, $info);
 hseqr($a,0,0,1,50,($wr=null),($wi=null),$z,$info);

=for bad

trevc ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*trevc = \&PDL::trevc;






=head2 tgevc

=for sig

  Signature: (A(n,n); int side();int howmny();B(n,n);int select(q);[o]VL(m,m); [o]VR(p,p);int [o]m(); int [o]info(); [t]work(workn=CALC(6*$SIZE(n))))

=for ref

Computes some or all of the right and/or left generalized
eigenvectors of a pair of real upper triangular matrices (A,B).

The right generalized eigenvector x and the left generalized
eigenvector y of (A,B) corresponding to a generalized eigenvalue
w are defined by:

	(A - wB) * x = 0  and  y**H * (A - wB) = 0
	where y**H denotes the conjugate transpose of y.

If an eigenvalue w is determined by zero diagonal elements of both A
and B, a unit vector is returned as the corresponding eigenvector.

If all eigenvectors are requested, the routine may either return
the matrices X and/or Y of right or left eigenvectors of (A,B), or
the products Z*X and/or Q*Y, where Z and Q are input orthogonal
matrices.  If (A,B) was obtained from the generalized real-Schur
factorization of an original pair of matrices

	(A0,B0) = (Q*A*Z**H,Q*B*Z**H),

then Z*X and Q*Y are the matrices of right or left eigenvectors of
A.

A must be block upper triangular, with 1-by-1 and 2-by-2 diagonal
blocks.  Corresponding to each 2-by-2 diagonal block is a complex
conjugate pair of eigenvalues and eigenvectors; only one
eigenvector of the pair is computed, namely the one corresponding
to the eigenvalue with positive imaginary part.

    Arguments
    =========

    side:   = 0 : compute both right and left eigenvectors;
	    = 1 : compute right eigenvectors only;
            = 2 : compute left eigenvectors only.

    howmny: = 0 : compute all right and/or left eigenvectors;
            = 1 : compute all right and/or left eigenvectors, and
                   backtransform them using the input matrices supplied
                   in VR and/or VL;
            = 2 : compute selected right and/or left eigenvectors,
                   specified by the logical array select.

    select: If howmny=2, select specifies the eigenvectors to be
            computed.
            If howmny=0 or 1, select is not referenced.
            To select the real eigenvector corresponding to the real
            eigenvalue w(j), select(j) must be set to TRUE  To select
            the complex eigenvector corresponding to a complex conjugate
            pair w(j) and w(j+1), either select(j) or select(j+1) must
            be set to TRUE.

    A:      The upper quasi-triangular matrix A.

    B:      The upper triangular matrix B.  If A has a 2-by-2 diagonal
            block, then the corresponding 2-by-2 block of B must be
            diagonal with positive elements.

    VL:     On entry, if side = 2 or 0 and howmny = 1, VL must
            contain an N-by-N matrix Q (usually the orthogonal matrix Q
            of left Schur vectors returned by hgqez).
            On exit, if side = 2 or 0, VL contains:
            if howmny = 0, the matrix Y of left eigenvectors of (A,B);
            if howmny = 1, the matrix Q*Y;
            if howmny = 2, the left eigenvectors of (A,B) specified by
                        select, stored consecutively in the columns of
                        VL, in the same order as their eigenvalues.
            If side = 1, VL is not referenced.

            A complex eigenvector corresponding to a complex eigenvalue
            is stored in two consecutive columns, the first holding the
            real part, and the second the imaginary part.

    VR:     On entry, if side = 1 or 0 and howmny = 1, VR must
            contain an N-by-N matrix Q (usually the orthogonal matrix Z
            of right Schur vectors returned by hgeqz).
            On exit, if side = 1 or 0, VR contains:
            if howmny = 0, the matrix X of right eigenvectors of (A,B);
            if howmny = 1, the matrix Z*X;
            if howmny = 2, the right eigenvectors of (A,B) specified by
                        select, stored consecutively in the columns of
                        VR, in the same order as their eigenvalues.
            If side = 2, VR is not referenced.

            A complex eigenvector corresponding to a complex eigenvalue
            is stored in two consecutive columns, the first holding the
            real part and the second the imaginary part.

    M:      The number of columns in the arrays VL and/or VR actually
            used to store the eigenvectors.  If howmny = 0 or 1, M
            is set to N.  Each selected real eigenvector occupies one
            column and each selected complex eigenvector occupies two
            columns.

    info:   = 0:  successful exit.
            < 0:  if info = -i, the i-th argument had an illegal value.
            > 0:  the 2-by-2 block (info:info+1) does not have a complex
                  eigenvalue.
=for example

 $a = random (50, 50);
 $info = null;
 $tau = zeroes(50);
 $z= zeroes(1,1);
 gehrd($a, 1, 50, $tau, $info);
 hseqr($a,0,0,1,50,($wr=null),($wi=null),$z,$info);

=for bad

tgevc ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*tgevc = \&PDL::tgevc;






=head2 gebal

=for sig

  Signature: ([io]A(n,n); int job(); int [o]ilo();int [o]ihi();[o]scale(n); int [o]info())

=for ref

Balances a general real matrix A.  This involves, first,
permuting A by a similarity transformation to isolate eigenvalues
in the first 1 to ilo-1 and last ihi+1 to N elements on the
diagonal; and second, applying a diagonal similarity transformation
to rows and columns ilo to ihi to make the rows and columns as
close in norm as possible.  Both steps are optional.

Balancing may reduce the 1-norm of the matrix, and improve the
accuracy of the computed eigenvalues and/or eigenvectors.

Further Details
===============

The permutations consist of row and column interchanges which put
the matrix in the form

               ( T1   X   Y  )
       P A P = (  0   B   Z  )
               (  0   0   T2 )

       where T1 and T2 are upper triangular matrices whose eigenvalues lie
       along the diagonal.  The column indices ilo and ihi mark the starting
       and ending columns of the submatrix B. Balancing consists of applying
       a diagonal similarity transformation inv(D) * B * D to make the
       1-norms of each row of B and its corresponding column nearly equal.

The output matrix is

       ( T1     X*D          Y    )
       (  0  inv(D)*B*D  inv(D)*Z ).
       (  0      0           T2   )

Information about the permutations P and the diagonal matrix D is
returned in the vector C<scale>.

    Arguments
    =========

    job:    Specifies the operations to be performed on A:
            = 0:  none:  simply set ilo = 1, ihi = N, scale(I) = 1.0
                    for i = 1,...,N;
            = 1:  permute only;
            = 2:  scale only;
            = 3:  both permute and scale.

    A:      On entry, the input matrix A.
            On exit,  A is overwritten by the balanced matrix.
            If job = 0, A is not referenced.
            See Further Details.

    ilo:
    ihi:    ilo and ihi are set to integers such that on exit
            A(i,j) = 0 if i > j and j = 1,...,ilo-1 or I = ihi+1,...,N.
            If job = 0 or 2, ilo = 1 and ihi = N.

    scale:  Details of the permutations and scaling factors applied to
            A.  If P(j) is the index of the row and column interchanged
            with row and column j and D(j) is the scaling factor
            applied to row and column j, then
            scale(j) = P(j)    for j = 1,...,ilo-1
                     = D(j)    for j = ilo,...,ihi
                     = P(j)    for j = ihi+1,...,N.
            The order in which the interchanges are made is N to ihi+1,
            then 1 to ilo-1.

    info:   = 0:  successful exit.
            < 0:  if info = -i, the i-th argument had an illegal value.

=for example

 $a = random (50, 50);
 $scale = zeroes(50);
 $info = null;
 $ilo = null;
 $ihi = null;
 gebal($a, $ilo, $ihi, $scale, $info);

=for bad

gebal ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*gebal = \&PDL::gebal;






=head2 gebak

=for sig

  Signature: ([io]A(n,m); int job(); int side();int ilo();int ihi();scale(n); int [o]info())

=for ref

gebak forms the right or left eigenvectors of a real general matrix
by backward transformation on the computed eigenvectors of the
balanced matrix output by gebal.

    Arguments
    =========

    A:      On entry, the matrix of right or left eigenvectors to be
            transformed, as returned by hsein or trevc.
            On exit, A is overwritten by the transformed eigenvectors.

    job:    Specifies the type of backward transformation required:
            = 0 , do nothing, return immediately;
            = 1, do backward transformation for permutation only;
            = 2, do backward transformation for scaling only;
            = 3, do backward transformations for both permutation and
                   scaling.
            job must be the same as the argument job supplied to gebal.

    side:   = 0:  V contains left eigenvectors.
	    = 1:  V contains right eigenvectors;

    ilo:
    ihi:    The integers ilo and ihi determined by gebal.
            1 <= ilo <= ihi <= N, if N > 0; ilo=1 and ihi=0, if N=0.
	    Here N is the the number of rows of the matrix A.

    scale:  Details of the permutation and scaling factors, as returned
            by gebal.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value.

=for example

 $a = random (50, 50);
 $scale = zeroes(50);
 $info = null;
 $ilo = null;
 $ihi = null;
 gebal($a, $ilo, $ihi, $scale, $info);
 # Compute eigenvectors ($ev)
 gebak($ev, $ilo, $ihi, $scale, $info);

=for bad

gebak ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*gebak = \&PDL::gebak;






=head2 lange

=for sig

  Signature: (A(n,m); int norm(); [o]b(); [t]work(workn))

=for ref

Computes the value of the one norm,  or the Frobenius norm, or
the  infinity norm,  or the  element of  largest absolute value  of a
real matrix A.

    Description
    ===========

    returns the value

       lange  = ( max(abs(A(i,j))), norm = 0
                (
                ( norm1(A),         norm = 1
                (
                ( normI(A),         norm = 2
                (
                ( normF(A),         norm = 3

    where  norm1  denotes the  one norm of a matrix (maximum column sum),
    normI  denotes the  infinity norm  of a matrix  (maximum row sum) and
    normF  denotes the  Frobenius norm of a matrix (square root of sum of
    squares).  Note that  max(abs(A(i,j)))  is not a  matrix norm.

    Arguments
    =========

    norm:   Specifies the value to be returned in lange as described
            above.

    A:      The n by m matrix A.

=for example

 $a = random (float, 100, 100);
 $norm  = $a->lange(1);

=for bad

lange ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*lange = \&PDL::lange;






=head2 lansy

=for sig

  Signature: (A(n,n); int uplo(); int norm(); [o]b(); [t]work(workn))

=for ref

Computes the value of the one norm,  or the Frobenius norm, or
the  infinity norm,  or the  element of  largest absolute value  of a
real symmetric matrix A.

    Description
    ===========

    returns the value

       lansy  = ( max(abs(A(i,j))), norm = 0
                (
                ( norm1(A),         norm = 1
                (
                ( normI(A),         norm = 2
                (
                ( normF(A),         norm = 3

    where  norm1  denotes the  one norm of a matrix (maximum column sum),
    normI  denotes the  infinity norm  of a matrix  (maximum row sum) and
    normF  denotes the  Frobenius norm of a matrix (square root of sum of
    squares).  Note that  max(abs(A(i,j)))  is not a  matrix norm.

    norm:   Specifies the value to be returned in lansy as described
            above.

    uplo:   Specifies whether the upper or lower triangular part of the
            symmetric matrix A is to be referenced.
            = 0:  Upper triangular part of A is referenced
            = 1:  Lower triangular part of A is referenced

    A:      The symmetric matrix A.  If uplo = 0, the leading n by n
            upper triangular part of A contains the upper triangular part
            of the matrix A, and the strictly lower triangular part of A
            is not referenced.  If uplo = 1, the leading n by n lower
            triangular part of A contains the lower triangular part of
            the matrix A, and the strictly upper triangular part of A is
            not referenced.

=for example

 # Assume $a is symmetric
 $a = random (float, 100, 100);
 $norm  = $a->lansy(1, 1);

=for bad

lansy ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*lansy = \&PDL::lansy;






=head2 lantr

=for sig

  Signature: (A(m,n);int uplo();int norm();int diag();[o]b(); [t]work(workn))

=for ref

Computes the value of the one norm,  or the Frobenius norm, or
the  infinity norm,  or the  element of  largest absolute value  of a
trapezoidal or triangular matrix A.

    Description
    ===========

    returns the value

       lantr  = ( max(abs(A(i,j))), norm = 0
                (
                ( norm1(A),         norm = 1
                (
                ( normI(A),         norm = 2
                (
                ( normF(A),         norm = 3

    where  norm1  denotes the  one norm of a matrix (maximum column sum),
    normI  denotes the  infinity norm  of a matrix  (maximum row sum) and
    normF  denotes the  Frobenius norm of a matrix (square root of sum of
    squares).  Note that  max(abs(A(i,j)))  is not a  matrix norm.

    norm:   Specifies the value to be returned in lantr as described
            above.

    uplo:   Specifies whether the matrix A is upper or lower trapezoidal.
            = 0:  Upper triangular part of A is referenced
            = 1:  Lower triangular part of A is referenced
	    Note that A is triangular instead of trapezoidal if M = N.

    diag:   Specifies whether or not the matrix A has unit diagonal.
            = 0:  Non-unit diagonal
            = 1:  Unit diagonal

    A:      The trapezoidal matrix A (A is triangular if m = n).
            If uplo = 0, the leading m by n upper trapezoidal part of
            the array A contains the upper trapezoidal matrix, and the
            strictly lower triangular part of A is not referenced.
            If uplo = 1, the leading m by n lower trapezoidal part of
            the array A contains the lower trapezoidal matrix, and the
            strictly upper triangular part of A is not referenced.  Note
            that when diag = 1, the diagonal elements of A are not
            referenced and are assumed to be one.

=for example

 # Assume $a is upper triangular
 $a = random (float, 100, 100);
 $norm  = $a->lantr(1, 1, 0);

=for bad

lantr ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*lantr = \&PDL::lantr;






=head2 gemm

=for sig

  Signature: (A(m,n); int transa(); int transb(); B(p,q);alpha(); beta(); [io]C(r,s))

=for ref

Performs one of the matrix-matrix operations

	C := alpha*op( A )*op( B ) + beta*C,
	where  op( X ) is one of p( X ) = X   or   op( X ) = X',
	alpha and beta are scalars, and A, B and C are matrices, with op( A )
	an m by k matrix,  op( B )  a  k by n matrix and  C an m by n matrix.

    Parameters
    ==========
    transa:  On entry, transa specifies the form of op( A ) to be used in
             the matrix multiplication as follows:
                transa = 0,	op( A ) = A.
                transa = 1,	op( A ) = A'.

    transb:  On entry, transb specifies the form of op( B ) to be used in
             the matrix multiplication as follows:
                transb = 0,	op( B ) = B.
                transb = 1,	op( B ) = B'.

    alpha:   On entry, alpha specifies the scalar alpha.

    A:       Before entry with  transa = 0,  the leading  m by k
             part of the array  A  must contain the matrix  A,  otherwise
             the leading  k by m  part of the array  A  must contain  the
             matrix A.

    B:       Before entry with  transb = 0,  the leading  k by n
             part of the array  B  must contain the matrix  B,  otherwise
             the leading  n by k  part of the array  B  must contain  the
             matrix B.

    beta:    On entry,  beta  specifies the scalar  beta.  When  beta  is
             supplied as zero then C need not be set on input.

    C:       Before entry, the leading  m by n  part of the array  C must
             contain the matrix  C,  except when  beta  is zero, in which
             case C need not be set on entry.
             On exit, the array  C  is overwritten by the  m by n  matrix
             ( alpha*op( A )*op( B ) + beta*C ).

=for example

 $a = random(5,4);
 $b = random(5,4);
 $alpha = pdl(0.5);
 $beta = pdl(0);
 $c = zeroes(5,5);
 gemm($a, 0, 1,$b, $alpha, $beta, $c);

=for bad

gemm ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*gemm = \&PDL::gemm;






=head2 mmult

=for sig

  Signature: (A(m,n); B(p,m); [o]C(p,n))

=for ref

Blas matrix multiplication based on gemm

=for bad

mmult ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*mmult = \&PDL::mmult;






=head2 crossprod

=for sig

  Signature: (A(n,m); B(p,m); [o]C(p,n))

=for ref

Blas matrix cross product based on gemm

=for bad

crossprod ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*crossprod = \&PDL::crossprod;






=head2 syrk

=for sig

  Signature: (A(m,n); int uplo(); int trans(); alpha(); beta(); [io]C(p,p))

=for ref

Performs one of the symmetric rank k operations

	C := alpha*A*A' + beta*C,

or

	C := alpha*A'*A + beta*C,

	where  alpha and beta  are scalars, C is an  n by n  symmetric matrix
	and  A  is an  n by k  matrix in the first case and a  k by n  matrix
	in the second case.

    Parameters
    ==========
    uplo:    On  entry,   uplo  specifies  whether  the  upper  or  lower
             triangular  part  of the  array  C  is to be  referenced  as
             follows:
                uplo = 0 Only the  upper triangular part of  C
                         is to be referenced.
                uplo = 1 Only the  lower triangular part of  C
                         is to be referenced.
             Unchanged on exit.

    trans:   On entry,  trans  specifies the operation to be performed as
             follows:
                trans = 0	C := alpha*A*A' + beta*C.
                trans = 1	C := alpha*A'*A + beta*C.

    alpha:   On entry, alpha specifies the scalar alpha.
             Unchanged on exit.

    A:       Before entry with  trans = 0,  the  leading  n by k
             part of the array  A  must contain the matrix  A,  otherwise
             the leading  k by n  part of the array  A  must contain  the
             matrix A.

    beta:    On entry, beta specifies the scalar beta.

    C:       Before entry  with  uplo = 0,  the leading  n by n
             upper triangular part of the array C must contain the upper
             triangular part  of the  symmetric matrix  and the strictly
             lower triangular part of C is not referenced.  On exit, the
             upper triangular part of the array  C is overwritten by the
             upper triangular part of the updated matrix.
             Before entry  with  uplo = 1,  the leading  n by n
             lower triangular part of the array C must contain the lower
             triangular part  of the  symmetric matrix  and the strictly
             upper triangular part of C is not referenced.  On exit, the
             lower triangular part of the array  C is overwritten by the
             lower triangular part of the updated matrix.

=for example

 $a = random(5,4);
 $b = zeroes(5,5);
 $alpha = 1;
 $beta = 0;
 syrk ($a, 1,0,$alpha, $beta , $b);

=for bad

syrk ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*syrk = \&PDL::syrk;






=head2 dot

=for sig

  Signature: (a(n);b(n);[o]c())

=for ref

Dot product of two vectors using Blas.

=for example

 $a = random(5);
 $b = random(5);
 $c = dot($a, $b)

=for bad

dot ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*dot = \&PDL::dot;






=head2 axpy

=for sig

  Signature: (a(n); alpha();[io]b(m))

=for ref

Linear combination of vectors ax + b using Blas.
Returns result in b.

=for example

 $a = random(5);
 $b = random(5);
 axpy($a, 12, $b)

=for bad

axpy ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*axpy = \&PDL::axpy;






=head2 nrm2

=for sig

  Signature: (a(n);[o]b())

=for ref

Euclidean norm of a vector using Blas.

=for example

 $a = random(5);
 $norm2 = nrm2($a)

=for bad

nrm2 ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*nrm2 = \&PDL::nrm2;






=head2 asum

=for sig

  Signature: (a(n);[o]b())

=for ref

Sum of absolute values of a vector using Blas.

=for example

 $a = random(5);
 $absum = asum($a)

=for bad

asum ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*asum = \&PDL::asum;






=head2 scal

=for sig

  Signature: ([io]a(n);scale())

=for ref

Scale a vector by a constant using Blas.

=for example

 $a = random(5);
 $a->scal(0.5)

=for bad

scal ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*scal = \&PDL::scal;






=head2 rot

=for sig

  Signature: ([io]a(n);c(); s();[io]b(n))

=for ref

Applies plane rotation using Blas.

=for example

 $a = random(5);
 $b = random(5);
 rot($a, 0.5, 0.7, $b)

=for bad

rot ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*rot = \&PDL::rot;






=head2 rotg

=for sig

  Signature: ([io]a();[io]b();[o]c(); [o]s())

=for ref

Generates plane rotation using Blas.

=for example

 $a = sequence(4);
 rotg($a(0), $a(1),$a(2),$a(3))

=for bad

rotg ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*rotg = \&PDL::rotg;






=head2 lasrt

=for sig

  Signature: ([io]d(n); int id();int [o]info())

=for ref

Sort the numbers in d in increasing order (if id = 0) or
in decreasing order (if id = 1 ).

Use Quick Sort, reverting to Insertion sort on arrays of
size <= 20. Dimension of stack limits N to about 2**32.

    Arguments
    =========

    id:     = 0: sort d in increasing order;
            = 1: sort d in decreasing order.

    d:      On entry, the array to be sorted.
            On exit, d has been sorted into increasing order
            (d(1) <= ... <= d(N) ) or into decreasing order
            (d(1) >= ... >= d(N) ), depending on id.

    info:   = 0:  successful exit
            < 0:  if info = -i, the i-th argument had an illegal value

=for example

 $a = random(5);
 lasrt ($a, 0, ($info = null));

=for bad

lasrt ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*lasrt = \&PDL::lasrt;






=head2 lacpy

=for sig

  Signature: (A(m,n); int uplo(); [o]B(p,n))

=for ref

Copies all or part of a two-dimensional matrix A to another
matrix B.

    Arguments
    =========

    uplo:   Specifies the part of the matrix A to be copied to B.
            = 0:      Upper triangular part
            = 1:      Lower triangular part
            Otherwise:  All of the matrix A

    A:      The m by n matrix A.  If uplo = 0, only the upper triangle
            or trapezoid is accessed; if uplo = 1, only the lower
            triangle or trapezoid is accessed.

    B:      On exit, B = A in the locations specified by uplo.

=for example

 $a = random(5,5);
 $b = zeroes($a);
 lacpy ($a, 0, $b);

=for bad

lacpy ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*lacpy = \&PDL::lacpy;






=head2 laswp

=for sig

  Signature: ([io]A(m,n);int k1();int  k2(); int ipiv(p);int inc())

=for ref

Performs a series of row interchanges on the matrix A.
One row interchange is initiated for each of rows k1 through k2 of A.
Doesn't use PDL indices (start = 1).

    Arguments
    =========

    A:      On entry, the matrix of column dimension N to which the row
            interchanges will be applied.
            On exit, the permuted matrix.

    k1:     The first element of ipiv for which a row interchange will
            be done.

    k2:     The last element of ipiv for which a row interchange will
            be done.

    ipiv:   The vector of pivot indices.  Only the elements in positions
            k1 through k2 of ipiv are accessed.
            ipiv(k) = l implies rows k and l are to be interchanged.

    inc:    The increment between successive values of ipiv.  If ipiv
            is negative, the pivots are applied in reverse order.

=for example

 $a = random(5,5);
 # reverse row (col for PDL)
 $b = pdl([5,4,3,2,1]);
 $a->laswp(1,2,$b,1);

=for bad

laswp ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*laswp = \&PDL::laswp;






=head2 lamch

=for sig

  Signature: (cmach(); [o]precision())

=for ref

Determines precision machine parameters.
Works inplace.

    Arguments
    =========

    cmach:  Specifies the value to be returned by lamch:
            = 0	LAMCH := eps
            = 1 LAMCH := sfmin
            = 2 LAMCH := base
            = 3 LAMCH := eps*base
            = 4 LAMCH := t
            = 5 LAMCH := rnd
            = 6 LAMCH := emin
            = 7 LAMCH := rmin
            = 8 LAMCH := emax
            = 9 LAMCH := rmax

            where

            eps   = relative machine precision
            sfmin = safe minimum, such that 1/sfmin does not overflow
            base  = base of the machine
            prec  = eps*base
            t     = number of (base) digits in the mantissa
            rnd   = 1.0 when rounding occurs in addition, 0.0 otherwise
            emin  = minimum exponent before (gradual) underflow
            rmin  = underflow threshold - base**(emin-1)
            emax  = largest exponent before overflow
            rmax  = overflow threshold  - (base**emax)*(1-eps)

=for example

 $a = lamch (0);
 print "EPS is $a for double\n";

=for bad

lamch ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*lamch = \&PDL::lamch;






=head2 labad

=for sig

  Signature: ([io]small(); [io]large())

=for ref

Takes as input the values computed by C<lamch> for underflow and
overflow, and returns the square root of each of these values if the
log of large is sufficiently large.  This subroutine is intended to
identify machines with a large exponent range, such as the Crays, and
redefine the underflow and overflow limits to be the square roots of
the values computed by C<lamch>.  This subroutine is needed because
lamch does not compensate for poor arithmetic in the upper half of
the exponent range, as is found on a Cray.

    Arguments
    =========

    small:  On entry, the underflow threshold as computed by lamch.
            On exit, if LOG10(large) is sufficiently large, the square
            root of small, otherwise unchanged.

    large:  On entry, the overflow threshold as computed by lamch.
            On exit, if LOG10(large) is sufficiently large, the square
            root of large, otherwise unchanged.

=for example

 $underflow = lamch(7);
 $overflow = lamch(9);
 labad ($underflow, $overflow);

=for bad

labad ignores the bad-value flag of the input ndarrays.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*labad = \&PDL::labad;






=head2 cplx_eigen

=for sig

  Signature: (eigreval(n);eigimval(n); eigvec(n,p);int fortran();[o]cplx_val(c=2,n);[o]cplx_vec(c=2,n,p))

=for ref

Output complex eigen-values/vectors from eigen-values/vectors
as computed by geev or geevx.
'fortran' means fortran storage type.

=for bad

cplx_eigen does not process bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




sub PDL::cplx_eigen {
  my ($eigre, $eigim, $eigvec, $fortran, @outs) = @_;
  my ($outval, $outvec) = @outs ? @outs : (null, null);
  PDL::_cplx_eigen_int($eigre, $eigim, $eigvec, $fortran, $outval, $outvec);
  $_ = $_->slice('(0)')->czip($_->slice('(1)')) for $outval, $outvec;
  ($outval, $outvec);
}



*cplx_eigen = \&PDL::cplx_eigen;






=head2 charpol

=for sig

  Signature: (A(n,n);[o]Y(n,n);[o]out(p=CALC($SIZE(n)+1)))

=for ref

Compute adjoint matrix and characteristic polynomial.

=for bad

charpol does not process bad values.
It will set the bad-value flag of all output ndarrays if the flag is set for any of the input ndarrays.

=cut




*charpol = \&PDL::charpol;







#line 10599 "lib/PDL/LinearAlgebra/Real.pd"

=head1 AUTHOR

Copyright (C) Gr�gory Vanuxem 2005-2018.

This library is free software; you can redistribute it and/or modify
it under the terms of the Perl Artistic License as in the file Artistic_2
in this distribution.

=cut
#line 8104 "lib/PDL/LinearAlgebra/Real.pm"

# Exit with OK status

1;
