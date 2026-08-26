package Physics::Lithography;
use strict;
use warnings;
use Carp;

our $VERSION = '0.02';

# ═══════════════════════════════════════════════════════════════════════════════
# Physics::Lithography — Laser Direct Imprint Lithography Simulation
#
# Models laser-matter interaction, thermal transport, ablation, phase change,
# pattern transfer fidelity, and laser-induced forward transfer (LIFT).
# ═══════════════════════════════════════════════════════════════════════════════

sub new {
    my ($class, %opts) = @_;
    my $self = bless {
        verbose => $opts{verbose} // 0,
    }, $class;
    return $self;
}

sub laser {
    my ($self, %opts) = @_;
    require Physics::Lithography::Laser;
    $opts{verbose} //= $self->{verbose};
    return Physics::Lithography::Laser->new(%opts);
}

sub thermal {
    my ($self, %opts) = @_;
    require Physics::Lithography::Thermal;
    $opts{verbose} //= $self->{verbose};
    return Physics::Lithography::Thermal->new(%opts);
}

sub ablation {
    my ($self, %opts) = @_;
    require Physics::Lithography::Ablation;
    $opts{verbose} //= $self->{verbose};
    return Physics::Lithography::Ablation->new(%opts);
}

sub phase_change {
    my ($self, %opts) = @_;
    require Physics::Lithography::PhaseChange;
    $opts{verbose} //= $self->{verbose};
    return Physics::Lithography::PhaseChange->new(%opts);
}

sub pattern {
    my ($self, %opts) = @_;
    require Physics::Lithography::Pattern;
    $opts{verbose} //= $self->{verbose};
    return Physics::Lithography::Pattern->new(%opts);
}

sub lift {
    my ($self, %opts) = @_;
    require Physics::Lithography::LIFT;
    $opts{verbose} //= $self->{verbose};
    return Physics::Lithography::LIFT->new(%opts);
}

sub interface {
    my ($self, $name, %opts) = @_;
    my %map = (
        openfoam => 'Physics::Lithography::Interface::OpenFOAM',
        lammps   => 'Physics::Lithography::Interface::LAMMPS',
    );
    my $pkg = $map{lc $name} or croak "Unknown interface: $name";
    eval "require $pkg" or croak "Failed to load $pkg: $@";
    return $pkg->new(%opts);
}

sub methods    { return [qw(laser thermal ablation phase_change pattern lift)] }
sub interfaces { return [qw(openfoam lammps)] }

1;

__END__

=pod

=head1 NAME

Physics::Lithography - Laser Direct Imprint Lithography simulation framework

=head1 VERSION

Version 0.02

=head1 SYNOPSIS

    use Physics::Lithography;

    my $litho = Physics::Lithography->new(verbose => 1);

    # Characterise the laser source
    my $laser = $litho->laser(
        wavelength  => 355e-9,    # 355 nm (UV)
        pulse_width => 10e-9,     # 10 ns
        fluence     => 0.5,       # J/cm^2
        spot_size   => 5e-6,      # 5 um 1/e^2 radius
        profile     => 'gaussian',
        temporal    => 'gaussian',
    );

    # Solve 2D heat flow in a supported material
    my $thermal = $litho->thermal(material => 'pmma');
    $thermal->solve(laser => $laser, time => 100e-9);
    printf "Peak temperature: %.0f K\n", $thermal->T_max;

    # Predict ablation depth
    my $abl = $litho->ablation(alpha => 1e5, F_threshold => 0.1);
    printf "Ablation depth: %.0f nm\n", $abl->ablation_depth(fluence => 0.5) * 1e9;

=head1 DESCRIPTION

C<Physics::Lithography> is a Perl toolkit for simulating Laser Direct Imprint
Lithography (LDIL) and related laser-material processes. It provides compact
physics-based models for beam/pulse characterisation, thermal transport,
ablation, phase change, pattern-transfer fidelity, and Laser-Induced Forward
Transfer (LIFT). Interface modules can write input files for OpenFOAM and
LAMMPS when higher-fidelity CFD or molecular dynamics are required.

All quantities are in SI base units (metres, seconds, joules, kelvin, kg) with
fluence customarily expressed in J/cm^2 for convenience.

=head1 FEATURES

=over 4

=item * B<Laser characterisation> - Gaussian/flat-top/ring beam profiles,
temporal pulse shapes, Beer-Lambert absorption, thermal confinement checks.

=item * B<2D thermal solver> - Explicit finite-difference in cylindrical (r,z)
coordinates with built-in material data for PMMA, SU-8, polyimide, silicon,
gold and copper.

=item * B<Ablation modelling> - Logarithmic blow-off model, multi-pulse
incubation, crater geometry, volume removal rate and ablation efficiency.

=item * B<Phase change> - Melt pool analysis, resolidification time
(Stefan number), heat-affected zone depth and enthalpy method.

=item * B<Pattern transfer> - Minimum feature size prediction, edge acuity,
aspect-ratio limits, process window mapping and scan parameters.

=item * B<LIFT> - Vapour recoil pressure, jetting threshold, droplet diameter,
transfer regime classification, Weber/Reynolds numbers.

=item * B<Interface modules> - OpenFOAM (interFoam for melt dynamics) and
LAMMPS (TTM + MD for ultrafast ablation) input-file generation.

=back

=head1 MAIN FACTORY METHODS

The C<Physics::Lithography> class is a factory that returns specialised solver
objects. Common options such as C<verbose> are inherited by sub-modules unless
overridden.

=over 4

=item C<new(%opts)>

Constructor. C<verbose> enables informational messages.

=item C<laser(%opts)>

Returns a L<Physics::Lithography::Laser|"LASER"> object.

=item C<thermal(%opts)>

Returns a L<Physics::Lithography::Thermal|"THERMAL"> object.

=item C<ablation(%opts)>

Returns a L<Physics::Lithography::Ablation|"ABLATION"> object.

=item C<phase_change(%opts)>

Returns a L<Physics::Lithography::PhaseChange|"PHASE_CHANGE"> object.

=item C<pattern(%opts)>

Returns a L<Physics::Lithography::Pattern|"PATTERN"> object.

=item C<lift(%opts)>

Returns a L<Physics::Lithography::LIFT|"LIFT"> object.

=item C<interface($name, %opts)>

Returns an interface object. C<$name> may be C<'openfoam'> or C<'lammps'>.

=item C<methods()>

Returns an array reference of the sub-module factory method names.

=item C<interfaces()>

Returns an array reference of the supported interface names.

=back

=head2 LASER

    my $laser = $litho->laser(
        wavelength  => 355e-9,
        pulse_width => 10e-9,
        fluence     => 0.5,         # J/cm^2
        spot_size   => 5e-6,        # m
        profile     => 'gaussian',  # gaussian | flat_top | ring
        temporal    => 'gaussian',  # gaussian | square
        rep_rate    => 1000,        # Hz
    );

Public methods:

=over 4

=item C<peak_intensity()>

Peak intensity in W/cm^2 for a Gaussian temporal pulse.

=item C<pulse_energy()>

Pulse energy in joules.

=item C<average_power()>

Average power in watts.

=item C<photon_energy_eV()>

Photon energy in electron-volts.

=item C<thermal_diffusion_length(%opts)>

Thermal diffusion length (m) for a given diffusivity.

=item C<spatial_profile($r)>

Normalised spatial intensity at radius C<$r> (m).

=item C<temporal_profile($t)>

Normalised temporal intensity at time C<$t> (s).

=item C<absorption_profile(%opts)>

Beer-Lambert volumetric heat source (W/m^3).

=item C<penetration_depth(%opts)>

Optical penetration depth (m).

=item C<is_thermal_confinement(%opts)>

True if the pulse is shorter than the thermal diffusion time for the material.

=item C<photon_flux()>

Photons per pulse per unit area (photons/m^2).

=item C<summary()>

Hash reference summarising laser parameters and derived values.

=back

=head2 THERMAL

    my $thermal = $litho->thermal(
        material => 'pmma',   # pmma | su8 | polyimide | silicon | gold | copper
        n_r      => 50,
        n_z      => 50,
        domain_r => 20e-6,
        domain_z => 10e-6,
    );

Public methods:

=over 4

=item C<solve(%opts)>

Run the explicit finite-difference heat equation. Requires C<laser> (a
C<Physics::Lithography::Laser> object) and either C<time> or C<steps>.

=item C<temperature_at($r, $z)>

Interpolated temperature (K) at arbitrary coordinates.

=item C<surface_temperature()>

Array reference of surface temperatures T(r, z=0).

=item C<T_max()>

Maximum temperature reached (K).

=item C<melt_radius()>

Surface radius where temperature drops below the melt point (m), or C<undef>.

=item C<melt_depth()>

Depth at the centre where temperature drops below the melt point (m), or
C<undef>.

=item C<decomposition_depth()>

Centre depth where the decomposition temperature is reached (m), for polymers.

=item C<field()>

Full 2D temperature field as an array reference C<[nr][nz]>.

=item C<grid_info()>

Hash reference of grid parameters.

=item C<materials()>

Available material names.

=item C<material_info($name)>

Material properties for C<$name>.

=back

=head2 ABLATION

    my $abl = $litho->ablation(
        alpha        => 1e5,    # 1/m effective absorption
        F_threshold  => 0.1,    # J/cm^2
        incubation_S => 0.85,   # incubation coefficient (S < 1)
    );

Public methods:

=over 4

=item C<ablation_depth(%opts)>

Single-pulse ablation depth (m) from the logarithmic blow-off model.

=item C<multi_pulse_depth(%opts)>

Accumulated ablation depth (m) with multi-pulse incubation.

=item C<ablation_rate_curve(%opts)>

Array reference of C<{fluence, depth_nm}> pairs over a fluence sweep.

=item C<calculate_threshold(%opts)>

Estimate threshold fluence (J/cm^2) from thermal properties.

=item C<crater_profile(%opts)>

Gaussian-beam crater radius/depth/profile hash reference.

=item C<volume_per_pulse(%opts)>

Removed volume per pulse (m^3).

=item C<efficiency(%opts)>

Mass removed per unit energy (kg/J).

=item C<threshold_with_incubation(%opts)>

Threshold fluence (J/cm^2) for N pulses.

=item C<stats()>

Hash reference of configured ablation parameters.

=back

=head2 PHASE_CHANGE

    my $pc = $litho->phase_change(
        T_melt   => 600,     # K
        L_fusion => 2.5e5,   # J/kg
        density  => 1200,
        cp       => 1200,
    );

Public methods:

=over 4

=item C<analyze_melt_pool(%opts)>

Compute melt/vapour pool geometry from a temperature field.

=item C<resolidification_time(%opts)>

Estimate resolidification time (s) from the Stefan number.

=item C<cooling_rate(%opts)>

Cooling rate at the solidification front (K/s).

=item C<haz_depth(%opts)>

Heat-affected zone depth (m).

=item C<enthalpy($T)>

Enthalpy per unit volume (J/m^3) at temperature C<$T>.

=item C<phase_at($T)>

Phase state string: C<'solid'>, C<'liquid'> or C<'vapor'>.

=item C<melt_pool()>

Accessor returning the stored melt-pool hash reference.

=back

=head2 PATTERN

    my $pat = $litho->pattern();

Public methods:

=over 4

=item C<minimum_feature_size(%opts)>

Minimum resolvable feature (nm) combining the optical spot and thermal
diffusion limits.

=item C<edge_acuity(%opts)>

Edge width from thermal and optical absorption lengths (nm).

=item C<max_aspect_ratio(%opts)>

Achievable depth-to-width ratio.

=item C<process_window(%opts)>

Array reference of C<{fluence, depth_nm, width_nm, quality}> points.

=item C<scan_parameters(%opts)>

Scan pitch, velocity, throughput and dwell time.

=item C<line_pattern(%opts)>

Predicted scanning line width and depth (nm).

=item C<resolution_comparison(%opts)>

Array reference comparing resolution for a set of pulse configurations.

=back

=head2 LIFT

    my $lift = $litho->lift(
        film_thickness  => 100e-9,  # donor film (m)
        density         => 19300,   # kg/m^3 (gold)
        T_melt          => 1337,    # K
        T_boil          => 3129,    # K
        L_vaporize      => 1.74e6,  # J/kg
        surface_tension => 1.14,    # N/m
        alpha           => 7e7,     # 1/m
        reflectivity    => 0.37,
        gap             => 50e-6,   # donor-receiver gap (m)
    );

Public methods:

=over 4

=item C<transfer_threshold()>

Fluence threshold (J/cm^2) for forward transfer.

=item C<transfer_regime(%opts)>

Classification string: C<no_transfer>, C<sub_threshold>, C<jetting>,
C<spray> or C<explosive>.

=item C<recoil_pressure(%opts)>

Vapour recoil pressure (Pa) at the donor interface.

=item C<jet_velocity(%opts)>

Estimated jet velocity (m/s).

=item C<droplet_diameter(%opts)>

Predicted droplet diameter (m).

=item C<weber_number(%opts)> / C<reynolds_number(%opts)>

Dimensionless jetting parameters.

=item C<flight_time(%opts)>

Donor-to-receiver flight time (s).

=item C<fluence_sweep(%opts)>

Array reference of regime, droplet size, velocity and pressure over a
fluence sweep.

=back

=head2 INTERFACE MODULES

    # OpenFOAM case generation
    my $of = $litho->interface('openfoam', case_dir => './melt_case');
    $of->generate_case(dt => 1e-10, end_time => 1e-6);

    # LAMMPS TTM-MD script generation
    my $lmp = $litho->interface('lammps', output_dir => './laser_md');
    $lmp->generate_script(material => 'gold', fluence => 0.5, pulse_fs => 100);

Supported interfaces are C<openfoam> (L<Physics::Lithography::Interface::OpenFOAM>)
and C<lammps> (L<Physics::Lithography::Interface::LAMMPS>).

=head1 EXAMPLES

The distribution includes example scripts in the F<examples/> directory:

=over 4

=item F<examples/quick_start.pl>

Short introductory script.

=item F<examples/thermal_imprint.pl>

Resolution analysis, thermal simulation, ablation depth vs fluence,
multi-pulse incubation and scanning parameters.

=item F<examples/lift_gold.pl>

LIFT transfer regimes for a gold donor film, including threshold
determination, fluence sweep and droplet sizing.

=back

Run an example with:

    perl -Ilib examples/thermal_imprint.pl

=head1 PHYSICS BACKGROUND

=head2 Logarithmic blow-off model

For a Beer-Lambert absorber the single-pulse ablation depth is

    d = (1/alpha) * ln(F / F_th)

where C<alpha> is the effective absorption coefficient, C<F> is the incident
fluence and C<F_th> is the threshold fluence.

=head2 Multi-pulse incubation

The threshold fluence decreases with accumulated pulses:

    F_th(N) = F_th(1) * N^(S - 1)      S < 1

=head2 Thermal confinement

A pulse is thermally confined when its duration is shorter than the time
required for heat to diffuse across the optical absorption depth:

    tau << 1 / (alpha^2 * kappa)

Thermal confinement enables sharper, smaller features.

=head2 LIFT transfer regimes

=over 4

=item * B<Sub-threshold> - incomplete film release

=item * B<Jetting> - clean single-droplet transfer (optimal)

=item * B<Spray> - multiple satellite droplets

=item * B<Explosive> - plasma-assisted, poor resolution

=back

=head1 INSTALLATION

    git clone https://github.com/jtrujil43/Physics-Lithography.git
    cd Physics-Lithography
    perl Makefile.PL
    make
    make test

Core dependencies (C<Carp>, C<List::Util>, C<File::Path>) ship with Perl.
OpenFOAM and LAMMPS are optional and only needed for the interface modules.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=head1 AUTHOR

Jovan Trujillo

=cut
