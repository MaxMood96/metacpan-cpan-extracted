use strict;
use warnings;
use PDL::Lite;
use PDL::Complex;
use PDL::Math;
use Test::More;
use Test::PDL;

# capture error in PDL::LinearAlgebra
{
my $info = bless pdl(1), 'PDL::Complex';
eval { $info ? 1 : 0 };
is $@, '', 'no error in comparison';
}

#Type of cplx and cmplx
my $x=PDL->sequence(2);
my $y=$x->cplx;
is(ref $y, 'PDL::Complex', 'type of cplx');
is(ref $x, 'PDL', "cplx doesn't modify original pdl");
my $z=$y->real;
is(ref $z, 'PDL', 'real returns type to pdl');
is(ref $y, 'PDL::Complex', "real doesn't change type of parent");
#Should there be a real subroutine, such as complex, that does change
#the parent?
$y=$x->complex;
is(ref $y, 'PDL::Complex', 'type of complex');
is(ref $x, 'PDL::Complex', 'complex does modify original pdl');
ok !$x->badflag, 'PDL::Complex badflag works';

eval { my $string = PDL::Complex->null.'' };
is $@, '', 'can stringify complex null';

#Check r2C
is(ref r2C(1), 'PDL::Complex', 'type of r2C');
is(r2C(1)->re, 1, 'real part of r2C');
is(r2C(1)->im, 0, 'imaginary part of r2C');

#Check i2C
is(ref i2C(1), 'PDL::Complex', 'type of i2C');
is(i2C(1)->re, 0, 'real part of i2C');
is(i2C(1)->im, 1, 'imaginary part of i2C');

#Test mixed complex-real operations

my $ref = pdl(-1,1);
$x = i - 1;

is(ref $x, 'PDL::Complex', 'type promotion i - real scalar');
is_pdl $x->real,$ref, 'value from i - real scalar';

$x = 1 - i();
is(ref $x, 'PDL::Complex', 'type promotion real scalar - i');
is_pdl $x->real,-$ref, 'value from real scalar - i';

my $native = pdl('[1+2i 3+4i]');
is $native.'', '[1+2i 3+4i]', 'immediate check of native and stringification'
  or diag PDL::Core::pdump($native), "_ci:", PDL::Core::pdump(PDL::_ci);
my $fromn = eval { PDL::Complex->from_native($native) };
$ref = pdl([1, 2], [3, 4]);
is_pdl $fromn->real,$ref, 'from_native works'
  or diag "native:", PDL::Core::pdump($native),
  "fromn:", PDL::Core::pdump($fromn);
is $fromn->as_native.'', $native.'', 'as_native'
  or diag "fromn:", PDL::Core::pdump($fromn), "native:", PDL::Core::pdump($native);
is $fromn->as_native->type, 'cdouble', 'as_native right type';

$ref = pdl([[-2,1],[-3,1]]);
$x = i() - pdl(2,3);

is(ref $x, 'PDL::Complex', 'type promotion i - real ndarray');
is_pdl $x->real,$ref, 'value from i - real ndarray';

$x = pdl(2,3) - i;
is(ref $x, 'PDL::Complex', 'type promotion real ndarray - i');
is_pdl $x->real,-$ref, 'value from real ndarray - i';

# dataflow from complex to real
my $ar = $x->real;
$ar++;
is_pdl $x->real, -$ref+1, 'complex to real dataflow';

# dataflow from real to complex when using cplx

my $refc=$ref->copy;
my $ac = $refc->cplx;
$ac .= $ac - 1 - i;
is_pdl $refc, $ref-1, 'real to complex dataflow';

# no dataflow from real to complex when complex

$refc=$ref->copy;
$ac = $refc->complex;
$ac .= $ac - 1 - i;
is_pdl $refc->real, $ref-1, 'real to complex dataflow';

#Check Cr2p and Cp2r
is_pdl Cr2p(pdl(1,1)), pdl(sqrt(2),atan2(1,1)), 'rectangular to polar';
is_pdl Cp2r(pdl(sqrt(2),atan2(1,1))), pdl(1,1), 'polar to rectangular';

# Check that converting from re/im to mag/ang and
#  back we get the same thing
$x = cplx($ref);
$y = $x->Cr2p()->Cp2r();
is_pdl $x, $y, 'check re/im and mag/ang equivalence';

# Test Cadd, Csub, Cmul, Cscale, Cdiv
$x=1+2*i;
$y=3+4*i;
$a=3;
my $pa=pdl(3);
is(ref Cadd($x,$y), 'PDL::Complex', 'Type of Cadd');
is_pdl Cadd($x,$y)->real, $x->real+$y->real, 'Value of Cadd';
is(ref Csub($x,$y), 'PDL::Complex', 'Type of Csub');
is_pdl Csub($x,$y)->real, $x->real-$y->real, 'Value of Csub';
is(ref Cscale($x,$a), 'PDL::Complex', 'Type of Cscale with scalar');
is_pdl Cscale($x,$a)->real, $x->real*$a, 'Value of Cscale with scalar';
is(ref Cscale($x,$pa), 'PDL::Complex', 'Type of Cscale with pdl');
is_pdl Cscale($x,$pa)->real, $x->real*$pa, 'Value of Cscale with pdl';

is_pdl $x->Cconj->im, pdl(-2), 'Cconj works';
is_pdl $x->conj->im, pdl(-2), 'conj works';

$x = cplx($ref);
my $cabs = sqrt($x->re**2+$x->im**2);

is(ref Cabs $x, 'PDL', 'Cabs type');
is(ref Cabs2 $x, 'PDL', 'Cabs2 type');
is(ref Carg $x, 'PDL', 'Carg type');
is_pdl $cabs, Cabs($x), 'Cabs value';
is_pdl $cabs**2, Cabs2($x), 'Cabs2 value';
is_pdl atan2($x->im, $x->re), Carg($x), 'Carg value';

#Csin, Ccos, Ctan

is(ref Csin(i), 'PDL::Complex', 'Csin type');
is_pdl Csin($x->re->r2C)->re, sin($x->re), 'Csin of reals';
is_pdl Csin(i()*$x->im)->im, sinh($x->im), 'Csin of imags';
is(ref Ccos(i), 'PDL::Complex', 'Ccos type');
is_pdl Ccos($x->re->r2C)->re, cos($x->re), 'Ccos of reals';
is_pdl Ccos(i()*$x->im)->re, cosh($x->im), 'Ccos of imags';
is(ref Ctan(i), 'PDL::Complex', 'Ctan type');
is_pdl Ctan($x->re->r2C)->re, tan($x->re), 'Ctan of reals';
is_pdl Ctan(i()*$x->im)->im, tanh($x->im), 'Ctan of imags';

#Cexp, Clog, Cpow
is(ref Cexp(i), 'PDL::Complex', 'Cexp type');
is_pdl Cexp($x->re->r2C)->re, exp($x->re), 'Cexp of reals';
is_pdl Cexp(i()*$x->im->r2C)->real, pdl(cos($x->im), sin($x->im))->mv(1,0),
	   'Cexp of imags ';
is(ref Clog(i), 'PDL::Complex', 'Clog type');
is_pdl Clog($x)->real,
	   pdl(log($x->Cabs), atan2($x->im, $x->re))->mv(1,0),
   'Clog of reals';
is(ref Cpow($x, r2C(2)), 'PDL::Complex', 'Cpow type');
is_pdl Cpow($x,r2C(2))->real,
	   pdl($x->re**2-$x->im**2, 2*$x->re*$x->im)->mv(1,0),
   'Cpow value';

#Csqrt
is(ref Csqrt($x), 'PDL::Complex', 'Csqrt type');
is_pdl +(Csqrt($x)*Csqrt($x))->real, $x->real, 'Csqrt value';

is_pdl Cpow(i,2)->real, pdl(-1,0), 'scalar power of i';
is_pdl Cpow(i,pdl(2))->real, pdl(-1,0), 'real pdl power of i';

#Casin, Cacos, Catan
is(ref Casin($x), 'PDL::Complex', 'Casin type');
is_pdl Csin(Casin($x))->real, $x->real, 'Casin value';
is(ref Cacos($x), 'PDL::Complex', 'Cacos type');
is_pdl Ccos(Cacos($x))->real, $x->real, 'Cacos value';
is(ref Catan($x), 'PDL::Complex', 'Catan type');
is_pdl Ctan(Catan($x))->real, $x->real, 'Catan value';

#Csinh, Ccosh, Ctanh
is(ref Csinh($x), 'PDL::Complex', 'Csinh type');
is_pdl Csinh($x)->real, (i()*Csin($x/i()))->real, 'Csinh value';
is(ref Ccosh($x), 'PDL::Complex', 'Ccosh type');
is_pdl Ccosh($x)->real, (Ccos($x/i()))->real, 'Ccosh value';
is(ref Ctanh($x), 'PDL::Complex', 'Ctanh type');
is_pdl Ctanh($x)->real, (i()*Ctan($x/i()))->real, 'Ctanh value';

#Casinh, Cacosh, Catanh
is(ref Casinh($x), 'PDL::Complex', 'Casinh type');
is_pdl Csinh(Casinh($x))->real, $x->real, 'Casinh value';
is(ref Cacosh($x), 'PDL::Complex', 'Cacosh type');
is_pdl Ccosh(Cacosh($x))->real, $x->real, 'Cacosh value';
is(ref Catanh($x), 'PDL::Complex', 'Catanh type');
is_pdl Ctanh(Catanh($x))->real, $x->real, 'Catanh value';

# Croots
is(ref +(my $croots = Croots($x, 5)), 'PDL::Complex', 'Croots type');
is_pdl Cpow($croots, r2C(5))->real, $x->real->slice(':,*5'),
   'Croots value';
is_pdl $croots->sumover, r2C(pdl [0,0]),
   'Croots center of mass';

#Check real and imaginary parts
is((2+3*i())->re, 2, 'Real part');
is((2+3*i())->im, 3, 'Imaginary part');

#rCpolynomial
is(ref rCpolynomial(pdl(1,2,3), $x), 'PDL::Complex',
	'rCpolynomial type');
is_pdl rCpolynomial(pdl(1,2,3), $x)->real,
	   (1+2*$x+3*$x**2)->real, 'rCpolynomial value';

# Check cat'ing of PDL::Complex
$y = $x->copy + 1;
my $bigArray = $x->cat($y);
ok(abs($bigArray->sumover->sumover +  8 - 4*i()) < .0001, 'check cat for PDL::Complex');
ok(abs($bigArray->sum() +  8 - 4*i()) < .0001, 'check cat for PDL::Complex');

$z = pdl(0) + i()*pdl(0);
$z **= 2;

ok($z->at(0) == 0 && $z->at(1) == 0, 'check that 0 +0i exponentiates correctly'); # Wasn't always so.

my $zz = $z ** 0;

#Are these results really correct? WLM

ok($zz->at(0) == 1 && $zz->at(1) == 0, 'check that 0+0i ** 0 is 1+0i');

$z **= $z;

ok($z->at(0) == 1 && $z->at(1) == 0, 'check that 0+0i ** 0+0i is 1+0i');

my $r = pdl(-10) + i()*pdl(0);
$r **= 2;
ok($r->at(0) < 100.000000001 && $r->at(0) > 99.999999999 && $r->at(1) == 0,
  'check that imaginary part is exactly zero') or diag "got:$r";

$r = PDL->sequence(2,2,3)->complex;
my $slice = $r->slice('(0),:,(0)');
$slice .= 44;
like $r->slice(':,(1),(0)'), qr/44.*3/ or diag "got:", $r->slice(':,(1),(0)');

$r = r2C(-10);
$r .= 2;
ok(PDL::approx($r->at(0), 2) && PDL::approx($r->at(1), 0),
  'check broadcasting does not make assigning a real value affect imag part') or diag "got:$r";

$r = r2C(2);
$r++;
ok(PDL::approx($r->at(0), 3) && PDL::approx($r->at(1), 0), '++ not imag') or diag "got:$r";

$r = r2C(3);
$r--;
ok(PDL::approx($r->at(0), 2) && PDL::approx($r->at(1), 0), '-- not imag') or diag "got:$r";

#Check Csumover sumover, Cprodover and prodover
$x=PDL->sequence(2,3)+1;
$y=$x->copy->complex;
is(ref $y->Csumover, 'PDL::Complex', 'Type of Csumover');
is($y->Csumover->dim(0), 2, 'Dimension 0 of Csumover');
is_pdl $y->Csumover->real, $x->mv(1,0)->sumover,
   'Csumover value';
is(ref $y->sumover, 'PDL::Complex', 'Type of sumover');
is($y->sumover->dim(0), 2, 'Dimension 0 of sumover');
is_pdl $y->sumover->real, $x->mv(1,0)->sumover, 'sumover value';
is(ref PDL::sumover($y), 'PDL::Complex', 'Type of sumover');

is(ref $y->Cprodover, 'PDL::Complex', 'Type of Cprodover');
is($y->Cprodover->dim(0), 2, 'Dimension 0 of Cprodover');
my @els = map $y->slice(":,($_)"), 0..2;
is_pdl $y->Cprodover->real,
	   ($els[0]*$els[1]*$els[2])->real,
	  'Value of Cprodover';
is(ref $y->prodover, 'PDL::Complex', 'Type of prodover');
     is($y->prodover->dim(0), 2, 'Dimension 0 of prodover');
is_pdl $y->prodover->real,
	   ($els[0]*$els[1]*$els[2])->real,
   'Value of prodover';

#Check sum
$x=PDL->sequence(2,3)+1;
$y=$x->copy->complex;
is(ref $y->sum, 'PDL::Complex', 'Type of sum');
is($y->sum->dims, 1, 'Dimensions of sum');
is($y->sum->dim(0), 2, 'Dimension 0 of sum');
is_pdl $y->sum->real, $x->mv(1,0)->sumover, 'Value of sum';

#Check prod
$x=PDL->sequence(2,3)+1;
$y=$x->copy->complex;
is(ref $y->prod, 'PDL::Complex', 'Type of prod');
is($y->prod->dims, 1, 'Dimensions of prod');
is($y->prod->dim(0), 2, 'Dimension 0 of prod');
is_pdl $y->prod->real, $y->prodover->real,
   'Value of prod';

{
# Check stringification of complex ndarray
my $c =  9.1234 + 4.1234*i();
my $dummy = $c->dummy(2,1);
like $dummy.'', qr/9.123\S*4.123/, 'sf.net bug #1176614'
  or diag "c:", PDL::Core::pdump($c), "dummy:", PDL::Core::pdump($dummy);
$c = PDL->sequence(2, 3, 4)->complex;
unlike $c.'', qr/\s\+/, 'stringified no space before +';
}

TODO: {
      local $TODO="Autoincrement creates new copy, so doesn't flow";
      # autoincrement flow
      $x=i;
      $y=$x;
      $y++;
      is_pdl $x->real, $y->real, 'autoincrement flow';
      diag("$x should have equaled $y");
}

TODO: {
      local $TODO="Computed assignment creates new copy, so doesn't flow";
      # autoincrement flow
      $x=i;
      $y=$x;
      $y+=1;
      is_pdl $x->real, $y->real, 'computed assignment flow';
      diag("$x should have equaled $y");
}
TODO: {
      local $TODO="Computed assignment doesn't modify slices";
      # autoincrement flow
      $x=PDL->sequence(2,3)->complex;
      $y=$x->copy;
      $x+=$x;
      $y->slice('')+=$y;
      is_pdl $x->real, $y->real, 'computed assignment to slice';
      diag("$x should have equaled $y");
}

$x=3+4*i;$y=4+2*i; my $c=1+1*i;
ok(Cmul($x,$y) == 4+22*i,"Cmul");
ok($x*$y == 4+22*i,"overloaded *");
ok(Cdiv($x,$y) == 1 + 0.5*i,"Cdiv");
ok($x/$y == 1+0.5*i,"overloaded /");
is_pdl Cabs(atan2(pdl(1)->r2C,pdl(0)->r2C)),PDL::Math::asin(1.0),"atan2";

TODO: {
      local $TODO="Transpose of complex data should leave 0-th dimension alone";
      $x=PDL->sequence(2,3,4)->complex;
      $y=$x->transpose;
      is($y->dim(0),2, "Keep dimension 0 when transposing");
}
TODO: {
      local $TODO="complex numbers should not be so after moving dimension 0";

      $x=PDL->sequence(2,2)->complex;
      $y=$x->mv(0,1);
      is(ref $y, 'PDL', 'PDL::Complex becomes real PDL after moving dim 0');
}

#test overloaded operators
{
    my $less = 3-4*i;
    my $equal = -1*(-3+4*i);
    my $more = 3+2*i;
    my $zero_imag = r2C(4);
    eval { my $bool = $less<$more }; ok $@, 'exception on invalid operator';
    eval { my $bool = $less<=$equal }; ok $@, 'exception on invalid operator';
    ok($less==$equal,'equal to');
    ok(!($less!=$equal),'not equal to');
    eval { my $bool = $more>$equal }; ok $@, 'exception on invalid operator';
    eval { my $bool = $more>=$equal }; ok $@, 'exception on invalid operator';
    ok($zero_imag==4,'equal to real');
    ok($zero_imag!=5,'neq real');
}

{
my $aa = PDL->sequence(2,3,3)->cplx;
my $up = pdl('[[0 1; 2 3; 4 5] [0 0; 8 9; 10 11] [0 0; 0 0; 16 17]]')->cplx;
my $lo = pdl('[[0 1; 0 0; 0 0] [6 7; 8 9; 0 0] [12 13; 14 15; 16 17]]')->cplx;
is_pdl $aa->tricpy(0), $up;
is_pdl $aa->tricpy, $up;
is_pdl $aa->tricpy(1), $lo;
is_pdl $aa->mstack($up), pdl('[[0 1; 2 3; 4 5] [6 7; 8 9; 10 11] [12 13; 14 15; 16 17] [0 1; 2 3; 4 5] [0 0; 8 9; 10 11] [0 0; 0 0; 16 17]]')->cplx;
my $got;
is_pdl $got = PDL->sequence(2,2,3)->cplx->augment(PDL->sequence(2,3,3)->cplx+10), PDL::Complex->from_native(pdl('[i 2+3i 10+i 12+3i 14+5i; 4+5i 6+7i 16+7i 18+9i 20+11i; 8+9i 10+11i 22+13i 24+15i 26+17i]'));
my $B = PDL::Complex->from_native(pdl('[i 2+4i 3+5i; 0 3i 7+9i]'));
is_pdl $got = $B->t, PDL::Complex->from_native(pdl('[i 0; 2+4i 3i; 3+5i 7+9i]'));
is_pdl $got = $B->t(1), PDL::Complex->from_native(pdl('[-i 0; 2-4i -3i; 3-5i 7-9i]'));
is_pdl $got = PDL::Complex->from_native(PDL->sequence(3)->r2C)->t, PDL::Complex->from_native(pdl('[0; 1; 2]')->r2C);
is_deeply $got = [PDL::Complex->from_native(pdl(3)->r2C)->t->dims], [2,1,1] or diag "got: ", explain $got;
}

done_testing;
