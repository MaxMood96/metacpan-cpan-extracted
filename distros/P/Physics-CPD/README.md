# Physics-CPD

Generic computational plasma dynamics in Perl, with an optional stellarator
fusion-reactor modelling submodule and 3‑D visualisation of the **Wendelstein
7‑X** stellarator.

The distribution provides two modules:

| Module | Role |
|--------|------|
| **`Physics::CPD`** | Pure‑Perl *Computational Plasma Dynamics* package — generic magnetised‑plasma calculations from density, temperature, magnetic field and ion species. |
| **`Physics::CPD::Stellarator`** | Fusion-reactor modelling submodule that extends `Physics::CPD` with stellarator geometry and physics, using **Wendelstein 7‑X** (W7‑X, IPP Greifswald) as the default configuration, plus plotting and 3‑D design diagrams. |

---

## Features

### `Physics::CPD` — generic plasma physics package (no heavy dependencies)

* Characteristic frequencies: electron/ion **plasma** and **cyclotron** frequencies.
* Characteristic lengths/speeds: **Debye length**, electron/ion **Larmor radii**,
  **thermal**, **Alfvén** and **ion‑sound** speeds.
* Energetics: kinetic and magnetic **pressure**, **plasma β**.
* Collisional transport (NRL Plasma Formulary): **Coulomb logarithm**,
  **collision frequency**, **mean free path**, **Spitzer resistivity**.
* Multi‑species ions (`H, D, T, He, He3, C, O, …`); temperatures in **eV**.

### `Physics::CPD::Stellarator` — stellarator fusion-reactor model

* Device parameters: major/minor radius, **5 field periods**, coil counts,
  rotational transform *ι*, design **β limit**, pulse length, ECRH gyrotron.
* Derived physics: **aspect ratio**, **plasma volume/surface**,
  **ISS04 confinement‑time scaling**, **stored energy**, the stellarator
  **Sudo density limit**, β/density‑limit fractions, the **Lawson triple
  product**, and the **ECRH resonant field**.
* Theoretical **fusion power production** (if fuelled with D‑T): **Bosch‑Hale
  D‑T reactivity** ⟨σv⟩, **fusion power density** and **total fusion power**,
  the **neutron/alpha split**, **neutron wall loading** and the **fusion gain
  *Q***.
* 3‑D geometry: the last‑closed flux surface as a **VMEC‑style Fourier series**
  `R(u,v), Z(u,v)`, the **helical magnetic axis**, nested flux surfaces and
  **modular field coils** — fully parameterised so you can model other
  stellarators by supplying your own boundary coefficients.
* Plotting via `PDL::Graphics::Gnuplot` (headless‑safe PNG output):
  **3‑D design diagram**, **poloidal cross sections**, **radial profiles**,
  **confinement scans**.

---

## Installation

```sh
perl Makefile.PL
make
make test
make install
```

Requirements:

* **Runtime (core physics):** [`Moo`](https://metacpan.org/pod/Moo).
* **Plotting / 3‑D (optional):** [`PDL`](https://metacpan.org/pod/PDL),
  [`PDL::Graphics::Gnuplot`](https://metacpan.org/pod/PDL::Graphics::Gnuplot)
  and a `gnuplot` binary. These are loaded on demand — the physics API works
  without them.

---

## Quick start

### Plasma parameters

```perl
use Physics::CPD;

my $plasma = Physics::CPD->new(
    electron_density     => 1e20,   # m^-3
    electron_temperature => 5000,   # eV
    ion_temperature      => 3000,   # eV
    magnetic_field       => 3.0,    # T
    ion_species          => 'D',
);

print $plasma->report;
printf "beta = %.2f %%\n", 100 * $plasma->plasma_beta;
```

### Wendelstein 7‑X

```perl
use Physics::CPD::Stellarator;

my $w7x = Physics::CPD::Stellarator->new(
    electron_density     => 8e19,
    electron_temperature => 4000,
    ion_temperature      => 2500,
    magnetic_field       => 2.5,
    heating_power        => 10,     # MW
);

print $w7x->device_report;

printf "ISS04 tau_E = %.3f s\n",  $w7x->confinement_time_iss04;
printf "stored W    = %.1f MJ\n", $w7x->stored_energy_MJ;

# Visualisations (PNG files)
$w7x->plot_3d( output => 'w7x_3d.png' );              # 3-D design diagram
$w7x->plot_cross_sections( output => 'w7x_cross.png');# flux-surface sections
$w7x->plot_profiles( output => 'w7x_profiles.png' );  # radial profiles
$w7x->plot_confinement_scan( output => 'w7x_conf.png',
                             parameter => 'heating_power', from => 1, to => 20 );
```

The 3‑D diagram shows the twisted, bean‑shaped plasma boundary (the five field
periods), the helical magnetic axis and the tilted modular coils.

### Theoretical fusion power

W7‑X is a research device and does not itself produce significant fusion power,
but the model can estimate what a stellarator of this design *would* deliver if
run as a **deuterium–tritium** reactor (a 0‑D estimate using the Bosch‑Hale
reactivity):

```perl
use Physics::CPD::Stellarator;

my $reactor = Physics::CPD::Stellarator->new(
    electron_density => 2.0e20,   # m^-3
    ion_temperature  => 15000,    # eV  (15 keV)
    magnetic_field   => 2.5,      # T
    heating_power    => 10,       # MW  (auxiliary)
    dt_fuel_fraction => 1.0,      # pure 50:50 D-T
);

print $reactor->power_report;

printf "P_fusion = %.1f MW\n", $reactor->fusion_power_MW;   # ~235 MW
printf "  neutrons = %.1f MW\n", $reactor->neutron_power_MW;
printf "  alphas   = %.1f MW\n", $reactor->alpha_power_MW;
printf "wall load  = %.2f MW/m^2\n", $reactor->neutron_wall_load;
printf "gain Q     = %.1f\n", $reactor->fusion_gain_Q;      # P_fus / P_heat
```

---

## Examples

Runnable scripts in [`examples/`](examples):

* `plasma_parameters.pl` — `Physics::CPD` standalone.
* `w7x_simulation.pl` — W7‑X report and a density scan (τ_E, triple product, β).
* `power_production.pl` — theoretical D‑T fusion power of the W7‑X‑class design,
  with ion‑temperature and density scans (P_fus, neutron wall load, *Q*).
* `plot_3d_design.pl` — writes all four PNG visualisations
  (`perl examples/plot_3d_design.pl [output_dir]`).

---

## API reference

Both classes are built with [`Moo`](https://metacpan.org/pod/Moo): every
constructor argument below is also a read/write accessor (`$obj->attr` to read,
`$obj->attr($value)` to set), and every derived quantity is a plain method that
recomputes from the current state. Temperatures are in **eV**; all other
quantities are **SI** unless a method name carries an explicit unit suffix
(`_MJ`, `_MW`, `_hz`, …).

### `Physics::CPD`

**Constructor attributes**

| Attribute | Symbol | Unit | Default | Description |
|-----------|--------|------|---------|-------------|
| `electron_density` | *n*ₑ | m⁻³ | `1e20` | electron number density |
| `electron_temperature` | *T*ₑ | eV | `1000` | electron temperature |
| `ion_temperature` | *T*ᵢ | eV | = *T*ₑ | ion temperature |
| `magnetic_field` | *B* | T | `1` | magnetic flux density |
| `ion_species` | — | — | `'H'` | `e, H, p, D, T, He, He3, He4, C, O` |
| `ion_mass` | *m*ᵢ | kg | from species | override to bypass the species table |
| `ion_charge` | *Z* | — | from species | ion charge number |

**Derived quantities (methods)**

| Group | Methods | Unit |
|-------|---------|------|
| Energy / density helpers | `electron_temperature_joules`, `ion_temperature_joules`, `electron_temperature_kelvin`, `ion_temperature_kelvin`, `ion_density`, `mass_density` | J, K, m⁻³, kg·m⁻³ |
| Frequencies (＋`_hz` variants) | `electron_plasma_frequency`, `ion_plasma_frequency`, `electron_cyclotron_frequency`, `ion_cyclotron_frequency` | rad/s (Hz) |
| Lengths & speeds | `debye_length`, `electron_gyroradius`, `ion_gyroradius`, `electron_thermal_velocity`, `ion_thermal_velocity`, `alfven_velocity`, `ion_sound_speed` | m, m/s |
| Pressure & energetics | `plasma_pressure`, `magnetic_pressure`, `plasma_beta` | Pa, Pa, – |
| Collisional transport (NRL) | `coulomb_logarithm`, `collision_frequency`, `mean_free_path`, `spitzer_resistivity` | –, s⁻¹, m, Ω·m |
| Other | `plasma_parameter` (*N*_D), `as_hash`, `report` | –, hashref, text |

`as_hash` returns every quantity keyed with its unit (e.g. `debye_length_m`);
`report` returns the same as a formatted, printable block.

### `Physics::CPD::Stellarator`

Inherits everything above and overrides the default `magnetic_field` to 2.5 T.

**Additional attributes**

| Attribute | Symbol | Unit | Default | Description |
|-----------|--------|------|---------|-------------|
| `config_name` | — | — | `'Wendelstein 7-X …'` | free-text label |
| `major_radius` | *R₀* | m | `5.5` | major radius |
| `minor_radius` | *a* | m | `0.53` | minor radius |
| `num_field_periods` | *N*fp | — | `5` | toroidal field periods |
| `iota` | *ι* | — | `0.96` | rotational transform |
| `heating_power` | *P* | MW | `10` | auxiliary heating power |
| `num_nonplanar_coils` | — | — | `50` | non-planar modular coils |
| `num_planar_coils` | — | — | `20` | planar coils |
| `beta_limit` | — | — | `0.05` | design MHD β limit |
| `pulse_length` | — | s | `1800` | pulse length |
| `gyrotron_frequency` | — | Hz | `140e9` | ECRH gyrotron frequency |
| `dt_fuel_fraction` | *f* | — | `1.0` | D-T fuel-ion fraction of *n*ₑ (fusion methods) |
| `boundary_coeffs` | — | m | W7-X set | `[m, n, Rbc, Zbs]` Fourier rows |
| `coil_radius` / `coil_elongation` / `coil_tilt` | — | m / – / rad | `0.95` / `1.25` / `0.16` | 3-D coil styling |

**Geometry & performance methods**

| Group | Methods | Unit |
|-------|---------|------|
| Device geometry | `aspect_ratio`, `field_period_angle`, `plasma_volume`, `plasma_surface_area`, `rotational_transform`, `safety_factor` | –, rad, m³, m², –, – |
| Confinement & limits | `confinement_time_iss04`, `stored_energy` / `stored_energy_MJ`, `sudo_density_limit`, `beta_fraction`, `density_fraction`, `triple_product`, `ecrh_resonance_field([n])` | s, J/MJ, m⁻³, –, –, keV·s·m⁻³, T |
| Radial profiles | `density_profile($x[,α])`, `temperature_profile($x[,α])` | m⁻³, eV |
| Reporting | `device_report`, `power_report` | text |

**Fusion power methods** (assume a 50:50 D‑T plasma; 0‑D estimate over the
plasma volume, Bosch‑Hale reactivity)

| Method | Returns | Unit |
|--------|---------|------|
| `dt_reactivity([$Ti_keV])` | ⟨σv⟩ at *T*ᵢ (default `ion_temperature`) | m³/s |
| `fuel_ion_density` | `dt_fuel_fraction × electron_density` | m⁻³ |
| `fusion_power_density` | (*n*_fuel/2)² ⟨σv⟩ *E*_DT | W/m³ |
| `fusion_power` / `fusion_power_MW` | total fusion power | W / MW |
| `neutron_power_MW` | 14.07 MeV channel (to blanket) | MW |
| `alpha_power_MW` | 3.52 MeV channel (heats plasma) | MW |
| `neutron_wall_load` | neutron power / plasma surface | MW/m² |
| `fusion_gain_Q` | `fusion_power_MW / heating_power` | – |

**Geometry accessors** (pure Perl, return array references — no PDL required)

`boundary_point($u,$v[,$scale])`, `surface_point_xyz($u,$v[,$scale])`,
`magnetic_axis([$n])`, `cross_section($v[,$nu,$scale])`,
`surface_grid([$nu,$nv,$scale])`, `modular_coils([$count,$npts])`.

**Plotting methods** (require `PDL` + `PDL::Graphics::Gnuplot`; each takes an
`output =>` filename and returns the filename written)

`plot_3d`, `plot_cross_sections`, `plot_profiles`, `plot_confinement_scan`.

---

## Wendelstein 7‑X reference parameters (defaults)

| Quantity | Value |
|----------|-------|
| Major radius `R0` | 5.5 m |
| Minor radius `a` | 0.53 m |
| Aspect ratio | ≈ 10.4 |
| Field periods | 5 |
| Magnetic field | up to 3 T (2.5 T typical) |
| Plasma volume | ≈ 30 m³ |
| Non‑planar / planar coils | 50 / 20 |
| Rotational transform *ι* | ≈ 0.8 – 1.2 |
| ECRH | 140 GHz, 2nd‑harmonic X‑mode → 2.5 T |
| Design β limit | ≈ 5 % |

---

## Physics references

* Klinger *et al.*, “Overview of first Wendelstein 7‑X high‑performance
  operation”, *Nucl. Fusion* **59** (2019) 112004.
* Yamada *et al.*, ISS04 confinement scaling, *Nucl. Fusion* **45** (2005) 1684.
* Sudo *et al.*, stellarator density limit, *Nucl. Fusion* **30** (1990) 11.
* Bosch & Hale, improved D‑T fusion reactivities, *Nucl. Fusion* **32** (1992) 611.
* Huba, *NRL Plasma Formulary* (collisional parameters).

## License

Released under the **GNU General Public License v3.0** — see the
[`LICENSE`](LICENSE) file for the full text.
