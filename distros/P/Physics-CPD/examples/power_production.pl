#!/usr/bin/env perl
use strict;
use warnings;
use lib 'lib';
use Physics::CPD::Stellarator;

# Theoretical fusion power production for a Wendelstein 7-X-class design.
#
# W7-X is a hydrogen/deuterium research device and does not itself produce
# significant fusion power.  Here we ask a "what if" question: how much power
# would a stellarator of this geometry deliver if it were operated as a
# deuterium-tritium reactor?  The estimate is 0-D (uniform n_e and T_i over the
# plasma volume) using the Bosch-Hale D-T reactivity built into the module.

my $reactor = Physics::CPD::Stellarator->new(
    config_name          => 'W7-X-class D-T reactor point',
    electron_density     => 2.0e20,   # m^-3
    electron_temperature => 15000,    # eV  (15 keV)
    ion_temperature      => 15000,    # eV  (15 keV)
    magnetic_field       => 2.5,      # T
    heating_power        => 10,       # MW  (auxiliary heating)
    dt_fuel_fraction     => 1.0,      # pure 50:50 D-T (no dilution)
);

print $reactor->power_report;

# ---------------------------------------------------------------------------
# Temperature scan: fusion power and gain Q across the reactor-relevant range.
# ---------------------------------------------------------------------------
print "\nIon-temperature scan (n_e = 2e20 m^-3, P_heat = 10 MW):\n";
printf "  %-8s %-14s %-12s %-14s %-8s\n",
    'T_i[keV]', '<sv>[m^3/s]', 'P_fus[MW]', 'wall[MW/m^2]', 'Q';
for my $T_keV ( 5, 10, 15, 20, 30, 50 ) {
    $reactor->ion_temperature( $T_keV * 1000 );
    printf "  %-8.0f %-14.3e %-12.1f %-14.3f %-8.1f\n",
        $T_keV,
        $reactor->dt_reactivity,
        $reactor->fusion_power_MW,
        $reactor->neutron_wall_load,
        $reactor->fusion_gain_Q;
}

# ---------------------------------------------------------------------------
# Density scan at fixed 15 keV: fusion power grows as n^2.
# ---------------------------------------------------------------------------
$reactor->ion_temperature(15000);
print "\nDensity scan (T_i = 15 keV, P_heat = 10 MW):\n";
printf "  %-12s %-12s %-14s %-8s\n",
    'n_e[m^-3]', 'P_fus[MW]', 'P_neutron[MW]', 'Q';
for my $ne ( 5e19, 1e20, 1.5e20, 2e20, 3e20 ) {
    $reactor->electron_density($ne);
    printf "  %-12.2e %-12.1f %-14.1f %-8.1f\n",
        $ne,
        $reactor->fusion_power_MW,
        $reactor->neutron_power_MW,
        $reactor->fusion_gain_Q;
}

print "\nNote: a 0-D estimate assuming uniform, pure 50:50 D-T; real devices\n";
print "have peaked profiles, fuel dilution and finite burn-up.\n";
