package Physics::PVD;
use strict;
use warnings;
use Carp;

our $VERSION = '0.02';

use Physics::PVD::KMC;
use Physics::PVD::DSMC;
use Physics::PVD::Film;

# Optional interface modules loaded on demand
my %INTERFACES = (
    openfoam   => 'Physics::PVD::Interface::OpenFOAM',
    lammps     => 'Physics::PVD::Interface::LAMMPS',
    quantumatk => 'Physics::PVD::Interface::QuantumATK',
);

sub new {
    my ($class, %opts) = @_;
    my $self = bless {
        method      => $opts{method}    // 'kmc',      # kmc | dsmc | hybrid
        temperature => $opts{temperature} // 300,      # K
        pressure    => $opts{pressure}   // 1e-3,      # Pa (base pressure)
        verbose     => $opts{verbose}    // 0,
        seed        => $opts{seed}       // int(rand(2**31)),
        _engines    => {},
        _film       => undef,
    }, $class;

    srand($self->{seed});
    return $self;
}

# Configure simulation parameters
sub configure {
    my ($self, %params) = @_;
    for my $key (keys %params) {
        $self->{$key} = $params{$key};
    }
    return $self;
}

# Get/create the KMC engine
sub kmc {
    my ($self, %opts) = @_;
    unless ($self->{_engines}{kmc}) {
        $self->{_engines}{kmc} = Physics::PVD::KMC->new(
            temperature => $self->{temperature},
            seed        => $self->{seed},
            verbose     => $self->{verbose},
            %opts,
        );
    }
    return $self->{_engines}{kmc};
}

# Get/create the DSMC engine
sub dsmc {
    my ($self, %opts) = @_;
    unless ($self->{_engines}{dsmc}) {
        $self->{_engines}{dsmc} = Physics::PVD::DSMC->new(
            pressure    => $self->{pressure},
            temperature => $self->{temperature},
            seed        => $self->{seed},
            verbose     => $self->{verbose},
            %opts,
        );
    }
    return $self->{_engines}{dsmc};
}

# Get/create the Film object
sub film {
    my ($self, %opts) = @_;
    unless ($self->{_film}) {
        $self->{_film} = Physics::PVD::Film->new(%opts);
    }
    return $self->{_film};
}

# Load and return an interface module
sub interface {
    my ($self, $name, %opts) = @_;
    $name = lc($name);
    croak "Unknown interface '$name'. Available: " . join(', ', sort keys %INTERFACES)
        unless exists $INTERFACES{$name};

    my $module = $INTERFACES{$name};
    eval "require $module" or croak "Failed to load $module: $@";
    return $module->new(%opts);
}

# Run a complete PVD simulation
sub run {
    my ($self, %opts) = @_;
    my $method = $opts{method} // $self->{method};

    if ($method eq 'kmc') {
        return $self->_run_kmc(%opts);
    } elsif ($method eq 'dsmc') {
        return $self->_run_dsmc(%opts);
    } elsif ($method eq 'hybrid') {
        return $self->_run_hybrid(%opts);
    } else {
        croak "Unknown simulation method: $method";
    }
}

sub _run_kmc {
    my ($self, %opts) = @_;
    my $kmc = $self->kmc;
    my $steps = $opts{steps} // 10000;
    my $flux  = $opts{flux}  // 1e14;   # atoms/cm²/s

    $kmc->set_flux($flux) if $flux;
    $kmc->run(steps => $steps);
    $self->{_film} = $kmc->get_film;
    return $self->{_film};
}

sub _run_dsmc {
    my ($self, %opts) = @_;
    my $dsmc = $self->dsmc;
    my $timesteps = $opts{timesteps} // 5000;

    $dsmc->run(timesteps => $timesteps);
    return $dsmc->get_flux_distribution;
}

sub _run_hybrid {
    my ($self, %opts) = @_;
    # Hybrid: DSMC for transport → KMC for film growth
    my $flux_dist = $self->_run_dsmc(%opts);
    my $kmc = $self->kmc;
    $kmc->set_angular_distribution($flux_dist);
    return $self->_run_kmc(%opts);
}

# Convenience: list available methods
sub available_methods { return qw(kmc dsmc hybrid); }

# Convenience: list available interfaces
sub available_interfaces { return sort keys %INTERFACES; }

1;

__END__

=head1 NAME

Physics::PVD - Physical Vapor Deposition simulation framework

=head1 SYNOPSIS

    use Physics::PVD;

    my $pvd = Physics::PVD->new(
        method      => 'kmc',
        temperature => 600,   # K
        pressure    => 5e-3,  # Pa
    );

    # Configure and run KMC film growth
    my $kmc = $pvd->kmc(lattice_size => [100, 100, 50]);
    $kmc->add_species(name => 'Ta', mass => 180.95, binding_energy => 8.1);
    $kmc->deposit(flux => 1e14, time => 60, angle => 0);

    # Get results
    my $film = $kmc->get_film;
    printf "Thickness: %.1f nm\n", $film->thickness;
    printf "Roughness: %.2f nm\n", $film->roughness;

=head1 DESCRIPTION

Physics::PVD provides a Perl framework for simulating Physical Vapor
Deposition (PVD) processes. It combines:

=over 4

=item * Kinetic Monte Carlo (KMC)

BKL rejection-free atomistic film growth: adsorption, surface diffusion,
desorption, Ehrlich-Schwoebel step-edge barriers, oblique-angle deposition,
and multi-species films.

=item * Direct Simulation Monte Carlo (DSMC)

Rarefied vapor transport using Thompson energy distributions, cos^n angular
emission, variable hard-sphere collisions, and Knudsen-number characterization.

=item * Hybrid coupling

DSMC flux/energy/angle distributions can be fed into the KMC film growth
engine for coupled transport-plus-growth simulations.

=item * External interfaces (optional)

Interfaces to OpenFOAM (C<dsmcFoam+>), LAMMPS (molecular dynamics
deposition/sputtering/annealing), and QuantumATK (DFT/DFTB binding energies
and sputtering yields) enable multi-scale workflows.

=back

=head1 VERSION

Version 0.02

=head1 METHODS

=head2 new(%options)

Create a new Physics::PVD simulation controller.

    my $pvd = Physics::PVD->new(
        method      => 'kmc',       # 'kmc' | 'dsmc' | 'hybrid'
        temperature => 300,          # substrate temperature (K)
        pressure    => 1e-3,         # base pressure (Pa)
        verbose     => 0,            # print progress messages
        seed        => 12345,        # RNG seed for reproducibility
    );

Defaults:

=over 4

=item * method: C<'kmc'>

=item * temperature: C<300> K

=item * pressure: C<1e-3> Pa

=item * verbose: C<0>

=item * seed: random 31-bit integer

=back

=head2 configure(%params)

Update simulation parameters after construction.

    $pvd->configure(temperature => 700, pressure => 2e-3);

=head2 kmc(%options)

Get or create the L<Physics::PVD::KMC> engine. Options are forwarded to the
engine constructor and override the controller defaults.

    my $kmc = $pvd->kmc(
        lattice_size => [100, 100, 50],
        temperature  => 600,
    );

=head2 dsmc(%options)

Get or create the L<Physics::PVD::DSMC> engine. Options are forwarded to the
engine constructor and override the controller defaults.

    my $dsmc = $pvd->dsmc(
        n_particles => 10000,
        pressure    => 2.0,
    );

=head2 film(%options)

Get or create a L<Physics::PVD::Film> analysis object.

    my $film = $pvd->film;
    printf "Thickness: %.1f nm\n", $film->thickness;

=head2 interface($name, %options)

Load and instantiate an external interface module on demand. C<$name> must
be one of the interfaces returned by L</available_interfaces>.

    my $lmp  = $pvd->interface('lammps',
        executable => '/usr/bin/lmp',
    );
    my $foam = $pvd->interface('openfoam',
        case_dir => './my_case',
    );
    my $atk  = $pvd->interface('quantumatk',
        python_path => 'atkpython',
    );

=head2 run(%options)

Run a complete PVD simulation using the configured or requested method.

    # KMC film growth
    my $film = $pvd->run(method => 'kmc', steps => 50000, flux => 1e14);

    # DSMC vapor transport
    my $dist = $pvd->run(method => 'dsmc', timesteps => 5000);

    # Hybrid DSMC -> KMC
    my $film = $pvd->run(
        method    => 'hybrid',
        steps     => 50000,
        timesteps => 2000,
        flux      => 5e13,
    );

=head2 available_methods()

Return the list of supported simulation methods.

    my @methods = $pvd->available_methods;
    # ('kmc', 'dsmc', 'hybrid')

=head2 available_interfaces()

Return the list of available external tool interfaces.

    my @interfaces = $pvd->available_interfaces;
    # ('lammps', 'openfoam', 'quantumatk')

=head1 SUBMODULES

=over 4

=item * L<Physics::PVD::KMC>

Kinetic Monte Carlo engine for atomistic film growth.

=item * L<Physics::PVD::DSMC>

Direct Simulation Monte Carlo engine for vapor transport.

=item * L<Physics::PVD::Film>

Film analysis: thickness, roughness, density, porosity, composition profiles,
and export to XYZ and LAMMPS data formats.

=item * L<Physics::PVD::Interface::OpenFOAM>

Generate and run C<dsmcFoam+> cases.

=item * L<Physics::PVD::Interface::LAMMPS>

Generate and run LAMMPS deposition, sputtering, and annealing simulations.

=item * L<Physics::PVD::Interface::QuantumATK>

Generate QuantumATK scripts for binding energies, sputtering yields, and
adatom diffusion.

=back

=head1 INSTALLATION

From the source distribution:

    cd Physics-PVD
    perl Makefile.PL
    make
    make test
    make install              # or: make install DESTDIR=~/perl5

Install to a local directory without root privileges:

    perl Makefile.PL INSTALL_BASE=~/perl5
    make && make test && make install
    export PERL5LIB=~/perl5/lib/perl5:$PERL5LIB

Once published on CPAN:

    cpanm Physics::PVD

=head2 Prerequisites

=over 4

=item * Perl 5.16 or newer.

=item * Core modules: C<Carp>, C<POSIX>, C<List::Util>, C<File::Path>,
C<File::Spec>, C<File::Temp>.

=item * C<Test::More> for running the test suite.

=back

=head1 OPTIONAL DEPENDENCIES

These are only required if you use the corresponding interface or examples:

=over 4

=item * PDL and C<PDL::Graphics::Gnuplot> for visualization examples.

=item * OpenFOAM executables C<blockMesh>, C<dsmcInitialise>, and
C<dsmcFoam+> for L<Physics::PVD::Interface::OpenFOAM>.

=item * LAMMPS with the C<MANYBODY> package for EAM/MEAM/Tersoff potentials
in L<Physics::PVD::Interface::LAMMPS>.

=item * QuantumATK with a commercial license from Synopsys and the
C<atkpython> interpreter for L<Physics::PVD::Interface::QuantumATK>.

=item * Interatomic potentials from the NIST Interatomic Potentials
Repository (C<Ta.eam.alloy>, C<Cu.eam.alloy>, C<CuTa.eam.alloy>, etc.).

=back

=head1 EXAMPLES

=head2 Basic KMC film growth

    use Physics::PVD;

    my $pvd = Physics::PVD->new(temperature => 600);
    my $kmc = $pvd->kmc(lattice_size => [50, 50, 30]);
    $kmc->add_species(name => 'Ta', mass => 180.95, binding_energy => 8.1);
    $kmc->deposit(flux => 1e14, time => 30);

    my $film = $kmc->get_film;
    printf "Thickness: %.1f nm\n", $film->thickness;
    $film->export_xyz('ta_film.xyz');

See F<examples/kmc_basic.pl>.

=head2 DSMC vapor transport

    use Physics::PVD;

    my $pvd  = Physics::PVD->new(pressure => 2.0);
    my $dsmc = $pvd->dsmc(n_particles => 5000, target_material => 'Ta');
    $dsmc->run(timesteps => 3000);

    printf "Knudsen: %.2f\n", $dsmc->knudsen_number;
    printf "Mean arrival energy: %.2f eV\n", $dsmc->mean_arrival_energy;

See F<examples/dsmc_transport.pl>.

=head2 Hybrid DSMC to KMC

    use Physics::PVD;

    my $pvd = Physics::PVD->new(
        method => 'hybrid', temperature => 400, pressure => 1.5,
    );
    my $film = $pvd->run(steps => 50000, timesteps => 2000, flux => 5e13);
    printf "Film: %.1f nm, roughness: %.2f nm\n",
           $film->thickness, $film->roughness;

See F<examples/hybrid_dsmc_kmc.pl>.

=head2 LAMMPS deposition MD

    use Physics::PVD;

    my $pvd = Physics::PVD->new;
    my $lmp = $pvd->interface('lammps',
        substrate_material => 'Cu',
        deposit_species    => 'Ta',
        potential_file     => 'CuTa.eam.alloy',
    );
    $lmp->generate_input(template => 'deposition',
                         params => {n_deposits => 100});
    $lmp->run;
    my $frames = $lmp->parse_dump;

See F<examples/lammps_pvd.pl>.

=head1 PHYSICAL MODELS

=head2 Kinetic Monte Carlo (KMC)

The BKL (Bortz-Kalos-Lebowitz, 1975) rejection-free algorithm:

=over 4

=item 1. Build a rate catalog from all possible events using Arrhenius rates:
C<k = nu_0 * exp(-E_a / k_B T)>.

=item 2. Select an event with probability proportional to its rate:
C<P(event_i) = k_i / sum(k_j)>.

=item 3. Advance physical time by C<delta_t = -ln(u) / R_total> where
C<u> is uniform on C<(0,1)> and C<R_total> is the total rate.

=back

Implemented events: adsorption (rate proportional to flux), surface diffusion,
desorption (barrier equals binding energy), and Ehrlich-Schwoebel descent.

=head2 Direct Simulation Monte Carlo (DSMC)

Bird's method (1994) for rarefied gas dynamics:

=over 4

=item 1. Particle emission from the target with Thompson energy distribution
C<P(E) proportional to E / (E + E_b)^3> and cosine^n angular distribution.

=item 2. Free flight for a time step C<delta_t>.

=item 3. Collision using the null-collision method with variable hard-sphere
cross-section: C<P_coll = n_gas * sigma * v_rel * delta_t>.

=item 4. Energy transfer via hard-sphere scattering in the center-of-mass frame.

=back

=head2 Knudsen number regimes

    Kn > 10        Free-molecular   Ballistic, line-of-sight transport
    0.1 < Kn < 10  Transitional     Partial thermalization
    Kn < 0.1       Continuum        Fully diffusive (continuum mechanics)

=head1 BUGS AND SUPPORT

Please report bugs and feature requests at the repository:

    https://github.com/your-org/Physics-PVD.git

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself (Artistic License 2.0 / GPL v1+).

=head1 SEE ALSO

=over 4

=item * L<Physics::PVD::KMC>

=item * L<Physics::PVD::DSMC>

=item * L<Physics::PVD::Film>

=item * L<Physics::PVD::Interface::OpenFOAM>

=item * L<Physics::PVD::Interface::LAMMPS>

=item * L<Physics::PVD::Interface::QuantumATK>

=back

=cut
