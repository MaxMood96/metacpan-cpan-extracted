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
    electron_density     => 2e20,
    electron_temperature => 15000,
    ion_temperature      => 15000,     # 15 keV
    magnetic_field       => 2.5,
    heating_power        => 10,
);

#---------------------------------------------------------------- reactivity
# Bosch-Hale D-T <sigma v> against published reference values (~0.25% accuracy).
approx( $w->dt_reactivity(10),  1.136e-22, 3e-3, '<sv> at 10 keV ~ 1.14e-22 m^3/s' );
approx( $w->dt_reactivity(20),  4.330e-22, 3e-3, '<sv> at 20 keV ~ 4.33e-22 m^3/s' );

# reactivity rises with temperature through the fusion-relevant range and peaks
# near ~64 keV
ok( $w->dt_reactivity(20) > $w->dt_reactivity(10), '<sv> increases 10 -> 20 keV' );
ok( $w->dt_reactivity(64) > $w->dt_reactivity(30), '<sv> still rising toward the peak' );
ok( $w->dt_reactivity(100) < $w->dt_reactivity(64), '<sv> falls again past the peak' );

# no fuel temperature -> no reactions
is( $w->dt_reactivity(0), 0, '<sv> is zero at zero temperature' );

# default reactivity uses the model ion temperature (15 keV)
approx( $w->dt_reactivity, $w->dt_reactivity(15), 1e-12, 'default <sv> uses ion_temperature' );

#---------------------------------------------------------------- power
# fuel-ion density scales with dt_fuel_fraction
approx( $w->fuel_ion_density, 2e20, 1e-12, 'fuel density = f * n_e (f=1)' );

# closed-form fusion power density  P/V = (n_fuel/2)^2 <sv> E_DT
my $E_DT = 17.59 * 1.602176634e-13;     # J per reaction
approx(
    $w->fusion_power_density,
    ( 2e20 / 2 )**2 * $w->dt_reactivity * $E_DT,
    1e-9, 'fusion power density closed form'
);

# total power = density * volume
approx( $w->fusion_power, $w->fusion_power_density * $w->plasma_volume,
    1e-12, 'P_fus = power density * volume' );
approx( $w->fusion_power_MW, $w->fusion_power / 1e6, 1e-12, 'MW conversion' );

# neutron + alpha channels sum to the total and carry the right fractions
approx( $w->neutron_power_MW + $w->alpha_power_MW, $w->fusion_power_MW,
    1e-9, 'neutron + alpha = total fusion power' );
approx( $w->neutron_power_MW / $w->fusion_power_MW, 14.07 / 17.59,
    1e-9, 'neutrons carry 14.07/17.59 of the energy' );
approx( $w->alpha_power_MW / $w->fusion_power_MW, 3.52 / 17.59,
    1e-9, 'alphas carry 3.52/17.59 of the energy' );

# W7-X-class design at a reactor-relevant D-T point lands at a few hundred MW
ok( $w->fusion_power_MW > 100 && $w->fusion_power_MW < 500,
    'reactor-point fusion power is a few hundred MW' );

# fusion gain  Q = P_fus / P_heat
approx( $w->fusion_gain_Q, $w->fusion_power_MW / 10, 1e-12, 'Q = P_fus / P_heat' );

# neutron wall load  = neutron power / plasma surface
approx( $w->neutron_wall_load, $w->neutron_power_MW / $w->plasma_surface_area,
    1e-12, 'neutron wall load = P_n / surface' );

#---------------------------------------------------------------- fuel fraction
# halving the fuel fraction quarters the power (density enters squared)
{
    my $half = Physics::CPD::Stellarator->new(
        electron_density => 2e20, ion_temperature => 15000,
        heating_power => 10, dt_fuel_fraction => 0.5,
    );
    approx( $half->fusion_power_MW, 0.25 * $w->fusion_power_MW,
        1e-9, 'fusion power scales as fuel-fraction squared' );
}

# power_report renders
like( $w->power_report, qr/Theoretical fusion power/, 'power_report renders' );
like( $w->power_report, qr/fusion gain/,              'power_report shows Q' );

done_testing;
