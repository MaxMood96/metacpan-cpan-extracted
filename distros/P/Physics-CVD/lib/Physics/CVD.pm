package Physics::CVD;
use strict;
use warnings;
use Carp;

our $VERSION = '0.03';

# ═══════════════════════════════════════════════════════════════════════════════
# Physics::CVD — Chemical Vapor Deposition Simulation Framework
#
# Provides KMC surface growth, gas-phase chemistry, mass transport modeling,
# and reactor-scale simulation for CVD processes.
# ═══════════════════════════════════════════════════════════════════════════════

sub new {
    my ($class, %opts) = @_;
    my $self = bless {
        temperature => $opts{temperature} // 700,   # K
        pressure    => $opts{pressure}    // 100,   # Pa (typ. LPCVD)
        verbose     => $opts{verbose}     // 0,
    }, $class;
    return $self;
}

# Factory methods
sub reactor {
    my ($self, %opts) = @_;
    require Physics::CVD::Reactor;
    $opts{temperature} //= $self->{temperature};
    $opts{pressure}    //= $self->{pressure};
    $opts{verbose}     //= $self->{verbose};
    return Physics::CVD::Reactor->new(%opts);
}

sub chemistry {
    my ($self, %opts) = @_;
    require Physics::CVD::Chemistry;
    $opts{temperature} //= $self->{temperature};
    $opts{pressure}    //= $self->{pressure};
    $opts{verbose}     //= $self->{verbose};
    return Physics::CVD::Chemistry->new(%opts);
}

sub transport {
    my ($self, %opts) = @_;
    require Physics::CVD::Transport;
    $opts{temperature} //= $self->{temperature};
    $opts{pressure}    //= $self->{pressure};
    $opts{verbose}     //= $self->{verbose};
    return Physics::CVD::Transport->new(%opts);
}

sub kmc {
    my ($self, %opts) = @_;
    require Physics::CVD::KMC;
    $opts{temperature} //= $self->{temperature};
    $opts{pressure}    //= $self->{pressure};
    $opts{verbose}     //= $self->{verbose};
    return Physics::CVD::KMC->new(%opts);
}

sub film {
    my ($self, %opts) = @_;
    require Physics::CVD::Film;
    return Physics::CVD::Film->new(%opts);
}

sub interface {
    my ($self, $name, %opts) = @_;
    my %map = (
        openfoam => 'Physics::CVD::Interface::OpenFOAM',
        lammps   => 'Physics::CVD::Interface::LAMMPS',
        cantera  => 'Physics::CVD::Interface::Cantera',
    );
    my $pkg = $map{lc $name} or croak "Unknown interface: $name";
    eval "require $pkg" or croak "Failed to load $pkg: $@";
    return $pkg->new(%opts);
}

sub methods    { return [qw(reactor chemistry transport kmc film)] }
sub interfaces { return [qw(openfoam lammps cantera)] }

1;

__END__

=head1 NAME

Physics::CVD - Chemical Vapor Deposition simulation framework in Perl

=head1 SYNOPSIS

    use Physics::CVD;

    my $cvd = Physics::CVD->new(
        temperature => 700,    # K
        pressure    => 66.5,   # Pa (500 mTorr)
    );

    my $chem = $cvd->chemistry;
    $chem->add_species(name => 'TEOS', mass => 208, concentration => 1e16);
    $chem->add_gas_reaction(
        reactants => ['TEOS'], products => ['SiO2_g'],
        A => 1e15, Ea => 2.9,
    );

    my $kmc = $cvd->kmc(lattice_size => [30, 30, 15]);
    $kmc->add_species(
        name => 'Si', sticking_coeff => 0.04,
        partial_pressure => 4.0, diffusion_barrier => 0.8,
    );
    $kmc->deposit(steps => 1000);

    my $film = $kmc->get_film;
    printf "Thickness: %.2f nm\n", $film->thickness;
    printf "Roughness: %.3f nm\n", $film->roughness;

=head1 DESCRIPTION

C<Physics::CVD> is a Perl library for simulating Chemical Vapor Deposition
(CVD) processes. It ties together gas-phase chemistry, surface Kinetic Monte
Carlo (KMC) growth, reactor-scale transport, mass-transport models, film
analysis, and interfaces to external simulation tools.

The intended workflow is:

=over 4

=item 1. Create a C<Physics::CVD> instance with reactor conditions.

=item 2. Build a chemistry network with C<chemistry()>.

=item 3. Model reactor flow and transport with C<reactor()> and C<transport()>.

=item 4. Run atomistic film growth with C<kmc()> and analyze with C<get_film()>.

=item 5. Export cases to OpenFOAM, LAMMPS, or Cantera via C<interface()>.

=back

=head1 FEATURES

=over 4

=item * Gas-phase chemistry — Arrhenius kinetics, reaction networks, precursor decomposition.

=item * Surface KMC — Multi-species, deposition-centric Kinetic Monte Carlo for film growth.

=item * Reactor modeling — LPCVD/PECVD/MOCVD geometry, flow, Reynolds/Knudsen numbers.

=item * Mass transport — Boundary layer, Knudsen diffusion, feature-scale step coverage.

=item * Film analysis — Thickness, roughness, density, composition profiles, stoichiometry.

=item * Interfaces — OpenFOAM (reactingFoam cases), LAMMPS (ReaxFF/Tersoff), Cantera (YAML mechanisms and Python reactors).

=back

=head1 CONSTRUCTOR

=head2 new(%opts)

Create a new CVD simulation object. The temperature and pressure are propagated
to the factory methods unless overridden.

Options:

=over 4

=item C<temperature>

Process temperature in Kelvin (default: 700 K).

=item C<pressure>

Process pressure in Pascals (default: 100 Pa, typical of LPCVD).

=item C<verbose>

Verbosity level 0/1 (default: 0).

=back

=head1 FACTORY METHODS

=head2 chemistry(%opts)

Return a L<Physics::CVD::Chemistry> engine. Inherits C<temperature>,
C<pressure>, and C<verbose> from the main object.

=head2 kmc(%opts)

Return a L<Physics::CVD::KMC> surface-growth engine. Inherits C<temperature>,
C<pressure>, and C<verbose>. Common options: C<lattice_size>, C<lattice_const>,
C<attempt_freq>.

=head2 reactor(%opts)

Return a L<Physics::CVD::Reactor> model. Inherits C<temperature>,
C<pressure>, and C<verbose>. Common options: C<type>, C<length>, C<diameter>,
C<gap>, C<wafer_diameter>, C<total_flow>, C<carrier_gas>, C<gases>.

=head2 transport(%opts)

Return a L<Physics::CVD::Transport> model. Inherits C<temperature>,
C<pressure>, and C<verbose>. Common options: C<feature_type>, C<aspect_ratio>,
C<feature_width>.

=head2 film(%opts)

Return a standalone L<Physics::CVD::Film> analysis object.

=head2 interface($name, %opts)

Load an external-tool interface. C<$name> must be one of:

=over 4

=item C<openfoam> — L<Physics::CVD::Interface::OpenFOAM>

=item C<lammps> — L<Physics::CVD::Interface::LAMMPS>

=item C<cantera> — L<Physics::CVD::Interface::Cantera>

=back

=head2 methods()

Return an arrayref of factory method names: C<reactor>, C<chemistry>,
C<transport>, C<kmc>, C<film>.

=head2 interfaces()

Return an arrayref of available interface names: C<openfoam>, C<lammps>,
C<cantera>.

=head1 API REFERENCE

=head2 Physics::CVD::Chemistry

Chemical kinetics engine for gas-phase and surface reactions.

=over 4

=item C<add_species(%spec)>

Register a species with keys such as C<name>, C<mass>, C<formula>, C<type>,
and C<concentration>.

=item C<add_gas_reaction(%rxn)>

Add an Arrhenius gas reaction. Keys: C<name>, C<reactants>, C<products>, C<A>,
C<Ea>, C<order>.

=item C<add_surface_reaction(%rxn)>

Add a surface reaction (Langmuir-Hinshelwood or Eley-Rideal). Keys include
C<mechanism>, C<sticking_coeff>, C<Ea>, C<A>.

=item C<rate_constant(%opts)>

Compute C<k = A exp(-Ea / kT)>.

=item C<gas_rates()>

Compute gas-phase rates from current concentrations.

=item C<surface_rates(%opts)>

Compute surface reaction rates for supplied coverages.

=item C<impingement_flux(%opts)>

Hertz-Knudsen flux in molecules/cmB<2>/s.

=item C<sticking_coefficient(%opts)>

Temperature-dependent sticking coefficient.

=item C<evolve(%opts)>

Integrate gas chemistry forward in time with simple Euler integration.

=item C<growth_rate(%opts)>

Estimate deposition rate in nm/min from impingement flux, sticking coefficient,
and film density.

=item C<set_concentration($species, $conc)> / C<get_concentration($species)> / C<concentrations()>

Concentration accessors.

=item C<stats()>

Return counts of species and reactions plus current state.

=back

=head2 Physics::CVD::KMC

Deposition-centric Kinetic Monte Carlo engine.

=over 4

=item C<new(%opts)>

Constructor options include C<lattice_size> (default C<[30,30,20]>),
C<lattice_const> (default 3.0 Å), C<attempt_freq> (default 1e13 sB<-1>),
C<temperature>, C<pressure>, and C<verbose>.

=item C<add_species(%spec)>

Register a depositing species with C<sticking_coeff>, diffusion/desorption/
decomposition barriers, C<partial_pressure>, and flags such as C<is_precursor>.

=item C<add_surface_reaction(%rxn)>

Add a co-adsorbed surface reaction between species.

=item C<deposit(%opts)>

Estimate deposition steps from impingement flux and run the KMC.

=item C<run(%opts)>

Execute the deposition-centric BKL loop (adsorption, diffusion,
decomposition, reaction).

=item C<get_film()>

Return a L<Physics::CVD::Film> object built from the lattice state.

=item C<coverage()>

Fraction of surface sites currently occupied.

=item C<stats()>

Return simulation time, steps, deposited atoms, coverage, and event counts.

=back

=head2 Physics::CVD::Reactor

Reactor-scale flow and transport diagnostics.

=over 4

=item C<new(%opts)>

Constructor options: C<type> (default C<lpcvd_tube>), C<length>, C<diameter>,
C<gap>, C<wafer_diameter>, C<total_flow>, C<carrier_gas>, C<gases>, plus
C<temperature>, C<pressure>, and C<verbose>.

=item C<gas_velocity()>

Mean gas velocity in m/s.

=item C<residence_time()>

Gas residence time in seconds.

=item C<reynolds_number()>

Reynolds number based on carrier-gas properties.

=item C<gas_density()> / C<gas_viscosity()>

Ideal-gas density and Sutherland viscosity.

=item C<mean_free_path()>

Gas mean free path in meters.

=item C<knudsen_number()>

C<lambda / characteristic_length>.

=item C<damkohler_number(%opts)>

C<Da = surface_rate * L / D>, the reaction-to-transport ratio.

=item C<diffusivity(%opts)>

Chapman-Enskog binary diffusivity in cmB<2>/s.

=item C<thiele_modulus(%opts)> / C<step_coverage(%opts)>

Feature-scale Thiele modulus and trench step coverage.

=item C<summary()>

Hash of reactor flow/transport diagnostics.

=back

=head2 Physics::CVD::Transport

Feature-scale mass-transport model.

=over 4

=item C<new(%opts)>

Options: C<feature_type> (default C<trench>), C<aspect_ratio>,
C<feature_width>, plus C<temperature>, C<pressure>, C<verbose>.

=item C<knudsen_diffusivity(%opts)>

Knudsen diffusivity inside a feature in cmB<2>/s.

=item C<effective_diffusivity(%opts)>

Bosanquet interpolation: C<1/D_eff = 1/D_bulk + 1/D_Kn>.

=item C<step_coverage(%opts)>

Analytical step coverage estimate from sticking coefficient and aspect ratio.

=item C<conformality_profile(%opts)>

Relative flux versus depth inside a feature.

=item C<boundary_layer_thickness(%opts)>

Stagnation-flow boundary-layer thickness in cm.

=item C<mass_transfer_coeff(%opts)>

C<h_m = D / delta> in cm/s.

=item C<wafer_uniformity(%opts)>

Normalized radial deposition-rate profile across a wafer.

=item C<regime(%opts)>

Classify the regime as reaction-limited, transport-limited, or mixed.

=item C<stats()>

Return feature parameters plus computed Knudsen diffusivity and step coverage.

=back

=head2 Physics::CVD::Film

Analysis object for a deposited film.

=over 4

=item C<thickness()>

Average film thickness in nm.

=item C<roughness()>

RMS surface roughness in nm.

=item C<density()> / C<porosity()>

Fraction of occupied sites and C<1 - density>.

=item C<composition()>

Species counts and fractions over the whole film.

=item C<composition_profile(%opts)>

Depth-resolved composition bins.

=item C<stoichiometry($A, $B)>

Atomic ratio C<A:B>.

=item C<export_xyz($file)>

Export film to XYZ format; returns atom count.

=item C<export_lammps_data($file)>

Export film to LAMMPS data format; returns atom count.

=back

=head2 Interfaces

=head3 Physics::CVD::Interface::OpenFOAM

=over 4

=item C<generate_case(%opts)>

Create a complete reactingFoam case directory.

=item C<run(%opts)>

Run C<blockMesh> and the selected solver, serial or MPI.

=back

=head3 Physics::CVD::Interface::LAMMPS

=over 4

=item C<generate_surface_reaction(%opts)>

Write a ReaxFF CVD deposition input script.

=item C<generate_stress_analysis(%opts)>

Write a Tersoff NPT stress-relaxation script.

=item C<run(%opts)>

Execute LAMMPS serial or MPI run.

=item C<parse_log($file)>

Parse thermodynamic output rows into an array of hashes.

=back

=head3 Physics::CVD::Interface::Cantera

=over 4

=item C<generate_sio2_mechanism(%opts)>

Write C<sio2_cvd.yaml> for TEOS/OB<2> to SiOB<2>.

=item C<generate_si3n4_mechanism(%opts)>

Write C<si3n4_cvd.yaml> for DCS+NHB<3> LPCVD SiB<3>NB<4>.

=item C<generate_reactor_script(%opts)>

Write an executable Python/Cantera reactor script.

=back

=head1 PHYSICAL MODELS

=head2 Gas-Phase Chemistry

=over 4

=item Arrhenius kinetics: C<k = A exp(-Ea / kT)>

=item Hertz-Knudsen impingement: C<Phi = P / sqrt(2 pi m kT)>

=item Binary diffusion: Chapman-Enskog with collision integrals

=back

=head2 Surface Kinetics

=over 4

=item Langmuir-Hinshelwood: rate proportional to C<theta_A theta_B k(T)>

=item Eley-Rideal: rate proportional to C<P_gas theta_surface S(T)>

=item Sticking coefficient: C<S(T) = S0 exp(-Ea / kT)>

=back

=head2 Mass Transport

=over 4

=item Knudsen diffusion: C<D_Kn = (w / 3) sqrt(8 kT / pi m)>

=item Bosanquet interpolation: C<1 / D_eff = 1 / D_bulk + 1 / D_Kn>

=item Step coverage: C<SC = 1 / (1 + phi^2 / 6)> where C<phi = AR sqrt(S / (2 - S))>

=item Boundary layer: C<delta = sqrt(D L / v)>

=back

=head2 Reactor Physics

=over 4

=item Reynolds number: C<Re = rho v D / mu>

=item Knudsen number: C<Kn = lambda / L>

=item Damköhler number: C<Da = k_s L / D> (reaction vs transport)

=item Thiele modulus: C<phi = L sqrt(k_s / D)>

=back

=head1 CVD PROCESS REFERENCE

Typical process windows used by the built-in examples:

    Process        Precursors      T (C)    P (Pa)    Rate (nm/min)
    --------------------------------------------------------------
    TEOS SiO2      TEOS + O2       680      40        10-30
    PE-SiO2        SiH4 + N2O      350      300       50-200
    LP-Si3N4       DCS + NH3       780      25        3-5
    PE-SiNx        SiH4 + NH3      350      200       10-50
    Poly-Si        SiH4            620      30        10-20
    W-CVD          WF6 + SiH4      400      5000      100-300

=head1 EXAMPLES

Run the bundled examples from the C<examples/> directory:

    cd examples
    perl -I../lib sio2_teos.pl    # TEOS CVD SiO2
    perl -I../lib si3n4_lpcvd.pl  # DCS + NH3 LPCVD Si3N4

=head1 INSTALLATION

    cd Physics-CVD
    perl Makefile.PL
    make
    make test
    make install    # optional, installs system-wide

Optional dependencies:

    OpenFOAM  -> sudo apt install openfoam
    LAMMPS    -> sudo apt install lammps
    Cantera   -> pip install cantera
    PDL       -> cpanm PDL
    PDL::Graphics::Gnuplot -> cpanm PDL::Graphics::Gnuplot

=head1 LICENSE

This module is free software; you can redistribute it under the same terms
as Perl itself.

=head1 SEE ALSO

=over 4

=item C<Physics::CVD::Chemistry>

=item C<Physics::CVD::KMC>

=item C<Physics::CVD::Reactor>

=item C<Physics::CVD::Transport>

=item C<Physics::CVD::Film>

=item C<Physics::CVD::Interface::OpenFOAM>

=item C<Physics::CVD::Interface::LAMMPS>

=item C<Physics::CVD::Interface::Cantera>

=back

=cut
