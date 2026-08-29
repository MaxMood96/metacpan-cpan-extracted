use strict;
use warnings;
use Test::More;
use Physics::CPD::Stellarator;

my $w = Physics::CPD::Stellarator->new;
my $PI = 3.14159265358979;

# boundary_point at u=v=0, scale=1 is the sum of the R cosine coefficients
my ( $R0, $Z0 ) = $w->boundary_point( 0, 0, 1 );
my $sumR = 0;
$sumR += $_->[2] for @{ $w->boundary_coeffs };
is_deeply( [ sprintf('%.6f',$R0), sprintf('%.6f',$Z0) ],
           [ sprintf('%.6f',$sumR), sprintf('%.6f',0) ],
           'boundary_point(0,0,1) = (sum Rbc, 0)' );

# scale = 0 collapses to the magnetic axis (only m=0 modes survive)
my ( $Ra, $Za ) = $w->boundary_point( 0, 0, 0 );
approx_ok( $Ra, 5.5 - 0.28, 'axis R at v=0 uses only m=0 modes' );
approx_ok( $Za, 0,          'axis Z at v=0 is zero' );

# magnetic axis geometry
my ( $ax, $ay, $az ) = $w->magnetic_axis(400);
is( scalar(@$ax), 401, 'magnetic_axis returns n+1 points (x)' );
is( scalar(@$ay), 401, 'magnetic_axis returns n+1 points (y)' );
is( scalar(@$az), 401, 'magnetic_axis returns n+1 points (z)' );
approx_ok( $ax->[0], 5.22, 'axis first point x = R(v=0)' );
approx_ok( $ay->[0], 0,    'axis first point y = 0' );
# axis has a genuine helical (non-zero Z) excursion
my $zmax = 0; $zmax = $_ > $zmax ? $_ : $zmax for @$az;
ok( $zmax > 0.1, 'magnetic axis has helical vertical excursion' );

# cross section closes on itself (u = 0 and u = 2pi coincide)
my ( $Rc, $Zc ) = $w->cross_section( 0, 200, 1 );
is( scalar(@$Rc), 201, 'cross_section returns nu+1 points' );
approx_ok( $Rc->[0], $Rc->[-1], 'cross section closes in R' );
approx_ok( $Zc->[0], $Zc->[-1], 'cross section closes in Z' );

# nested surfaces shrink toward the axis
my $extent = sub {
    my $scale = shift;
    my ( $r, $z ) = $w->cross_section( 0, 100, $scale );
    my ( $min, $max ) = ( $r->[0], $r->[0] );
    for (@$r) { $min = $_ if $_ < $min; $max = $_ if $_ > $max; }
    return $max - $min;
};
ok( $extent->(1.0) > $extent->(0.5), 'outer surface wider than inner surface' );
ok( $extent->(0.5) > $extent->(0.1), 'inner nesting continues toward axis' );

# surface grid dimensions
my ( $X, $Y, $Z ) = $w->surface_grid( 10, 20, 1 );
is( scalar(@$X),     11, 'surface_grid has nu+1 rows' );
is( scalar(@{$X->[0]}), 21, 'surface_grid has nv+1 columns' );

# modular coils
my @coils = $w->modular_coils;
is( scalar(@coils), 2 * $w->num_field_periods, 'default coil count = 2*Nfp' );
is( scalar( @{ $coils[0] } ), 3, 'each coil is [x,y,z]' );
ok( scalar( @{ $coils[0][0] } ) > 10, 'coil has many points' );

my @coils5 = $w->modular_coils(5, 50);
is( scalar(@coils5), 5, 'explicit coil count honoured' );
is( scalar( @{ $coils5[0][0] } ), 51, 'explicit coil point count honoured' );

done_testing;

sub approx_ok {
    my ( $got, $exp, $name ) = @_;
    my $ok = abs( $got - $exp ) < 1e-2 * ( abs($exp) > 1 ? abs($exp) : 1 );
    ok( $ok, $name ) or diag("  got $got, expected $exp");
}
