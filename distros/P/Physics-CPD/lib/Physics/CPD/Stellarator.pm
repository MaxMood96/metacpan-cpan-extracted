package Physics::CPD::Stellarator;

use strict;
use warnings;
use Moo;
use Carp qw(croak);

extends 'Physics::CPD';

our $VERSION = '0.03';

use constant PI => 3.14159265358979;

#---------------------------------------------------------------------------
# Fusion (deuterium-tritium) reaction data
#---------------------------------------------------------------------------
# Energy released per D-T fusion reaction  T(d,n)4He  [MeV]
use constant {
    DT_ENERGY_MEV         => 17.59,          # total energy per reaction
    DT_ALPHA_ENERGY_MEV   => 3.52,           # 4He alpha (charged, heats plasma)
    DT_NEUTRON_ENERGY_MEV => 14.07,          # neutron (escapes to the blanket)
    MEV_TO_JOULE          => 1.602176634e-13,
};

# Bosch-Hale parametrisation of the Maxwell-averaged reactivity <sigma v> for
# T(d,n)4He (H.-S. Bosch & G.M. Hale, Nucl. Fusion 32 (1992) 611).  Valid for
# ion temperatures 0.2-100 keV; accurate to better than ~0.25%.
my $DT_BG   = 34.3827;      # Gamow constant  [sqrt(keV)]
my $DT_MRC2 = 1124656;      # reduced-mass energy m_r c^2  [keV]
my @DT_C    = (             # C1 .. C7
    1.17302e-9,  1.51361e-2,  7.51886e-2,  4.60643e-3,
    1.35000e-2, -1.06750e-4,  1.36600e-5,
);

#---------------------------------------------------------------------------
# Default Wendelstein 7-X-like boundary (VMEC-style Fourier series).
#
#   R(u,v) = sum  Rbc(m,n) cos(m u - n Nfp v)
#   Z(u,v) = sum  Zbs(m,n) sin(m u - n Nfp v)
#
# u = poloidal angle, v = toroidal angle, Nfp = number of field periods.
# Each element is [ m, n, Rbc, Zbs ] in metres.  The m=0 terms define the
# helical magnetic axis; m>=1 terms define the rotating, bean-shaped cross
# section that gives the stellarator its characteristic five-fold twist.
#---------------------------------------------------------------------------
sub _default_boundary_coeffs {
    return [
        [ 0, 0,  5.50,  0.00 ],   # major radius R0
        [ 0, 1, -0.28, -0.18 ],   # major-radius breathing + axis excursion
        [ 1, 0,  0.50,  0.55 ],   # base (elongated) cross section
        [ 1, 1,  0.26, -0.28 ],   # rotating elongation -> bean shape + twist
        [ 2, 0, -0.05,  0.04 ],   # triangularity
        [ 2, 1, -0.05,  0.04 ],   # triangularity modulation
    ];
}

#---------------------------------------------------------------------------
# Device attributes  (defaults describe Wendelstein 7-X)
#---------------------------------------------------------------------------
has config_name => (
    is      => 'rw',
    default => sub { 'Wendelstein 7-X (standard EIM configuration)' },
);

has major_radius => (            # R0  [m]
    is      => 'rw',
    default => sub { 5.5 },
);

has minor_radius => (            # a  [m]
    is      => 'rw',
    default => sub { 0.53 },
);

has num_field_periods => (       # Nfp
    is      => 'rw',
    default => sub { 5 },
);

has iota => (                    # rotational transform (effective, ~2/3 radius)
    is      => 'rw',
    default => sub { 0.96 },
);

has heating_power => (           # P  [MW]
    is      => 'rw',
    default => sub { 10 },
);

has num_nonplanar_coils => (
    is      => 'rw',
    default => sub { 50 },
);

has num_planar_coils => (
    is      => 'rw',
    default => sub { 20 },
);

has beta_limit => (              # design MHD beta limit
    is      => 'rw',
    default => sub { 0.05 },
);

has pulse_length => (            # [s]
    is      => 'rw',
    default => sub { 1800 },
);

has gyrotron_frequency => (      # ECRH gyrotron frequency  [Hz]
    is      => 'rw',
    default => sub { 140e9 },
);

has dt_fuel_fraction => (        # D-T fuel-ion fraction of n_e (0..1)
    is      => 'rw',             # 1.0 = pure 50:50 D-T; lower models dilution
    default => sub { 1.0 },
);

has boundary_coeffs => (
    is      => 'rw',
    default => \&_default_boundary_coeffs,
);

# --- coil-geometry styling (used by the 3-D diagram) ---
has coil_radius     => ( is => 'rw', default => sub { 0.95 } );  # [m]
has coil_elongation => ( is => 'rw', default => sub { 1.25 } );
has coil_tilt       => ( is => 'rw', default => sub { 0.16 } );  # rad

# W7-X runs a strong field; override the CPD default of 1 T.
has '+magnetic_field' => ( default => sub { 2.5 } );

#---------------------------------------------------------------------------
# Basic device geometry
#---------------------------------------------------------------------------
sub aspect_ratio {
    my ($self) = @_;
    return $self->major_radius / $self->minor_radius;
}

# Toroidal angle spanned by one field period  [rad]
sub field_period_angle {
    my ($self) = @_;
    return 2 * PI / $self->num_field_periods;
}

# Plasma volume of the toroidal plasma  V = 2 pi^2 R0 a^2  [m^3]
sub plasma_volume {
    my ($self) = @_;
    return 2 * PI**2 * $self->major_radius * $self->minor_radius**2;
}

# Plasma surface area (approx.)  S = 4 pi^2 R0 a  [m^2]
sub plasma_surface_area {
    my ($self) = @_;
    return 4 * PI**2 * $self->major_radius * $self->minor_radius;
}

# Rotational transform and its inverse, the stellarator "safety factor"
sub rotational_transform { $_[0]->iota }
sub safety_factor        { 1 / $_[0]->iota }

#---------------------------------------------------------------------------
# Confinement, limits and fusion figures of merit
#---------------------------------------------------------------------------
# ISS04 international stellarator energy-confinement scaling  [s]
#   tau_E = 0.134 a^2.28 R^0.64 P^-0.61 n19^0.54 B^0.84 iota^0.41
# a,R in m; P in MW; n19 = line-averaged density in 1e19 m^-3; B in T.
sub confinement_time_iss04 {
    my ($self) = @_;
    my $a    = $self->minor_radius;
    my $R    = $self->major_radius;
    my $P    = $self->heating_power;
    my $n19  = $self->electron_density / 1e19;
    my $B    = $self->magnetic_field;
    my $iota = $self->iota;
    return 0.134
        * $a**2.28
        * $R**0.64
        * $P**-0.61
        * $n19**0.54
        * $B**0.84
        * $iota**0.41;
}

# Stored thermal plasma energy  W = (3/2) p V  [J]
sub stored_energy {
    my ($self) = @_;
    return 1.5 * $self->plasma_pressure * $self->plasma_volume;
}
sub stored_energy_MJ { $_[0]->stored_energy / 1e6 }

# Sudo density limit for stellarators  [m^-3]
#   n_max = 0.25 * sqrt( P B / (a^2 R) ) * 1e20 ;  P in MW, B in T, a,R in m.
sub sudo_density_limit {
    my ($self) = @_;
    return 0.25
        * sqrt( $self->heating_power * $self->magnetic_field
                / ( $self->minor_radius**2 * $self->major_radius ) )
        * 1e20;
}

# Fraction of the design beta limit currently used
sub beta_fraction {
    my ($self) = @_;
    return $self->plasma_beta / $self->beta_limit;
}

# Fraction of the Sudo density limit currently used
sub density_fraction {
    my ($self) = @_;
    return $self->electron_density / $self->sudo_density_limit;
}

# Lawson triple product  n T_i tau_E  [keV s m^-3]
sub triple_product {
    my ($self) = @_;
    return $self->electron_density
        * ( $self->ion_temperature / 1000 )      # eV -> keV
        * $self->confinement_time_iss04;
}

# Resonant field for electron-cyclotron heating at the gyrotron frequency
#   f = n * (e B) / (2 pi m_e)  ->  B_res = 2 pi m_e f / (n e)
sub ecrh_resonance_field {
    my ( $self, $harmonic ) = @_;
    $harmonic ||= 2;   # W7-X uses 2nd-harmonic X-mode at 2.5 T / 140 GHz
    return 2 * PI * Physics::CPD::ELECTRON_MASS() * $self->gyrotron_frequency
        / ( $harmonic * Physics::CPD::ELEMENTARY_CHARGE() );
}

#---------------------------------------------------------------------------
# Theoretical fusion power production  (assumes a 50:50 D-T plasma)
#
# W7-X itself is a hydrogen/deuterium research device and produces negligible
# fusion power; these methods estimate the power a stellarator of this design
# *would* deliver if fuelled with deuterium-tritium at the given operating
# point.  The model is a 0-D estimate that treats n_e and T_i as uniform over
# the plasma volume, using the Bosch-Hale reactivity above.
#---------------------------------------------------------------------------
# Maxwell-averaged D-T reactivity <sigma v>  [m^3/s] at ion temperature
# $Ti_keV (defaults to the model ion temperature).
sub dt_reactivity {
    my ( $self, $Ti_keV ) = @_;
    $Ti_keV = $self->ion_temperature / 1000 unless defined $Ti_keV;
    return 0 if $Ti_keV <= 0;
    my $T   = $Ti_keV;
    my $num = $T * ( $DT_C[1] + $T * ( $DT_C[3] + $T * $DT_C[5] ) );
    my $den = 1  + $T * ( $DT_C[2] + $T * ( $DT_C[4] + $T * $DT_C[6] ) );
    my $theta = $T / ( 1 - $num / $den );
    my $xi    = ( $DT_BG**2 / ( 4 * $theta ) )**( 1 / 3 );
    my $sv_cm3 = $DT_C[0] * $theta
        * sqrt( $xi / ( $DT_MRC2 * $T**3 ) ) * exp( -3 * $xi );
    return $sv_cm3 * 1e-6;   # cm^3/s -> m^3/s
}

# Total D-T fuel-ion density  n_fuel = f * n_e  [m^-3]
sub fuel_ion_density {
    my ($self) = @_;
    return $self->dt_fuel_fraction * $self->electron_density;
}

# Volumetric fusion power density  P/V = n_D n_T <sv> E_DT  [W/m^3]
# For a 50:50 mix n_D = n_T = n_fuel/2, so n_D n_T = n_fuel^2 / 4.
sub fusion_power_density {
    my ($self) = @_;
    my $nfuel = $self->fuel_ion_density;
    return 0.25 * $nfuel**2 * $self->dt_reactivity
        * DT_ENERGY_MEV * MEV_TO_JOULE;
}

# Total fusion power  [W] and [MW]
sub fusion_power    { $_[0]->fusion_power_density * $_[0]->plasma_volume }
sub fusion_power_MW { $_[0]->fusion_power / 1e6 }

# 14.07 MeV neutron power carried to the blanket  [MW]
sub neutron_power_MW {
    my ($self) = @_;
    return $self->fusion_power_MW * ( DT_NEUTRON_ENERGY_MEV / DT_ENERGY_MEV );
}

# 3.52 MeV alpha (charged-particle) power retained to heat the plasma  [MW]
sub alpha_power_MW {
    my ($self) = @_;
    return $self->fusion_power_MW * ( DT_ALPHA_ENERGY_MEV / DT_ENERGY_MEV );
}

# Average neutron wall loading over the plasma surface  [MW/m^2]
sub neutron_wall_load {
    my ($self) = @_;
    return $self->neutron_power_MW / $self->plasma_surface_area;
}

# Fusion energy gain  Q = P_fusion / P_heating  (dimensionless)
sub fusion_gain_Q {
    my ($self) = @_;
    my $p = $self->heating_power;
    return $p > 0 ? $self->fusion_power_MW / $p : 'inf';
}

#---------------------------------------------------------------------------
# Radial profiles (illustrative, peaked shapes)
#   x = r/a in [0,1];  f(x) = f0 (1 - x^2)^alpha
#---------------------------------------------------------------------------
sub density_profile {
    my ( $self, $x, $alpha ) = @_;
    $alpha = defined $alpha ? $alpha : 0.5;
    my $v = 1 - $x * $x;
    $v = 0 if $v < 0;
    return $self->electron_density * $v**$alpha;
}

sub temperature_profile {
    my ( $self, $x, $alpha ) = @_;
    $alpha = defined $alpha ? $alpha : 2.0;
    my $v = 1 - $x * $x;
    $v = 0 if $v < 0;
    return $self->electron_temperature * $v**$alpha;
}

#===========================================================================
# GEOMETRY  (pure Perl; returns array references so no PDL is required)
#===========================================================================
# Evaluate the Fourier boundary at (u,v).  A scale in [0,1] shrinks the
# poloidal (m>=1) modes toward the axis, generating nested flux surfaces.
sub boundary_point {
    my ( $self, $u, $v, $scale ) = @_;
    $scale = 1 unless defined $scale;
    my $Nfp = $self->num_field_periods;
    my ( $R, $Z ) = ( 0, 0 );
    for my $c ( @{ $self->boundary_coeffs } ) {
        my ( $m, $n, $rbc, $zbs ) = @$c;
        my $sc  = $m == 0 ? 1 : $scale;
        my $ang = $m * $u - $n * $Nfp * $v;
        $R += $sc * $rbc * cos($ang);
        $Z += $sc * $zbs * sin($ang);
    }
    return ( $R, $Z );
}

# Cartesian point on a flux surface at (u,v).
sub surface_point_xyz {
    my ( $self, $u, $v, $scale ) = @_;
    my ( $R, $Z ) = $self->boundary_point( $u, $v, $scale );
    return ( $R * cos($v), $R * sin($v), $Z );
}

# Magnetic axis: the m=0 part of the boundary (scale = 0).
# Returns ($x_aref, $y_aref, $z_aref) for $n samples over the full torus.
sub magnetic_axis {
    my ( $self, $n ) = @_;
    $n ||= 400;
    my ( @X, @Y, @Z );
    for my $i ( 0 .. $n ) {
        my $v = 2 * PI * $i / $n;
        my ( $x, $y, $z ) = $self->surface_point_xyz( 0, $v, 0 );
        push @X, $x;
        push @Y, $y;
        push @Z, $z;
    }
    return ( \@X, \@Y, \@Z );
}

# One poloidal cross section (R,Z) at toroidal angle $v.
# Returns ($R_aref, $Z_aref).
sub cross_section {
    my ( $self, $v, $nu, $scale ) = @_;
    $nu ||= 200;
    my ( @R, @Z );
    for my $i ( 0 .. $nu ) {
        my $u = 2 * PI * $i / $nu;
        my ( $r, $z ) = $self->boundary_point( $u, $v, $scale );
        push @R, $r;
        push @Z, $z;
    }
    return ( \@R, \@Z );
}

# Flux-surface grid as arrays-of-arrays [nu+1][nv+1] for X, Y, Z.
sub surface_grid {
    my ( $self, $nu, $nv, $scale ) = @_;
    $nu ||= 60;
    $nv ||= 180;
    my ( @X, @Y, @Z );
    for my $i ( 0 .. $nu ) {
        my $u = 2 * PI * $i / $nu;
        my ( @xr, @yr, @zr );
        for my $j ( 0 .. $nv ) {
            my $v = 2 * PI * $j / $nv;
            my ( $x, $y, $z ) = $self->surface_point_xyz( $u, $v, $scale );
            push @xr, $x;
            push @yr, $y;
            push @zr, $z;
        }
        push @X, \@xr;
        push @Y, \@yr;
        push @Z, \@zr;
    }
    return ( \@X, \@Y, \@Z );
}

# Modular coils as tilted, elongated rings following the magnetic axis.
# Returns a list of coil loops, each an arrayref [ $x_aref, $y_aref, $z_aref ].
sub modular_coils {
    my ( $self, $count, $npts ) = @_;
    $count ||= 2 * $self->num_field_periods;   # readable subset of the 50 coils
    $npts  ||= 120;
    my $rc    = $self->coil_radius;
    my $elong = $self->coil_elongation;
    my $tilt  = $self->coil_tilt;
    my @coils;
    for my $k ( 0 .. $count - 1 ) {
        my $phic = ( $k + 0.5 ) * 2 * PI / $count;
        my ( $Rc0, $Zc0 ) = $self->boundary_point( 0, $phic, 0 );   # axis centre
        my ( @X, @Y, @Z );
        for my $i ( 0 .. $npts ) {
            my $u   = 2 * PI * $i / $npts;
            my $dR  = $rc * cos($u);
            my $dZ  = $rc * $elong * sin($u);
            my $phi = $phic + $tilt * sin($u) / $Rc0;
            my $R   = $Rc0 + $dR;
            my $Z   = $Zc0 + $dZ;
            push @X, $R * cos($phi);
            push @Y, $R * sin($phi);
            push @Z, $Z;
        }
        push @coils, [ \@X, \@Y, \@Z ];
    }
    return @coils;
}

#===========================================================================
# PLOTTING  (lazily loads PDL + PDL::Graphics::Gnuplot; writes to a file)
#===========================================================================
sub _new_gpwin {
    my ( $self, %o ) = @_;
    eval {
        require PDL;
        require PDL::Graphics::Gnuplot;
        1;
    } or croak
        "Plotting requires PDL and PDL::Graphics::Gnuplot to be installed: $@";
    my $output = $o{output}   || 'stellarator.png';
    my $term   = $o{terminal} || 'pngcairo';
    my $size   = $o{size}     || [ 10, 8 ];
    my $w = PDL::Graphics::Gnuplot->new(
        $term,
        output => $output,
        size   => $size,
    );
    return $w;
}

# turn an arrayref (or array-of-arrays) into a PDL piddle
sub _pdl { require PDL; return PDL->pdl( $_[0] ); }

# --- 3-D diagram of the stellarator design -------------------------------
# Draws the last-closed flux surface, the helical magnetic axis and a set of
# modular field coils.  Options: output, title, size, view [az,el],
# show_axis, show_coils, coil_count, nu, nv, surface_scale.
sub plot_3d {
    my ( $self, %o ) = @_;
    my $w = $self->_new_gpwin(%o);

    my $nu    = $o{nu} || 54;
    my $nv    = $o{nv} || 170;
    my $scale = defined $o{surface_scale} ? $o{surface_scale} : 1;
    my $view  = $o{view} || [ 62, 25 ];
    my $title = defined $o{title} ? $o{title}
              : $self->config_name . ' - 3D design';

    my @items;

    # last-closed flux surface (wireframe)
    my ( $X, $Y, $Z ) = $self->surface_grid( $nu, $nv, $scale );
    push @items,
        ( { with => 'lines', lc => '#c8b0e8' },
          _pdl($X), _pdl($Y), _pdl($Z) );

    # helical magnetic axis
    if ( !defined $o{show_axis} || $o{show_axis} ) {
        my ( $ax, $ay, $az ) = $self->magnetic_axis( 400 );
        push @items,
            ( { with => 'lines', lw => 3, lc => '#000000' },
              _pdl($ax), _pdl($ay), _pdl($az) );
    }

    # modular coils
    if ( !defined $o{show_coils} || $o{show_coils} ) {
        for my $coil ( $self->modular_coils( $o{coil_count} ) ) {
            push @items,
                ( { with => 'lines', lw => 2, lc => '#d83010' },
                  _pdl( $coil->[0] ), _pdl( $coil->[1] ), _pdl( $coil->[2] ) );
        }
    }

    $w->plot3d(
        {   trid   => 1,
            title  => $title,
            view   => $view,
            xlabel => 'X (m)',
            ylabel => 'Y (m)',
            zlabel => 'Z (m)',
        },
        @items,
    );
    $w->close;
    return $o{output} || 'stellarator.png';
}

# --- nested flux-surface cross sections over one field period ------------
# Options: output, title, size, n_angles, n_surfaces, nu.
sub plot_cross_sections {
    my ( $self, %o ) = @_;
    $o{output} ||= 'stellarator_cross_sections.png';
    my $w = $self->_new_gpwin(%o);

    my $nang  = $o{n_angles}   || 5;
    my $nsurf = $o{n_surfaces} || 6;
    my $nu    = $o{nu}         || 200;
    my $title = defined $o{title} ? $o{title}
              : 'Flux-surface cross sections over one field period';

    my @plots;
    my @palette = (
        '#1f77b4', '#d62728', '#2ca02c', '#9467bd',
        '#ff7f0e', '#17becf', '#8c564b', '#e377c2',
    );
    for my $a ( 0 .. $nang - 1 ) {
        my $v = ( $nang > 1 ? $a / ( $nang - 1 ) : 0 )
              * $self->field_period_angle;
        my $color = $palette[ $a % @palette ];
        for my $s ( 1 .. $nsurf ) {
            my $scale = $s / $nsurf;
            my ( $R, $Z ) = $self->cross_section( $v, $nu, $scale );
            my %style = ( with => 'lines', lc => $color );
            $style{legend} = sprintf( 'phi = %.0f deg', $v * 180 / PI )
                if $s == $nsurf;    # label only the outermost surface
            push @plots, ( \%style, _pdl($R), _pdl($Z) );
        }
    }

    $w->plot(
        {   title  => $title,
            xlabel => 'R (m)',
            ylabel => 'Z (m)',
        },
        @plots,
    );
    $w->close;
    return $o{output};
}

# --- radial density and temperature profiles -----------------------------
sub plot_profiles {
    my ( $self, %o ) = @_;
    $o{output} ||= 'stellarator_profiles.png';
    my $w = $self->_new_gpwin(%o);

    my $n     = $o{n_points} || 100;
    my $alpha_n = defined $o{alpha_n} ? $o{alpha_n} : 0.5;
    my $alpha_T = defined $o{alpha_T} ? $o{alpha_T} : 2.0;

    my ( @x, @ne, @te );
    for my $i ( 0 .. $n ) {
        my $xr = $i / $n;
        push @x,  $xr;
        push @ne, $self->density_profile( $xr, $alpha_n ) / 1e19;   # 1e19 m^-3
        push @te, $self->temperature_profile( $xr, $alpha_T ) / 1000; # keV
    }

    $w->plot(
        {   title  => 'W7-X radial profiles (illustrative)',
            xlabel => 'normalised minor radius  r/a',
            ylabel => 'n_e (1e19 m^-3)  /  T_e (keV)',
        },
        ( { with => 'lines', lw => 2, legend => 'n_e (1e19 m^-3)' },
          _pdl( \@x ), _pdl( \@ne ) ),
        ( { with => 'lines', lw => 2, legend => 'T_e (keV)' },
          _pdl( \@x ), _pdl( \@te ) ),
    );
    $w->close;
    return $o{output};
}

# --- ISS04 confinement-time parameter scan --------------------------------
# Scans one attribute (default 'heating_power') and plots tau_E(ISS04).
sub plot_confinement_scan {
    my ( $self, %o ) = @_;
    $o{output} ||= 'stellarator_confinement.png';
    my $w = $self->_new_gpwin(%o);

    my $param = $o{parameter} || 'heating_power';
    my $from  = defined $o{from} ? $o{from} : 1;
    my $to    = defined $o{to}   ? $o{to}   : 20;
    my $n     = $o{n_points} || 60;

    my $saved = $self->$param;                 # restore afterwards
    my ( @x, @tau );
    for my $i ( 0 .. $n ) {
        my $val = $from + ( $to - $from ) * $i / $n;
        $self->$param($val);
        push @x,   $val;
        push @tau, $self->confinement_time_iss04;
    }
    $self->$param($saved);

    ( my $plabel = $param ) =~ s/_/ /g;        # avoid gnuplot subscripting
    $w->plot(
        {   title  => "ISS04 confinement time vs $plabel",
            xlabel => $plabel,
            ylabel => 'tau_E (s)',
        },
        ( { with => 'lines', lw => 2, legend => 'tau_E (ISS04)' },
          _pdl( \@x ), _pdl( \@tau ) ),
    );
    $w->close;
    return $o{output};
}

#---------------------------------------------------------------------------
# Reporting
#---------------------------------------------------------------------------
sub device_report {
    my ($self) = @_;
    my @l;
    push @l, "== Stellarator device: " . $self->config_name . " ==";
    push @l, sprintf( "  major radius       R0     = %.3f m", $self->major_radius );
    push @l, sprintf( "  minor radius       a      = %.3f m", $self->minor_radius );
    push @l, sprintf( "  aspect ratio       R0/a   = %.2f",  $self->aspect_ratio );
    push @l, sprintf( "  field periods      Nfp    = %d",    $self->num_field_periods );
    push @l, sprintf( "  rotational transf. iota   = %.3f (q = %.3f)",
        $self->iota, $self->safety_factor );
    push @l, sprintf( "  magnetic field     B      = %.2f T", $self->magnetic_field );
    push @l, sprintf( "  plasma volume      V      = %.2f m^3", $self->plasma_volume );
    push @l, sprintf( "  plasma surface     S      = %.2f m^2", $self->plasma_surface_area );
    push @l, sprintf( "  non-planar coils          = %d", $self->num_nonplanar_coils );
    push @l, sprintf( "  planar coils              = %d", $self->num_planar_coils );
    push @l, "  -- operating point --";
    push @l, sprintf( "  heating power      P      = %.1f MW", $self->heating_power );
    push @l, sprintf( "  electron density   n_e    = %.3e m^-3", $self->electron_density );
    push @l, sprintf( "  electron temp.     T_e    = %.2f keV", $self->electron_temperature / 1000 );
    push @l, sprintf( "  ion temperature    T_i    = %.2f keV", $self->ion_temperature / 1000 );
    push @l, "  -- derived performance --";
    push @l, sprintf( "  ISS04 confinement  tau_E  = %.3f s", $self->confinement_time_iss04 );
    push @l, sprintf( "  stored energy      W      = %.2f MJ", $self->stored_energy_MJ );
    push @l, sprintf( "  plasma beta        beta   = %.2f %%  (%.0f%% of limit)",
        100 * $self->plasma_beta, 100 * $self->beta_fraction );
    push @l, sprintf( "  Sudo density limit n_max  = %.3e m^-3  (%.0f%% used)",
        $self->sudo_density_limit, 100 * $self->density_fraction );
    push @l, sprintf( "  triple product n T tau    = %.3e keV s m^-3", $self->triple_product );
    push @l, sprintf( "  ECRH 2nd-harm. res. field = %.2f T (at %.0f GHz)",
        $self->ecrh_resonance_field(2), $self->gyrotron_frequency / 1e9 );
    return join( "\n", @l ) . "\n";
}

# Theoretical fusion-power summary for a 50:50 D-T operating point.
sub power_report {
    my ($self) = @_;
    my @l;
    push @l, "== Theoretical fusion power (50:50 D-T): " . $self->config_name . " ==";
    push @l, "  -- operating point --";
    push @l, sprintf( "  electron density   n_e    = %.3e m^-3", $self->electron_density );
    push @l, sprintf( "  D-T fuel fraction  f      = %.2f  (n_fuel = %.3e m^-3)",
        $self->dt_fuel_fraction, $self->fuel_ion_density );
    push @l, sprintf( "  ion temperature    T_i    = %.2f keV", $self->ion_temperature / 1000 );
    push @l, sprintf( "  heating power      P_heat = %.1f MW", $self->heating_power );
    push @l, "  -- fusion output --";
    push @l, sprintf( "  D-T reactivity     <sv>   = %.3e m^3/s", $self->dt_reactivity );
    push @l, sprintf( "  fusion power density      = %.3e MW/m^3", $self->fusion_power_density / 1e6 );
    push @l, sprintf( "  total fusion power P_fus  = %.2f MW", $self->fusion_power_MW );
    push @l, sprintf( "    neutrons (14.07 MeV)    = %.2f MW", $self->neutron_power_MW );
    push @l, sprintf( "    alphas   (3.52 MeV)     = %.2f MW", $self->alpha_power_MW );
    push @l, sprintf( "  neutron wall load         = %.3f MW/m^2", $self->neutron_wall_load );
    push @l, sprintf( "  fusion gain        Q      = %.2f", $self->fusion_gain_Q );
    return join( "\n", @l ) . "\n";
}

1;

__END__

=head1 NAME

Physics::CPD::Stellarator - Stellarator fusion-reactor modelling for Physics::CPD

=head1 SYNOPSIS

    use Physics::CPD::Stellarator;

    my $w7x = Physics::CPD::Stellarator->new(
        electron_density     => 8e19,    # m^-3
        electron_temperature => 4000,    # eV
        ion_temperature      => 2000,    # eV
        magnetic_field       => 2.5,     # T
        heating_power        => 10,      # MW
    );

    print $w7x->device_report;

    printf "ISS04 tau_E = %.3f s\n", $w7x->confinement_time_iss04;
    printf "stored W    = %.1f MJ\n", $w7x->stored_energy_MJ;

    # Theoretical fusion power if this design were fuelled with D-T:
    $w7x->ion_temperature(15000);        # 15 keV
    $w7x->electron_density(2e20);
    print $w7x->power_report;
    printf "P_fusion = %.1f MW,  Q = %.1f\n",
        $w7x->fusion_power_MW, $w7x->fusion_gain_Q;

    # visualisations (written to PNG files)
    $w7x->plot_3d( output => 'w7x_3d.png' );
    $w7x->plot_cross_sections( output => 'w7x_cross.png' );
    $w7x->plot_profiles( output => 'w7x_profiles.png' );
    $w7x->plot_confinement_scan( parameter => 'heating_power',
                                 from => 1, to => 20 );

=head1 DESCRIPTION

C<Physics::CPD::Stellarator> is the stellarator fusion-reactor modelling
submodule for L<Physics::CPD>.  It extends the generic computational-plasma
dynamics engine with the geometry and engineering/plasma parameters needed to
simulate a I<stellarator>, using the B<Wendelstein 7-X> (W7-X) device at IPP
Greifswald as its default configuration.  It inherits every plasma calculation
of the base class and adds:

=over 4

=item * device parameters - major/minor radius, five field periods, coil
counts, rotational transform C<iota>, design beta limit, pulse length;

=item * derived physics - aspect ratio, plasma volume and surface, the ISS04
international stellarator confinement-time scaling, stored thermal energy, the
Sudo density limit, plasma-beta and density-limit fractions, the Lawson triple
product, and the electron-cyclotron-heating resonant field;

=item * theoretical fusion power - Bosch-Hale D-T reactivity, fusion power
density and total fusion power, the neutron/alpha split, neutron wall loading
and the fusion gain C<Q>, for evaluating the design as a hypothetical D-T
reactor;

=item * three-dimensional geometry - the last-closed flux surface described as
a VMEC-style Fourier series R(u,v), Z(u,v), the helical magnetic axis, nested
flux surfaces and a set of tilted modular field coils; and

=item * plotting - 3-D design diagrams, poloidal cross sections through a field
period, radial profiles and confinement-scaling scans, rendered with
L<PDL::Graphics::Gnuplot>.

=back

Geometry accessors (C<boundary_point>, C<magnetic_axis>, C<cross_section>,
C<surface_grid>, C<modular_coils>) are pure Perl and return array references,
so they can be used and tested without PDL.  Only the C<plot_*> methods require
L<PDL> and L<PDL::Graphics::Gnuplot>; they are loaded on demand and render to an
image file (default terminal C<pngcairo>), so they work on headless machines.

=head1 KEY ATTRIBUTES

C<config_name>, C<major_radius> (5.5 m), C<minor_radius> (0.53 m),
C<num_field_periods> (5), C<iota> (0.96), C<magnetic_field> (2.5 T),
C<heating_power> (10 MW), C<num_nonplanar_coils> (50), C<num_planar_coils>
(20), C<beta_limit> (0.05), C<pulse_length> (1800 s),
C<gyrotron_frequency> (140 GHz), C<dt_fuel_fraction> (1.0, the D-T fuel-ion
fraction of C<n_e> used by the fusion-power methods), and C<boundary_coeffs>
(the Fourier boundary, overridable to model any stellarator equilibrium).

=head1 PHYSICS METHODS

C<aspect_ratio>, C<plasma_volume>, C<plasma_surface_area>,
C<rotational_transform>, C<safety_factor>, C<confinement_time_iss04>,
C<stored_energy> / C<stored_energy_MJ>, C<sudo_density_limit>,
C<beta_fraction>, C<density_fraction>, C<triple_product>,
C<ecrh_resonance_field>, C<density_profile>, C<temperature_profile>,
C<device_report>.

=head1 FUSION POWER METHODS

These estimate the fusion power a stellarator of this design would produce if
fuelled with a 50:50 deuterium-tritium mix.  W7-X itself runs hydrogen or
deuterium and produces negligible fusion power, so the numbers are a
I<theoretical> figure of merit for the geometry and operating point.  The model
is 0-D (it treats C<electron_density> and C<ion_temperature> as uniform over
C<plasma_volume>).

=over 4

=item dt_reactivity([$Ti_keV])

Maxwell-averaged D-T reactivity C<< <sigma v> >> in m^3/s at ion temperature
C<$Ti_keV> (defaults to the model C<ion_temperature>), via the Bosch-Hale
parametrisation (valid 0.2-100 keV).

=item fuel_ion_density

Total D-T fuel-ion density C<dt_fuel_fraction * electron_density> [m^-3].

=item fusion_power_density

Volumetric fusion power C<(n_fuel/2)^2 <sigma v> E_DT> [W/m^3].

=item fusion_power / fusion_power_MW

Total fusion power over the plasma volume, in W and MW.

=item neutron_power_MW / alpha_power_MW

The 14.07 MeV neutron power (to the blanket) and 3.52 MeV alpha power (retained
to heat the plasma), in MW.

=item neutron_wall_load

Average neutron loading over the plasma surface [MW/m^2].

=item fusion_gain_Q

Fusion energy gain C<Q = fusion_power_MW / heating_power>.

=item power_report

A formatted multi-line summary of the operating point and fusion output.

=back

=head1 GEOMETRY METHODS

C<boundary_point($u,$v,$scale)>, C<surface_point_xyz>, C<magnetic_axis($n)>,
C<cross_section($v,$nu,$scale)>, C<surface_grid($nu,$nv,$scale)>,
C<modular_coils($count,$npts)>.

=head1 PLOTTING METHODS

C<plot_3d>, C<plot_cross_sections>, C<plot_profiles>,
C<plot_confinement_scan>.  Each accepts an C<output> filename (and optional
C<terminal>, C<size> and method-specific options) and returns the filename it
wrote.

=head1 SEE ALSO

L<Physics::CPD>, L<PDL::Graphics::Gnuplot>.

W7-X reference: Klinger et al., "Overview of first Wendelstein 7-X high-
performance operation", Nucl. Fusion 59 (2019).  ISS04 scaling: Yamada et al.,
Nucl. Fusion 45 (2005) 1684.  D-T reactivity: H.-S. Bosch & G.M. Hale,
"Improved formulas for fusion cross-sections and thermal reactivities",
Nucl. Fusion 32 (1992) 611.

=head1 AUTHOR

Generated for the Physics-CPD project.

=head1 LICENSE

Copyright (C) 2026 the Physics-CPD authors.

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.  See L<https://www.gnu.org/licenses/gpl-3.0.html>.

=cut
