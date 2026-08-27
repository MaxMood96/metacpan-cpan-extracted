package Physics::Etch;

use strict;
use warnings;
use Carp qw(croak);

use Physics::Etch::Material;
use Physics::Etch::Etchant;
use Physics::Etch::WetEtch;
use Physics::Etch::DryEtch;
use Physics::Etch::GDSII;
use Physics::Etch::Layout;
use Physics::Etch::Chamber;
use Physics::Etch::Loading;
use Physics::Etch::Simulation;

our $VERSION = '0.02';

# ===========================================================================
# Material database  (density in g/cm^3; illustrative)
# ===========================================================================
my %MATERIAL = (
    copper            => { formula => 'Cu',    pretty => 'Copper',            density => 8.96 },
    photoresist       => { formula => '',      pretty => 'Photoresist',       density => 1.20 },
    aluminum_silicide => { formula => 'Al-Si', pretty => 'Aluminum Silicide', density => 2.70 },
    tantalum          => { formula => 'Ta',    pretty => 'Tantalum',          density => 16.65 },
    titanium          => { formula => 'Ti',    pretty => 'Titanium',          density => 4.51 },
    silicon_nitride   => { formula => 'Si3N4', pretty => 'Silicon Nitride',   density => 3.17 },
    polyimide         => { formula => 'PI',    pretty => 'Polyimide',         density => 1.42 },
    silicon           => { formula => 'Si',    pretty => 'Silicon',           density => 2.33 },
    silicon_dioxide   => { formula => 'SiO2',  pretty => 'Silicon Dioxide',   density => 2.20 },
    titanium_nitride  => { formula => 'TiN',   pretty => 'Titanium Nitride',  density => 5.22 },
);

# ===========================================================================
# Recipe database.  Numbers are illustrative, order-of-magnitude values from
# typical semiconductor practice; every value is overridable at call time.
#   Wet : rate @ ref_temp (degC), Ea (eV), isotropy (lateral/vertical)
#   Dry : nominal rate, anisotropy, and nominal power/pressure/bias
# ===========================================================================
my @RECIPE = (
    # -------------------------------- Copper --------------------------------
    {   material => 'copper', process => 'wet', etchant => 'FeCl3',
        composition => 'Ferric chloride, ~40 Baume', mechanism => 'chemical',
        rate => 800, ref_temp => 25, Ea => 0.43, isotropy => 1.0,
        sel_mask => 80, sel_substrate => 300,
        default_mask => 'photoresist', default_substrate => 'silicon_dioxide',
        notes => 'Fast, fully isotropic -> strong undercut on patterned Cu.',
    },
    {   material => 'copper', process => 'wet', etchant => 'APS',
        composition => 'Ammonium persulfate (NH4)2S2O8', mechanism => 'chemical',
        rate => 250, ref_temp => 25, Ea => 0.50, isotropy => 1.0,
        sel_mask => 120, sel_substrate => 400,
        default_mask => 'photoresist',
        notes => 'Cleaner alternative to FeCl3, slower.',
    },
    {   material => 'copper', process => 'dry', etchant => 'Ar-IBE',
        composition => 'Ar+ ion-beam milling', mechanism => 'physical',
        rate => 30, anisotropy => 0.70, power_nom => 300, pressure_nom => 1,
        bias_nom => 500, sel_mask => 1.5, sel_substrate => 1.2,
        default_mask => 'photoresist', default_substrate => 'silicon_dioxide',
        notes => 'Cu has no volatile halides near RT; physical milling used.',
    },
    # ----------------------------- Photoresist ------------------------------
    {   material => 'photoresist', process => 'wet', etchant => 'acetone',
        composition => 'Acetone / solvent strip', mechanism => 'chemical',
        rate => 5000, ref_temp => 25, Ea => 0.20, isotropy => 1.0,
        notes => 'Blanket solvent strip; effectively dissolves resist.',
    },
    {   material => 'photoresist', process => 'wet', etchant => 'piranha',
        composition => 'H2SO4 : H2O2 (3:1) piranha', mechanism => 'chemical',
        rate => 2000, ref_temp => 90, Ea => 0.30, isotropy => 1.0,
        notes => 'Aggressive organic strip / clean.',
    },
    {   material => 'photoresist', process => 'dry', etchant => 'O2',
        composition => 'O2 plasma ash', mechanism => 'chemical',
        rate => 300, anisotropy => 0.40, power_nom => 200, pressure_nom => 100,
        bias_nom => 100,
        notes => 'O2 ashing; low-bias barrel asher is nearly isotropic.',
    },
    # -------------------------- Aluminum silicide ---------------------------
    {   material => 'aluminum_silicide', process => 'wet', etchant => 'PAN',
        composition => 'H3PO4:HNO3:CH3COOH:H2O (16:1:1:2)', mechanism => 'chemical',
        rate => 400, ref_temp => 50, Ea => 0.53, isotropy => 1.0,
        sel_mask => 60, sel_substrate => 100,
        default_mask => 'photoresist', default_substrate => 'silicon_dioxide',
        notes => 'Standard Al etch; Si-rich residue possible from the Si phase.',
    },
    {   material => 'aluminum_silicide', process => 'dry', etchant => 'Cl2/BCl3',
        composition => 'Cl2 / BCl3 / (Ar)', mechanism => 'ion-assisted',
        rate => 250, anisotropy => 0.92, power_nom => 250, pressure_nom => 10,
        bias_nom => 200, sel_mask => 3, sel_substrate => 5,
        default_mask => 'photoresist', default_substrate => 'silicon_dioxide',
        notes => 'BCl3 scavenges native oxide; requires post-etch corrosion control.',
    },
    # ------------------------------- Tantalum -------------------------------
    {   material => 'tantalum', process => 'wet', etchant => 'HF/HNO3',
        composition => 'HF : HNO3 : H2O', mechanism => 'chemical',
        rate => 300, ref_temp => 25, Ea => 0.40, isotropy => 1.0,
        sel_mask => 40, sel_substrate => 20,
        default_mask => 'photoresist',
        notes => 'Attacks many underlayers; use with care.',
    },
    {   material => 'tantalum', process => 'dry', etchant => 'SF6',
        composition => 'SF6 (/ O2)', mechanism => 'ion-assisted',
        rate => 120, anisotropy => 0.85, power_nom => 200, pressure_nom => 20,
        bias_nom => 150, sel_mask => 5, sel_substrate => 8,
        default_mask => 'photoresist', default_substrate => 'silicon_dioxide',
        notes => 'Volatile TaF5 product; good for Ta/TaN metal.',
    },
    # ------------------------------- Titanium -------------------------------
    {   material => 'titanium', process => 'wet', etchant => 'DHF',
        composition => 'Dilute HF (1:20) or HF:H2O2', mechanism => 'chemical',
        rate => 120, ref_temp => 25, Ea => 0.35, isotropy => 1.0,
        sel_mask => 50, sel_substrate => 30,
        default_mask => 'photoresist', default_substrate => 'silicon_dioxide',
        notes => 'Ti etches readily in HF; SiO2 under-layer also attacked.',
    },
    {   material => 'titanium', process => 'dry', etchant => 'Cl2',
        composition => 'Cl2 / BCl3', mechanism => 'ion-assisted',
        rate => 150, anisotropy => 0.88, power_nom => 200, pressure_nom => 15,
        bias_nom => 180, sel_mask => 4, sel_substrate => 6,
        default_mask => 'photoresist', default_substrate => 'silicon_dioxide',
        notes => 'Volatile TiCl4; SF6 also works (TiF4).',
    },
    # ---------------------------- Silicon nitride ---------------------------
    {   material => 'silicon_nitride', process => 'wet', etchant => 'H3PO4',
        composition => 'Hot phosphoric acid, 180 degC', mechanism => 'chemical',
        rate => 5, ref_temp => 180, Ea => 1.90, isotropy => 1.0,
        sel_mask => 3, sel_substrate => 30,
        default_mask => 'silicon_dioxide', default_substrate => 'silicon_dioxide',
        notes => 'Classic selective nitride strip; very slow, high Ea, SiO2-selective.',
    },
    {   material => 'silicon_nitride', process => 'dry', etchant => 'CF4/O2',
        composition => 'CF4 / O2 (or CHF3)', mechanism => 'ion-assisted',
        rate => 120, anisotropy => 0.90, power_nom => 200, pressure_nom => 30,
        bias_nom => 250, sel_mask => 4, sel_substrate => 3,
        default_mask => 'photoresist', default_substrate => 'silicon',
        notes => 'Fluorocarbon RIE; O2 tunes polymerization / selectivity.',
    },
    # ------------------------------- Polyimide ------------------------------
    {   material => 'polyimide', process => 'wet', etchant => 'TMAH',
        composition => 'Hot alkaline (TMAH / hydrazine)', mechanism => 'chemical',
        rate => 150, ref_temp => 60, Ea => 0.70, isotropy => 1.0,
        sel_mask => 20,
        default_mask => 'photoresist',
        notes => 'For non-photodefinable PI; strongly temperature dependent.',
    },
    {   material => 'polyimide', process => 'dry', etchant => 'O2',
        composition => 'O2 (/ CF4) RIE', mechanism => 'ion-assisted',
        rate => 500, anisotropy => 0.85, power_nom => 250, pressure_nom => 50,
        bias_nom => 200, sel_mask => 15, sel_substrate => 50,
        default_mask => 'aluminum_silicide', default_substrate => 'silicon',
        notes => 'O2 RIE gives fast, anisotropic polymer etch; needs a hard mask.',
    },
);

# ===========================================================================
# Introspection
# ===========================================================================
sub material_names { return sort keys %MATERIAL }

sub recipes {
    my ( $class, %f ) = @_;
    return grep {
        ( !defined $f{material} || $_->{material} eq $f{material} )
            && ( !defined $f{process}  || $_->{process}  eq $f{process} )
            && ( !defined $f{etchant}  || $_->{etchant}  eq $f{etchant} )
    } @RECIPE;
}

sub find_recipe {
    my ( $class, $material, $process, $etchant ) = @_;
    my @m = $class->recipes(
        material => $material, process => $process,
        ( defined $etchant ? ( etchant => $etchant ) : () ),
    );
    return $m[0];
}

# ===========================================================================
# Material factory
# ===========================================================================
sub material {
    my ( $class, $name, %opt ) = @_;
    my $spec = $MATERIAL{$name};
    croak "Physics::Etch: unknown material '$name'" unless $spec;
    return Physics::Etch::Material->new(
        name    => $name,
        formula => $spec->{formula},
        pretty  => $spec->{pretty},
        density => $spec->{density},
        ( defined $opt{thickness} ? ( thickness => $opt{thickness} ) : () ),
    );
}

# ===========================================================================
# Process factories:  build a Wet/DryEtch from a recipe + user overrides
# ===========================================================================
sub wet_etch { my $c = shift; $c->_build( 'wet', @_ ) }
sub dry_etch { my $c = shift; $c->_build( 'dry', @_ ) }

sub _build {
    my ( $class, $process, $material, %o ) = @_;

    my $r = $class->find_recipe( $material, $process, $o{etchant} )
        or croak "Physics::Etch: no $process recipe for '$material'"
        . ( defined $o{etchant} ? " with etchant '$o{etchant}'" : '' );

    my $target  = $class->material( $material, thickness => $o{thickness} );
    my $etchant = Physics::Etch::Etchant->new(
        name        => $r->{etchant},
        type        => $process,
        composition => $r->{composition},
        mechanism   => $r->{mechanism},
        notes       => $r->{notes} // '',
    );

    # mask / substrate: accept a name (looked up), an object, or default
    my $mask = $class->_coerce_layer(
        exists $o{mask} ? $o{mask} : $r->{default_mask},
        $o{mask_thickness},
    );
    my $substrate = $class->_coerce_layer(
        exists $o{substrate} ? $o{substrate} : $r->{default_substrate},
        undef,
    );

    my %params = (
        target        => $target,
        etchant       => $etchant,
        mask          => $mask,
        substrate     => $substrate,
        sel_mask      => $r->{sel_mask},
        sel_substrate => $r->{sel_substrate},
    );

    if ( $process eq 'wet' ) {
        $params{$_} = $r->{$_}
            for grep { defined $r->{$_} } qw( rate ref_temp Ea isotropy );
    }
    else {
        $params{$_} = $r->{$_}
            for grep { defined $r->{$_} }
            qw( rate anisotropy power_nom pressure_nom bias_nom Ea ref_temp );
    }

    # user overrides win over recipe defaults (skip already-handled keys)
    my %handled = map { $_ => 1 }
        qw( thickness mask substrate mask_thickness etchant );
    for my $k ( keys %o ) {
        next if $handled{$k};
        $params{$k} = $o{$k};
    }
    $params{mask_thickness} = $o{mask_thickness} if defined $o{mask_thickness};

    return $process eq 'wet'
        ? Physics::Etch::WetEtch->new(%params)
        : Physics::Etch::DryEtch->new(%params);
}

sub _coerce_layer {
    my ( $class, $spec, $thickness ) = @_;
    return undef unless defined $spec;
    my $mat =
          ref $spec                    ? $spec
        : exists $MATERIAL{$spec}      ? $class->material($spec)
        :   Physics::Etch::Material->new( name => $spec );
    $mat->thickness($thickness) if defined $thickness;
    return $mat;
}

# ===========================================================================
# Convenience constructors for the pattern / chamber / loading / simulation
# tools (so a single `use Physics::Etch` exposes the whole toolkit).
# ===========================================================================
sub chamber    { shift; Physics::Etch::Chamber->new(@_) }
sub loading     { shift; Physics::Etch::Loading->new(@_) }
sub layout      { shift; Physics::Etch::Layout->new(@_) }
sub read_gdsii  { shift; Physics::Etch::GDSII->read(@_) }
sub new_gdsii   { shift; Physics::Etch::GDSII->new(@_) }

sub layout_from_gds {
    my ( $class, $file, %a ) = @_;
    return Physics::Etch::Layout->from_gdsii_file( $file, %a );
}

sub simulate {
    my ( $class, %a ) = @_;
    return Physics::Etch::Simulation->new(%a);
}

1;

__END__

=head1 NAME

Physics::Etch - model wet and dry semiconductor etch processes

=head1 SYNOPSIS

    use Physics::Etch;

    # Patterned copper, wet ferric-chloride etch
    my $cu = Physics::Etch->wet_etch( 'copper',
        thickness      => 500,          # nm
        temperature    => 40,           # degC
        feature_cd     => 3000,         # nm mask opening
        mask_thickness => 1500,         # nm resist
        overetch       => 0.30,
    );
    print $cu->report;

    # Silicon-nitride RIE
    my $sin = Physics::Etch->dry_etch( 'silicon_nitride',
        thickness  => 200, feature_cd => 250,
        power => 250, pressure => 25, bias => 300,
    );
    print $sin->report;

=head1 DESCRIPTION

C<Physics::Etch> is a facade over the etch models
L<Physics::Etch::WetEtch> (isotropic, Arrhenius-activated) and
L<Physics::Etch::DryEtch> (anisotropic plasma / RIE). It ships a small
built-in database of materials and etch recipes so a working process can be
built with one call, then customised via overrides.

The module also exposes a pattern / reactor toolkit: a self-contained
L<Physics::Etch::GDSII> reader/writer for resist masks, L<Physics::Etch::Layout>
geometry analysis, a L<Physics::Etch::Chamber> model, L<Physics::Etch::Loading>
(macro, micro and ARDE / RIE-lag), and L<Physics::Etch::Simulation> to tie
them together for per-feature results.

=head2 Physics

B<Wet etch> (L<Physics::Etch::WetEtch>) is a liquid-chemical, essentially
isotropic process:

    R(T) = rate * exp( (Ea/kB) * (1/Tref - 1/T) ) * concentration * agitation
    lateral = R * isotropy            # isotropy defaults to 1.0

Isotropy makes the lateral rate roughly equal to the vertical rate, so
undercut is comparable to etch depth and sidewalls are sloped/rounded. Strong
temperature activation (the Arrhenius term) is the main rate knob.

B<Dry etch> (L<Physics::Etch::DryEtch>) is a directional plasma / RIE process:

    Rv = rate * (P/Pnom)^0.8 * (p/pnom)^0.3 * (Vb/Vbnom)^0.5 * loading * arrhenius
    A_eff  = 1 - (1 - A_nom) * (p/pnom) * (Vbnom/Vb)      # clamped to [0,1]
    lateral = Rv * (1 - A_eff)

High DC bias and low pressure drive vertical etching and steep sidewalls;
high pressure or low bias lets radicals attack laterally, lowering anisotropy
and increasing undercut. An optional Arrhenius term models hot dry etches.

The L<Physics::Etch::Process> base class derives C<time_to_clear>,
C<etch_time> (clear time plus over-etch), C<etch_depth>, C<undercut>,
C<anisotropy>, C<profile> (top/bottom width, etch bias, sidewall angle,
aspect ratio), C<mask_loss> / C<mask_survives>, C<substrate_overetch>,
C<uniformity_report>, and a formatted C<report()>.

=head2 Factory methods

=over 4

=item C<< Physics::Etch->wet_etch($material, %overrides) >>

=item C<< Physics::Etch->dry_etch($material, %overrides) >>

Build a L<Physics::Etch::WetEtch> or L<Physics::Etch::DryEtch> process object
from the recipe database. C<%overrides> may set C<thickness>, C<temperature>,
C<feature_cd>, C<mask>, C<mask_thickness>, C<substrate>, C<overetch>,
C<uniformity>, C<time>, C<etchant> (to pick a specific chemistry), and any rate
parameter such as C<rate>, C<Ea>, C<power>, C<pressure>, C<bias>, or
C<anisotropy>.

=item C<< Physics::Etch->material($name, thickness => $nm) >>

Return a L<Physics::Etch::Material> from the built-in material database.

=item C<< Physics::Etch->recipes(%filter) >>

=item C<< Physics::Etch->find_recipe($material, $process, $etchant) >>

=item C<< Physics::Etch->material_names() >>

Introspect the built-in material and recipe database. C<recipes> accepts
C<material>, C<process> and/or C<etchant> filters and returns matching recipe
hashrefs. C<find_recipe> returns the first match.

=item C<< Physics::Etch->chamber(%args) >>

Convenience constructor for L<Physics::Etch::Chamber>.

=item C<< Physics::Etch->loading(%args) >>

Convenience constructor for L<Physics::Etch::Loading>.

=item C<< Physics::Etch->layout(%args) >>

Convenience constructor for L<Physics::Etch::Layout>.

=item C<< Physics::Etch->read_gdsii($file) >>

=item C<< Physics::Etch->new_gdsii(%args) >>

Convenience constructors for L<Physics::Etch::GDSII>.

=item C<< Physics::Etch->layout_from_gds($file, %args) >>

Read a GDSII file and return a L<Physics::Etch::Layout>.

=item C<< Physics::Etch->simulate(%args) >>

Convenience constructor for L<Physics::Etch::Simulation>.

=back

=head2 Pattern-dependent anisotropy, loading & chamber tools

    use Physics::Etch;
    use Physics::Etch::Loading;

    my $etch    = Physics::Etch->dry_etch('silicon_nitride', thickness => 200);
    my $chamber = Physics::Etch->chamber(
        wafer_diameter_mm => 200, gap_cm => 2.5,
        pressure_mtorr => 20, power_w => 300, flow_sccm => 80,
        gas => 'SF6', gas_mass_amu => 146, gas_diameter_m => 4.8e-10);
    my $layout  = Physics::Etch->layout_from_gds('mask.gds',
        layer => 1, structure => 'TOP', tone => 'clear', field => [200,200]);
    my $loading = Physics::Etch::Loading->from_chamber($chamber, arde_length => 5);

    my $sim = Physics::Etch->simulate(
        process => $etch, chamber => $chamber,
        layout  => $layout, loading => $loading);
    print $sim->report;               # per-CD anisotropy, undercut, RIE lag

=over 4

=item * L<Physics::Etch::GDSII> - a dependency-free GDSII stream reader/writer;
flattens C<SREF>/C<AREF> hierarchies with reflection, magnification and
rotation into absolute polygons.

=item * L<Physics::Etch::Layout> - open area / open fraction (macro-loading
input), per-feature CD from bounding boxes (ARDE input), and a local open-density
grid (micro-loading input). C<tone> selects clear vs dark field.

=item * L<Physics::Etch::Chamber> - reactor geometry to electrode C<area_ratio>,
C<power_density>, C<residence_time>, C<mean_free_path>, C<knudsen>, and a
heuristic DC C<self_bias> / C<ion_energy>. C<process_conditions> returns
pressure and bias ready to pass to the dry etch.

=item * L<Physics::Etch::Loading> - macro loading C<R/R0 = 1/(1+kappa*A_open)>,
micro loading C<1/(1+k_micro*density)>, and ARDE / RIE-lag
C<1/(1+AR/AR0)> (narrow features etch slower and taper). C<from_chamber>
estimates C<kappa> from residence time.

=item * L<Physics::Etch::Simulation> - applies chamber conditions, macro loading
from open area times wafer area, then per feature converts CD to aspect ratio,
applies ARDE plus micro-loading, and reports local rate, depth, undercut,
anisotropy, sidewall angle, and any features that fail to clear.

=back

=head2 Examples

The F<examples/> directory contains one runnable script per material and several
toolkit demos:

    examples/etch_copper.pl              Cu, wet FeCl3 vs dry Ar ion-mill
    examples/etch_photoresist_strip.pl   wet solvent / piranha strip
    examples/etch_photoresist_ash.pl     dry O2 plasma ash + RIE trim
    examples/etch_aluminum_silicide.pl   dry Cl2/BCl3 RIE vs wet PAN
    examples/etch_tantalum.pl            dry SF6 RIE, pressure/bias tuning
    examples/etch_titanium.pl            wet dilute-HF, SiO2 selectivity
    examples/etch_silicon_nitride.pl     wet hot H3PO4 + CF4/O2 RIE
    examples/etch_polyimide.pl           dry O2 RIE thick-film via etch
    examples/make_sample_mask.pl         writes sample_mask.gds
    examples/etch_gdsii_simulation.pl    GDSII-driven per-feature + RIE lag
    examples/etch_loading_effect.pl      macro & micro loading
    examples/etch_chamber_geometry.pl    reactor geometry -> bias / mfp

Run any example with:

    perl -Ilib examples/etch_copper.pl

=head2 Installation

With ExtUtils::MakeMaker:

    perl Makefile.PL
    make
    make test
    make install

On Windows with Strawberry Perl, use C<gmake> instead of C<make> if needed.

To build a release tarball:

    perl Makefile.PL
    make dist

This creates C<Physics-Etch-0.02.tar.gz>. Upload that tarball to PAUSE to publish
it on CPAN; after indexing you can install with C<cpanm Physics::Etch>.

=head1 EXTENDING THE DATABASE

The material and recipe databases are ordinary Perl data structures at the top
of F<lib/Physics/Etch.pm>. You can extend them by editing that file, or bypass
them entirely by constructing L<Physics::Etch::WetEtch> / L<Physics::Etch::DryEtch>
directly with your own parameters.

=head2 Adding a material

Add an entry to C<%MATERIAL>:

    my %MATERIAL = (
        # ... existing entries ...
        tungsten => {
            formula => 'W',
            pretty  => 'Tungsten',
            density => 19.25,          # g/cm^3, optional / illustrative
        },
    );

Required fields:

=over 4

=item * C<pretty> - human-readable name used in reports.

=item * C<formula> - chemical formula or identifier (may be empty).

=item * C<density> - density in g/cm^3, currently illustrative.

=back

=head2 Adding a wet-etch recipe

Wet recipes live in C<@RECIPE> and must contain at least C<material>,
C<process> set to C<'wet'>, C<etchant>, C<mechanism>, and C<rate> (nm/min at
C<ref_temp>). Common additional fields:

    {
        material  => 'tungsten',
        process   => 'wet',
        etchant   => 'H2O2/NH4OH',
        composition => 'Hydrogen peroxide / ammonium hydroxide',
        mechanism => 'chemical',
        rate      => 50,              # nm/min at ref_temp
        ref_temp  => 25,              # degC
        Ea        => 0.40,            # eV, Arrhenius activation energy
        isotropy  => 1.0,             # lateral/vertical ratio
        sel_mask       => 30,         # target:mask etch-rate selectivity
        sel_substrate  => 50,         # target:substrate selectivity
        default_mask   => 'photoresist',
        default_substrate => 'silicon_dioxide',
        notes => 'Brief description of the process.',
    },

=head2 Adding a dry-etch recipe

Dry recipes set C<process> to C<'dry'> and include plasma-specific knobs:

    {
        material  => 'tungsten',
        process   => 'dry',
        etchant   => 'SF6',
        composition => 'SF6 plasma',
        mechanism => 'ion-assisted',
        rate      => 150,             # nm/min at nominal conditions
        anisotropy => 0.85,           # nominal anisotropy, 0..1
        power_nom    => 300,          # W
        pressure_nom => 20,           # mTorr
        bias_nom     => 250,          # V
        sel_mask       => 4,
        sel_substrate  => 8,
        default_mask   => 'photoresist',
        default_substrate => 'silicon',
        notes => 'Brief description of the process.',
    },

Optional wet-style fields C<Ea> and C<ref_temp> may also be supplied for dry
recipes if you want a temperature correction.

=head2 Using custom materials without editing the database

Anywhere a material name is accepted you may pass a L<Physics::Etch::Material>
object, or construct L<Physics::Etch::WetEtch> / L<Physics::Etch::DryEtch>
directly:

    use Physics::Etch::WetEtch;
    use Physics::Etch::Material;
    use Physics::Etch::Etchant;

    my $etch = Physics::Etch::WetEtch->new(
        target    => Physics::Etch::Material->new(
            name => 'my_film', formula => 'X2Y', pretty => 'My Film', thickness => 300),
        etchant   => Physics::Etch::Etchant->new(
            name => 'custom', type => 'wet', composition => '...', mechanism => 'chemical'),
        rate      => 200,
        ref_temp  => 25,
        Ea        => 0.5,
        isotropy  => 0.9,
        feature_cd => 500,
    );
    print $etch->report;

=head1 DISCLAIMER

Rates, activation energies, selectivities and all other numeric values in the
embedded databases are illustrative teaching values, not process
specifications. Always calibrate against your own tool and chemistry.

=head1 SEE ALSO

L<Physics::Etch::WetEtch>, L<Physics::Etch::DryEtch>,
L<Physics::Etch::Process>, L<Physics::Etch::Material>,
L<Physics::Etch::Etchant>, L<Physics::Etch::Chamber>,
L<Physics::Etch::Loading>, L<Physics::Etch::Layout>,
L<Physics::Etch::GDSII>, L<Physics::Etch::Simulation>

=head1 AUTHOR

Jovan Trujillo <jtrujil43@users.noreply.github.com>

=head1 LICENSE

This software is licensed under the GPL-3.0-or-later license.

=cut
