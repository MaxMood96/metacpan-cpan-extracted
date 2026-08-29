use strict;
use warnings;
use Test::More;
use Physics::CPD;

# fractional-tolerance comparison
sub approx {
    my ( $got, $exp, $tol, $name ) = @_;
    $tol ||= 1e-3;
    my $ok = ( $exp == 0 ) ? abs($got) < $tol
                           : abs( ( $got - $exp ) / $exp ) < $tol;
    ok( $ok, $name ) or diag("  got $got, expected $exp");
}

my $p = Physics::CPD->new(
    electron_density     => 1e19,
    electron_temperature => 1000,
    magnetic_field       => 1,
    ion_species          => 'H',
);

# defaults / quasineutrality
is( $p->ion_temperature, 1000, 'ion temperature defaults to electron temperature' );
approx( $p->ion_density, 1e19, 1e-9, 'ion density equals n_e/Z for Z=1' );

# electron cyclotron frequency == e B / m_e exactly
approx(
    $p->electron_cyclotron_frequency,
    Physics::CPD::ELEMENTARY_CHARGE() * 1 / Physics::CPD::ELECTRON_MASS(),
    1e-12, 'electron cyclotron frequency = eB/m_e'
);
# 28 GHz/T rule of thumb
approx( $p->electron_cyclotron_frequency_hz, 27.99e9, 2e-3, 'f_ce ~ 28 GHz/T' );

# NRL: f_pe = 8980 * sqrt(n_cm3) Hz
approx( $p->electron_plasma_frequency_hz, 8980 * sqrt(1e13), 3e-3, 'f_pe ~ 8980*sqrt(n)' );

# NRL: lambda_D = 743 * sqrt(Te_eV / n_cm3) cm
approx( $p->debye_length, 7.43e2 * sqrt( 1000 / 1e13 ) * 1e-2, 3e-3, 'Debye length matches NRL' );

# beta is pressure ratio, and pressure is the sum of species pressures
approx( $p->plasma_beta, $p->plasma_pressure / $p->magnetic_pressure, 1e-12, 'beta = p/pmag' );
approx(
    $p->plasma_pressure,
    $p->electron_density * $p->electron_temperature_joules
        + $p->ion_density * $p->ion_temperature_joules,
    1e-12, 'pressure is electron + ion pressure'
);

# temperature conversions
approx( $p->electron_temperature_kelvin, 1000 * 11604.51812, 1e-6, 'eV -> K conversion' );
approx( $p->electron_temperature_joules, 1000 * 1.602176634e-19, 1e-9, 'eV -> J conversion' );

# ion Larmor radius bigger than electron Larmor radius
ok( $p->ion_gyroradius > $p->electron_gyroradius, 'ion gyroradius > electron gyroradius' );

# Alfven speed scales linearly with B
my $p2 = Physics::CPD->new(
    electron_density => 1e19, electron_temperature => 1000, magnetic_field => 2 );
approx( $p2->alfven_velocity / $p->alfven_velocity, 2, 1e-9, 'Alfven speed ~ B' );

# species handling
my $d = Physics::CPD->new( ion_species => 'D' );
approx( $d->ion_mass, 2.01410177812 * Physics::CPD::ATOMIC_MASS_UNIT(), 1e-6, 'deuterium mass' );
is( $d->ion_charge, 1, 'deuterium charge Z=1' );

my $he = Physics::CPD->new( ion_species => 'He' );
is( $he->ion_charge, 2, 'helium charge Z=2' );

# collisionality sanity: Coulomb log in a reasonable range, resistivity positive
ok( $p->coulomb_logarithm > 5 && $p->coulomb_logarithm < 30, 'Coulomb log in physical range' );
ok( $p->spitzer_resistivity > 0, 'Spitzer resistivity positive' );
ok( $p->plasma_parameter > 1, 'many particles in Debye sphere (ideal plasma)' );

# report is a non-empty string
like( $p->report, qr/Computational Plasma Dynamics/, 'report renders' );
ok( ref $p->as_hash eq 'HASH', 'as_hash returns a hashref' );

done_testing;
