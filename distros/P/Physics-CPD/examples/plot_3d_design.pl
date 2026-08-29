#!/usr/bin/env perl
use strict;
use warnings;
use lib 'lib';
use Physics::CPD::Stellarator;

# Produce the full set of Wendelstein 7-X visualisations as PNG files.
# Requires PDL, PDL::Graphics::Gnuplot and a gnuplot binary.
my $outdir = shift @ARGV || '.';

my $w7x = Physics::CPD::Stellarator->new(
    electron_density     => 8e19,
    electron_temperature => 4000,
    ion_temperature      => 2500,
    magnetic_field       => 2.5,
    heating_power        => 10,
);

print "Writing plots to $outdir/ ...\n";

# 3-D engineering diagram: last-closed flux surface + helical magnetic axis
# + modular field coils.
my $f1 = $w7x->plot_3d(
    output => "$outdir/w7x_3d.png",
    title  => 'Wendelstein 7-X: plasma boundary, magnetic axis and modular coils',
    view   => [ 62, 25 ],
);
print "  3D design diagram      -> $f1\n";

# Poloidal flux-surface cross sections through one field period.
my $f2 = $w7x->plot_cross_sections(
    output     => "$outdir/w7x_cross_sections.png",
    n_angles   => 5,
    n_surfaces => 6,
);
print "  flux-surface sections  -> $f2\n";

# Radial density / temperature profiles.
my $f3 = $w7x->plot_profiles( output => "$outdir/w7x_profiles.png" );
print "  radial profiles        -> $f3\n";

# ISS04 energy-confinement time vs heating power.
my $f4 = $w7x->plot_confinement_scan(
    output    => "$outdir/w7x_confinement.png",
    parameter => 'heating_power',
    from      => 1,
    to        => 20,
);
print "  confinement scaling    -> $f4\n";

print "Done.\n";
