# App::SlimPacker

Fatpack-style bundler with PPI-based minification for standalone Perl scripts.

`slimpack` turns a boot script plus its module tree into a single
self-contained, minified `#!/usr/bin/perl` script. By default it runs the whole
`fatpack` pipeline internally (via `App::FatPacker`'s methods):

1. **trace** the boot script to discover which modules it loads,
2. **drop** core modules with a `Module::CoreList` filter,
3. **resolve** the surviving modules' `.packlist` files,
4. **copy** their sources into a temporary `fatlib/`,
5. **minify** each reachable `.pm` from `lib/` plus every `.pm` from `fatlib/`
   with `App::SlimPacker::process()`, and emit the final script — shebang,
   `%INC` preamble, minified modules, boot script.

Each step is also available as its own subcommand (see Usage). It is
project-agnostic: no search paths or class layouts are baked in.

## Layout

| File | Purpose |
| --- | --- |
| `lib/App/SlimPacker.pm` | The minifier (`process`, `name_gen`, `needs_space`) and bundling helpers |
| `bin/slimpack` | CLI bundler that assembles the final script |
| `t/minify.t` | Tests for the minifier (whitespace rules, variable renaming) |
| `t/deps.t` | Tests for dependency finding (`module_deps`, plugin inlining, `perl_switches`) |
| `t/bundle.t` | End-to-end tests for the `bundle` subcommand |
| `t/cli.t` | Tests for subcommand dispatch (`pack`, `trace`, `packlists-for`, `tree`, `bundle`) |

## Installation

```sh
perl Makefile.PL
make
make test
make install        # installs bin/slimpack to your perl's bin dir
```

Requires `PPI`, `App::FatPacker` and `Module::CoreList` (none are core modules).

## Usage

By default `slimpack` runs the whole fatpack pipeline internally (calling
`App::FatPacker`'s methods, no shelling out): trace the boot script, drop core
modules via `Module::CoreList`, resolve their `.packlist` files, copy the
sources into a temporary `fatlib/`, then minify and emit the standalone script.
Each step is also exposed as a subcommand with the same arguments as `fatpack`:

```sh
slimpack [OPTIONS] [COMMAND] [ARGS]

# default 'pack' — full pipeline
slimpack [OPTIONS] script
slimpack [OPTIONS] -e/-E 'code' [-m/-M module ...]

# individual steps (fatpack-compatible args)
slimpack trace        [--to=FILE|--to-stderr] [--use=MODULE] script
slimpack packlists-for MODULE...
slimpack tree         [PACKLIST ...]
slimpack bundle       [OPTIONS] script          # minify+bundle only (--lib/--fatlib)

  script               boot script to bundle (ignored when -e/-E is given)
  -m module            use module with no imports  (like perl -m)
  -M module[=list]     use module, optional import list or version (like perl -M)
  -e CODE              code to bundle; may be repeated  (like perl -e)
  -E CODE              same, but enables all features  (like perl -E)
  -o, --output FILE    write the bundled script to FILE and chmod +x
                       (default a.out; use '-' for stdout)
  --lib DIR            project .pm sources  (default lib)
  --fatlib DIR         fatpacked core-module tree  (default fatlib; pack uses a temp one)
  --no-minify          bundle modules and boot program verbatim
  --no-rename          minify but leave variable names untouched
  --no-inline-plugins  keep Module::Pluggable as a runtime dependency
  --bundle-lib-all     include every .pm under --lib, even if not referenced
                       from the boot program (default: only statically-reachable
                       lib modules are bundled; fatlib is always fully included)
```

Module discovery resolves the static dependency tree from `--lib` and fully
includes what `pack` collected into `fatlib`, so modules referenced by `-M` or
by `use base`/`use parent` are only bundled if their `.pm` files are in those
trees; like perl, counterparts already present on the target system work either
way. Pass `--bundle-lib-all` to include every `.pm` under `--lib` regardless.

Examples:

```sh
# from this repo root, bundling a host project's boot script (full pipeline)
perl -Ilib bin/slimpack -o myapp bin/boot

# a one-liner program, pp/perl style
slimpack -o myapp -M List::Util=sum -e 'print sum(1..100)'
slimpack -o myapp -E 'say reverse qw(b a c)'
slimpack -o myapp -M strict bin/myapp          # -M also applies to scripts
```

### Module::Pluggable inlining

If the boot script contains `use Module::Pluggable(...)`, `slimpack` reads the
`search_path` from its arguments and inlines the matching plugin classes into
the `plugins()` call, so `Module::Pluggable` never needs to load at runtime.
This is on by default; disable with `--no-inline-plugins`. Boot scripts without
`Module::Pluggable` are unaffected.

## The minifier

`App::SlimPacker::process` does PPI-based minification:

* strips comments and POD,
* collapses blank lines and intra-line whitespace,
* renames `my` variables to short names (`a`, `b`, ... `aa`, ...) to
  shrink the source — skipping names used inside strings, regexes, heredocs,
  `<...>` readlines and backticks, plus `%KEEP` names, ALL_CAPS names and
  single-character names. `local`/`our` declarations are left untouched
  (they may be package globals read via `$PKG::name`). Pass `rename => 0`
  to disable renaming via the API, or `--no-rename` on the CLI; pass
  `--no-minify` to skip the whole pass.

Because variable renaming can silently break code, the test suite pinpoints
every edge case. Bundlers typically run `slimpack` with `rename` disabled for
`fatlib/` (core modules must not be touched) and enabled for `lib/`.

## Fatpack vs SlimPacker

Both tools pack a program plus its module tree into one self-contained script.
The example below was run in a scratch directory on perl 5.40.1 / Debian; both
tools produced a working "Hello, world!" — only the sizes differ.

Save this as `helloworld.pl`:

```perl
package MyGreeter;
use Moo;

has name => (is => 'ro', default => sub { 'world' });

sub greet {
    my $self = shift;
    return "Hello, " . $self->name . "!\n";
}

package main;
print MyGreeter->new->greet;
```

Pack it with both tools:

```sh
fatpack pack helloworld.pl > helloworld.fatpack.pl
slimpack -o helloworld.slimpack.pl helloworld.pl
```

| | `fatpack pack` | `slimpack` |
| --- | --- | --- |
| size | 294 KB | 59 KB |
| lines | 9,929 | 27 |

Both bundles inline the modules the program loads (the `Moo` tree:
`Role::Tiny`, `Sub::Quote`, `Sub::Defer`, `Class::Method::Modifiers`, the
`Method::Generate::*` builders) and run standalone — no `Moo`, no `PERL5LIB`:

```sh
perl helloworld.fatpack.pl    # Hello, world!
perl helloworld.slimpack.pl   # Hello, world!
```

`fatpack` copies every module verbatim, comments and POD included; `slimpack`
sends them through the PPI minifier and collapses the output onto a handful of
long lines. Measured on perl 5.40.1; exact sizes vary with the module set.

## Running the tests

```sh
perl Makefile.PL
make test
```