#!/usr/bin/env perl
use strict;
use warnings;
use lib 'lib';
use Physics::CPD;

# Base computational-plasma-dynamics engine, standalone.
# A hot hydrogen plasma at fusion-relevant conditions.
my $plasma = Physics::CPD->new(
    electron_density     => 1e20,    # m^-3
    electron_temperature => 5000,    # eV  (5 keV)
    ion_temperature      => 3000,    # eV  (3 keV)
    magnetic_field       => 3.0,     # T
    ion_species          => 'D',     # deuterium
);

print $plasma->report;

print "\nA few individual quantities:\n";
printf "  ion sound speed        c_s      = %.3e m/s\n", $plasma->ion_sound_speed;
printf "  electron mean free path lambda  = %.3e m\n",   $plasma->mean_free_path;
printf "  collision frequency    nu_ei    = %.3e Hz\n",  $plasma->collision_frequency;
printf "  Spitzer resistivity    eta      = %.3e Ohm.m\n", $plasma->spitzer_resistivity;
