package Physics::CPD;

use strict;
use warnings;
use Moo;
use Carp qw(croak);

our $VERSION = '0.03';

#---------------------------------------------------------------------------
# Physical constants (SI units, CODATA 2018)
#---------------------------------------------------------------------------
use constant {
    ELEMENTARY_CHARGE => 1.602176634e-19,    # C
    ELECTRON_MASS     => 9.1093837015e-31,   # kg
    PROTON_MASS       => 1.67262192369e-27,  # kg
    ATOMIC_MASS_UNIT  => 1.66053906660e-27,  # kg
    BOLTZMANN         => 1.380649e-23,        # J/K
    VACUUM_PERMITTIVITY => 8.8541878128e-12,  # F/m
    VACUUM_PERMEABILITY => 1.25663706212e-6,  # H/m
    SPEED_OF_LIGHT    => 299792458,           # m/s
    EV_TO_JOULE       => 1.602176634e-19,     # J per eV
    EV_TO_KELVIN      => 11604.51812,         # K per eV
    PI                => 3.14159265358979,
};

# atomic species table: name => [ mass number A, charge number Z ]
my %SPECIES = (
    'e'   => [ 5.48579909065e-4, -1 ],
    'H'   => [ 1.00782503207,     1 ],
    'p'   => [ 1.00727646688,     1 ],
    'D'   => [ 2.01410177812,     1 ],
    'T'   => [ 3.01604928199,     1 ],
    'He'  => [ 4.002602,          2 ],
    'He3' => [ 3.01602932,        2 ],
    'He4' => [ 4.002602,          2 ],
    'C'   => [ 12.011,            6 ],
    'O'   => [ 15.999,            8 ],
);

#---------------------------------------------------------------------------
# Attributes  (all plasma quantities are given in SI unless noted)
#   * temperatures are specified in electron-volts (eV), the plasma standard
#---------------------------------------------------------------------------
has electron_density => (        # n_e  [m^-3]
    is      => 'rw',
    default => sub { 1e20 },
);

has electron_temperature => (    # T_e  [eV]
    is      => 'rw',
    default => sub { 1000 },
);

has ion_temperature => (         # T_i  [eV]  (defaults to T_e)
    is      => 'rw',
    lazy    => 1,
    default => sub { $_[0]->electron_temperature },
);

has magnetic_field => (          # B  [T]
    is      => 'rw',
    default => sub { 1 },
);

has ion_species => (             # chemical symbol, see %SPECIES
    is      => 'rw',
    default => sub { 'H' },
);

has ion_mass => (                # m_i  [kg]
    is      => 'rw',
    lazy    => 1,
    builder => '_build_ion_mass',
);

has ion_charge => (              # Z  (charge number)
    is      => 'rw',
    lazy    => 1,
    builder => '_build_ion_charge',
);

sub _lookup_species {
    my ($self) = @_;
    my $s = $SPECIES{ $self->ion_species }
        or croak "Unknown ion species '" . $self->ion_species . "'";
    return $s;
}

sub _build_ion_mass {
    my ($self) = @_;
    return $self->_lookup_species->[0] * ATOMIC_MASS_UNIT;
}

sub _build_ion_charge {
    my ($self) = @_;
    return $self->_lookup_species->[1];
}

#---------------------------------------------------------------------------
# Temperature / energy helpers
#---------------------------------------------------------------------------
sub electron_temperature_joules { $_[0]->electron_temperature * EV_TO_JOULE }
sub ion_temperature_joules      { $_[0]->ion_temperature      * EV_TO_JOULE }
sub electron_temperature_kelvin { $_[0]->electron_temperature * EV_TO_KELVIN }
sub ion_temperature_kelvin      { $_[0]->ion_temperature      * EV_TO_KELVIN }

# quasineutral ion density  Z * n_i = n_e
sub ion_density {
    my ($self) = @_;
    return $self->electron_density / abs( $self->ion_charge );
}

sub mass_density {              # ion mass density  rho  [kg/m^3]
    my ($self) = @_;
    return $self->ion_density * $self->ion_mass;
}

#---------------------------------------------------------------------------
# Characteristic frequencies
#---------------------------------------------------------------------------
# Electron plasma (Langmuir) frequency  [rad/s]
sub electron_plasma_frequency {
    my ($self) = @_;
    my $ne = $self->electron_density;
    return sqrt( $ne * ELEMENTARY_CHARGE**2
                 / ( VACUUM_PERMITTIVITY * ELECTRON_MASS ) );
}
sub electron_plasma_frequency_hz { $_[0]->electron_plasma_frequency / ( 2 * PI ) }

# Ion plasma frequency  [rad/s]
sub ion_plasma_frequency {
    my ($self) = @_;
    my $ni = $self->ion_density;
    my $q  = $self->ion_charge * ELEMENTARY_CHARGE;
    return sqrt( $ni * $q**2 / ( VACUUM_PERMITTIVITY * $self->ion_mass ) );
}
sub ion_plasma_frequency_hz { $_[0]->ion_plasma_frequency / ( 2 * PI ) }

# Electron cyclotron (gyro) frequency  [rad/s]
sub electron_cyclotron_frequency {
    my ($self) = @_;
    return ELEMENTARY_CHARGE * $self->magnetic_field / ELECTRON_MASS;
}
sub electron_cyclotron_frequency_hz { $_[0]->electron_cyclotron_frequency / ( 2 * PI ) }

# Ion cyclotron frequency  [rad/s]
sub ion_cyclotron_frequency {
    my ($self) = @_;
    return abs( $self->ion_charge ) * ELEMENTARY_CHARGE * $self->magnetic_field
        / $self->ion_mass;
}
sub ion_cyclotron_frequency_hz { $_[0]->ion_cyclotron_frequency / ( 2 * PI ) }

#---------------------------------------------------------------------------
# Characteristic lengths and speeds
#---------------------------------------------------------------------------
# Debye length  [m]
sub debye_length {
    my ($self) = @_;
    return sqrt( VACUUM_PERMITTIVITY * $self->electron_temperature_joules
                 / ( $self->electron_density * ELEMENTARY_CHARGE**2 ) );
}

# Electron thermal speed  v = sqrt(k T / m)  [m/s]
sub electron_thermal_velocity {
    my ($self) = @_;
    return sqrt( $self->electron_temperature_joules / ELECTRON_MASS );
}

# Ion thermal speed  v = sqrt(k T / m)  [m/s]
sub ion_thermal_velocity {
    my ($self) = @_;
    return sqrt( $self->ion_temperature_joules / $self->ion_mass );
}

# Electron Larmor (gyro) radius using thermal speed  [m]
sub electron_gyroradius {
    my ($self) = @_;
    return ELECTRON_MASS * $self->electron_thermal_velocity
        / ( ELEMENTARY_CHARGE * $self->magnetic_field );
}

# Ion Larmor (gyro) radius using thermal speed  [m]
sub ion_gyroradius {
    my ($self) = @_;
    return $self->ion_mass * $self->ion_thermal_velocity
        / ( abs( $self->ion_charge ) * ELEMENTARY_CHARGE * $self->magnetic_field );
}

# Alfven speed  v_A = B / sqrt(mu0 rho)  [m/s]
sub alfven_velocity {
    my ($self) = @_;
    return $self->magnetic_field
        / sqrt( VACUUM_PERMEABILITY * $self->mass_density );
}

# Ion-acoustic (sound) speed  c_s = sqrt(Z k T_e / m_i)  [m/s]
sub ion_sound_speed {
    my ($self) = @_;
    return sqrt( abs( $self->ion_charge ) * $self->electron_temperature_joules
                 / $self->ion_mass );
}

#---------------------------------------------------------------------------
# Pressures, beta and stored-energy density
#---------------------------------------------------------------------------
# Kinetic plasma pressure  p = n_e k T_e + n_i k T_i   [Pa]
sub plasma_pressure {
    my ($self) = @_;
    return $self->electron_density * $self->electron_temperature_joules
        +  $self->ion_density      * $self->ion_temperature_joules;
}

# Magnetic pressure  B^2 / (2 mu0)  [Pa]
sub magnetic_pressure {
    my ($self) = @_;
    return $self->magnetic_field**2 / ( 2 * VACUUM_PERMEABILITY );
}

# Plasma beta = kinetic pressure / magnetic pressure  (dimensionless)
sub plasma_beta {
    my ($self) = @_;
    return $self->plasma_pressure / $self->magnetic_pressure;
}

#---------------------------------------------------------------------------
# Collisional parameters (NRL Plasma Formulary)
#---------------------------------------------------------------------------
# Coulomb logarithm for electron-ion collisions
sub coulomb_logarithm {
    my ($self) = @_;
    my $ne_cm3 = $self->electron_density * 1e-6;   # convert to cm^-3
    my $Te     = $self->electron_temperature;      # eV
    my $Z      = abs( $self->ion_charge );
    my $ln;
    if ( $Te > 10 * $Z**2 ) {
        $ln = 24 - log( sqrt($ne_cm3) / $Te );
    }
    else {
        $ln = 23 - log( sqrt($ne_cm3) * $Z * $Te**-1.5 );
    }
    return $ln < 1 ? 1 : $ln;
}

# Electron-ion collision frequency  [s^-1]
sub collision_frequency {
    my ($self) = @_;
    my $ne_cm3 = $self->electron_density * 1e-6;
    my $Te     = $self->electron_temperature;
    my $Z      = abs( $self->ion_charge );
    return 2.91e-6 * $Z * $ne_cm3 * $self->coulomb_logarithm * $Te**-1.5;
}

# Electron mean free path  [m]
sub mean_free_path {
    my ($self) = @_;
    my $nu = $self->collision_frequency;
    return $nu > 0 ? $self->electron_thermal_velocity / $nu : 'inf';
}

# Parallel Spitzer resistivity  [Ohm m]
sub spitzer_resistivity {
    my ($self) = @_;
    my $Z  = abs( $self->ion_charge );
    my $Te = $self->electron_temperature;   # eV
    return 5.2e-5 * $Z * $self->coulomb_logarithm * $Te**-1.5;
}

#---------------------------------------------------------------------------
# Dimensionless plasma parameter
#---------------------------------------------------------------------------
# Number of particles in a Debye sphere  N_D = (4/3) pi n lambda_D^3
sub plasma_parameter {
    my ($self) = @_;
    return ( 4 / 3 ) * PI * $self->electron_density * $self->debye_length**3;
}

#---------------------------------------------------------------------------
# Reporting
#---------------------------------------------------------------------------
sub as_hash {
    my ($self) = @_;
    return {
        electron_density              => $self->electron_density,
        electron_temperature_eV       => $self->electron_temperature,
        ion_temperature_eV            => $self->ion_temperature,
        magnetic_field_T              => $self->magnetic_field,
        ion_species                   => $self->ion_species,
        electron_plasma_frequency_Hz  => $self->electron_plasma_frequency_hz,
        ion_plasma_frequency_Hz       => $self->ion_plasma_frequency_hz,
        electron_cyclotron_freq_Hz    => $self->electron_cyclotron_frequency_hz,
        ion_cyclotron_frequency_Hz    => $self->ion_cyclotron_frequency_hz,
        debye_length_m                => $self->debye_length,
        electron_gyroradius_m         => $self->electron_gyroradius,
        ion_gyroradius_m              => $self->ion_gyroradius,
        electron_thermal_velocity_ms  => $self->electron_thermal_velocity,
        ion_thermal_velocity_ms       => $self->ion_thermal_velocity,
        alfven_velocity_ms            => $self->alfven_velocity,
        ion_sound_speed_ms            => $self->ion_sound_speed,
        plasma_pressure_Pa            => $self->plasma_pressure,
        magnetic_pressure_Pa          => $self->magnetic_pressure,
        plasma_beta                   => $self->plasma_beta,
        coulomb_logarithm             => $self->coulomb_logarithm,
        collision_frequency_Hz        => $self->collision_frequency,
        mean_free_path_m              => $self->mean_free_path,
        spitzer_resistivity_Ohm_m     => $self->spitzer_resistivity,
        plasma_parameter              => $self->plasma_parameter,
    };
}

sub report {
    my ($self) = @_;
    my @lines;
    push @lines, "== Computational Plasma Dynamics (Physics::CPD) ==";
    push @lines, sprintf( "  electron density      n_e = %.3e m^-3", $self->electron_density );
    push @lines, sprintf( "  electron temperature  T_e = %.3g eV  (%.3g K)",
        $self->electron_temperature, $self->electron_temperature_kelvin );
    push @lines, sprintf( "  ion temperature       T_i = %.3g eV  (%s, Z=%d)",
        $self->ion_temperature, $self->ion_species, $self->ion_charge );
    push @lines, sprintf( "  magnetic field        B   = %.3g T", $self->magnetic_field );
    push @lines, "  -- derived quantities --";
    push @lines, sprintf( "  plasma frequency  f_pe    = %.3e Hz", $self->electron_plasma_frequency_hz );
    push @lines, sprintf( "  e- cyclotron freq f_ce    = %.3e Hz", $self->electron_cyclotron_frequency_hz );
    push @lines, sprintf( "  ion cyclotron freq f_ci   = %.3e Hz", $self->ion_cyclotron_frequency_hz );
    push @lines, sprintf( "  Debye length      lambda_D= %.3e m", $self->debye_length );
    push @lines, sprintf( "  e- gyroradius     r_Le    = %.3e m", $self->electron_gyroradius );
    push @lines, sprintf( "  ion gyroradius    r_Li    = %.3e m", $self->ion_gyroradius );
    push @lines, sprintf( "  Alfven speed      v_A     = %.3e m/s", $self->alfven_velocity );
    push @lines, sprintf( "  ion sound speed   c_s     = %.3e m/s", $self->ion_sound_speed );
    push @lines, sprintf( "  plasma pressure   p       = %.3e Pa", $self->plasma_pressure );
    push @lines, sprintf( "  plasma beta       beta    = %.3f %%", 100 * $self->plasma_beta );
    push @lines, sprintf( "  Coulomb log       lnLambda= %.2f", $self->coulomb_logarithm );
    push @lines, sprintf( "  plasma parameter  N_D     = %.3e", $self->plasma_parameter );
    return join( "\n", @lines ) . "\n";
}

1;

__END__

=head1 NAME

Physics::CPD - Computational Plasma Dynamics: fundamental magnetised-plasma parameters

=head1 SYNOPSIS

    use Physics::CPD;

    my $plasma = Physics::CPD->new(
        electron_density     => 8e19,   # m^-3
        electron_temperature => 4000,   # eV
        ion_temperature      => 2000,   # eV
        magnetic_field       => 2.5,    # T
        ion_species          => 'H',
    );

    printf "Debye length   = %.3e m\n",  $plasma->debye_length;
    printf "plasma beta    = %.2f %%\n", 100 * $plasma->plasma_beta;
    print  $plasma->report;

=head1 DESCRIPTION

C<Physics::CPD> is a lightweight, pure-Perl package for generic computational
plasma dynamics.  It models a quasineutral, magnetised plasma from a small set
of state variables (density, electron/ion temperature, magnetic field and ion
species) and derives the standard characteristic frequencies, lengths, speeds,
pressures and collisional parameters used throughout magnetic-confinement
fusion and space-plasma physics.

Temperatures are supplied in B<electron-volts> (eV), the customary plasma unit;
all other quantities use SI.  The class is built with L<Moo> so every state
variable is a read/write accessor and derived quantities are ordinary methods.

The distribution also includes L<Physics::CPD::Stellarator>, a fusion-reactor
modelling submodule that adds stellarator geometry, Wendelstein 7-X defaults,
ISS04 confinement scaling, Sudo density limits and theoretical D-T fusion-power
estimates.

=head1 ATTRIBUTES

=over 4

=item electron_density  (n_e, m^-3, default 1e20)

=item electron_temperature  (T_e, eV, default 1000)

=item ion_temperature  (T_i, eV, defaults to T_e)

=item magnetic_field  (B, tesla, default 1)

=item ion_species  (chemical symbol; H, D, T, He, He3, C, O, ..., default 'H')

=item ion_mass  (kg, derived from the species unless overridden)

=item ion_charge  (Z, derived from the species unless overridden)

=back

=head1 METHODS

Frequencies (rad/s, with C<_hz> variants):
C<electron_plasma_frequency>, C<ion_plasma_frequency>,
C<electron_cyclotron_frequency>, C<ion_cyclotron_frequency>.

Lengths and speeds:
C<debye_length>, C<electron_gyroradius>, C<ion_gyroradius>,
C<electron_thermal_velocity>, C<ion_thermal_velocity>,
C<alfven_velocity>, C<ion_sound_speed>.

Pressures and energetics:
C<plasma_pressure>, C<magnetic_pressure>, C<plasma_beta>.

Collisional transport (NRL Plasma Formulary):
C<coulomb_logarithm>, C<collision_frequency>, C<mean_free_path>,
C<spitzer_resistivity>.

Other: C<ion_density>, C<mass_density>, C<plasma_parameter>,
C<as_hash>, C<report>.

=head1 SEE ALSO

L<Physics::CPD::Stellarator>

=head1 AUTHOR

Generated for the Physics-CPD project.

=head1 LICENSE

Copyright (C) 2026 the Physics-CPD authors.

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.  See L<https://www.gnu.org/licenses/gpl-3.0.html>.

=cut
