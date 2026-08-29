#!/usr/bin/env perl
use strict;
use warnings;
use lib 'lib';
use Physics::CPD::Stellarator;

# Simulate a Wendelstein 7-X high-performance discharge.
my $w7x = Physics::CPD::Stellarator->new(
    electron_density     => 8e19,    # m^-3
    electron_temperature => 4000,    # eV
    ion_temperature      => 2500,    # eV
    magnetic_field       => 2.5,     # T
    heating_power        => 10,      # MW  (ECRH)
    ion_species          => 'H',
);

print $w7x->device_report;

# Scan the operating density and report ISS04 confinement + triple product.
print "\nDensity scan (ISS04 confinement + Lawson triple product):\n";
printf "  %-12s %-12s %-14s %-10s\n",
    'n_e[m^-3]', 'tau_E[s]', 'nTtau[keV.s/m3]', 'beta[%]';
for my $ne ( 2e19, 4e19, 6e19, 8e19, 1e20 ) {
    $w7x->electron_density($ne);
    printf "  %-12.2e %-12.3f %-14.3e %-10.2f\n",
        $ne,
        $w7x->confinement_time_iss04,
        $w7x->triple_product,
        100 * $w7x->plasma_beta;
}
