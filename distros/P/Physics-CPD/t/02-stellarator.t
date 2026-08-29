use strict;
use warnings;
use Test::More;
use Physics::CPD::Stellarator;

sub approx {
    my ( $got, $exp, $tol, $name ) = @_;
    $tol ||= 1e-6;
    my $ok = ( $exp == 0 ) ? abs($got) < $tol
                           : abs( ( $got - $exp ) / $exp ) < $tol;
    ok( $ok, $name ) or diag("  got $got, expected $exp");
}

my $w = Physics::CPD::Stellarator->new(
    electron_density     => 8e19,
    electron_temperature => 4000,
    ion_temperature      => 2000,
    magnetic_field       => 2.5,
    heating_power        => 10,
);

#---------------------------------------------------------------- device
approx( $w->aspect_ratio, 5.5 / 0.53, 1e-9, 'aspect ratio = R0/a' );
approx( $w->plasma_volume, 2 * 3.14159265358979**2 * 5.5 * 0.53**2, 1e-6, 'plasma volume 2 pi^2 R a^2' );
approx( $w->field_period_angle, 2 * 3.14159265358979 / 5, 1e-9, 'field-period angle = 2pi/Nfp' );
approx( $w->safety_factor, 1 / 0.96, 1e-9, 'q = 1/iota' );

# W7-X reference numbers land in the right place
ok( abs( $w->plasma_volume - 30 ) < 1.5, 'plasma volume ~ 30 m^3 (W7-X)' );
ok( abs( $w->aspect_ratio - 10.4 ) < 0.2, 'aspect ratio ~ 10.4 (W7-X)' );

#---------------------------------------------------------------- physics
# ECRH 2nd-harmonic resonance at 140 GHz sits at 2.5 T
approx( $w->ecrh_resonance_field(2), 2.5, 3e-3, 'ECRH 2nd harmonic resonant field ~ 2.5 T' );

# stored energy = 3/2 p V
approx( $w->stored_energy, 1.5 * $w->plasma_pressure * $w->plasma_volume, 1e-9, 'W = 3/2 p V' );

# Sudo density limit closed form
approx(
    $w->sudo_density_limit,
    0.25 * sqrt( 10 * 2.5 / ( 0.53**2 * 5.5 ) ) * 1e20,
    1e-9, 'Sudo density limit'
);

# ISS04 scaling exponents verified through ratios
{
    my %base = (
        electron_density => 8e19, electron_temperature => 4000,
        magnetic_field => 2.5, heating_power => 10 );
    my $b  = Physics::CPD::Stellarator->new(%base);
    my $bn = Physics::CPD::Stellarator->new( %base, electron_density => 1.6e20 );
    my $bp = Physics::CPD::Stellarator->new( %base, heating_power => 20 );
    my $bb = Physics::CPD::Stellarator->new( %base, magnetic_field => 5 );
    approx( $bn->confinement_time_iss04 / $b->confinement_time_iss04, 2**0.54, 1e-6, 'ISS04 density exponent 0.54' );
    approx( $bp->confinement_time_iss04 / $b->confinement_time_iss04, 2**-0.61, 1e-6, 'ISS04 power exponent -0.61' );
    approx( $bb->confinement_time_iss04 / $b->confinement_time_iss04, 2**0.84, 1e-6, 'ISS04 field exponent 0.84' );
}

# triple product = n * Ti[keV] * tau
approx(
    $w->triple_product,
    $w->electron_density * ( $w->ion_temperature / 1000 ) * $w->confinement_time_iss04,
    1e-9, 'triple product n Ti tau'
);

# inherited plasma physics still works
ok( $w->debye_length > 0, 'inherited debye_length works' );
ok( $w->plasma_beta > 0,  'inherited plasma_beta works' );

# beta / density fractions
approx( $w->beta_fraction, $w->plasma_beta / 0.05, 1e-9, 'beta fraction vs limit' );
approx( $w->density_fraction, 8e19 / $w->sudo_density_limit, 1e-9, 'density fraction vs Sudo' );

# report
like( $w->device_report, qr/Wendelstein 7-X/, 'device_report renders' );

done_testing;
