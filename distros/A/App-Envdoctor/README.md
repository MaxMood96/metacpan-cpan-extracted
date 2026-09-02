# envdoctor (Perl)

Native Perl port of [envdoctor](https://github.com/arun-skg/envdoctor) — a
local-first environment-variable consistency checker, distributed as the
`App::Envdoctor` CPAN package.

## Install

```bash
cpanm App::Envdoctor
```

> **CPAN release pending** — the `App::Envdoctor` distribution is coming soon.
> Until it lands, install from a checkout:
>
> ```bash
> perl Makefile.PL && make && make install
> ```

## Quick start

```bash
envdoctor scan --dir .        # audit; exit 1 on errors
envdoctor scan --strict       # treat warnings as errors too
envdoctor scan --json         # machine-readable JSON array (no values)
```

## What it detects

Reconciles variables **used** in Perl source (`$ENV{X}`, `$ENV{'X'}`,
`$ENV{"X"}`) against those **defined** in `.env` files:

It also treats interpolated variables in **Docker Compose**
(`docker-compose.yml`, `compose.yaml`, …), **GitHub Actions** workflows
(`.github/workflows/*.yml`), and **Kubernetes** manifests (any `*.yml`/`*.yaml`
with `apiVersion:` and `kind:`) as *used*. `${VAR}` / `$VAR` interpolation is
recognised everywhere (escaped `$$` is ignored), and in Actions the
`secrets.X` / `vars.X` / `env.X` contexts are recognised too. This feeds the
existing missing/undefined and unused detectors — no new rules, and values are
never read from these files. Parsing is dependency-free (regex/line scanning,
no YAML library).

| Rule | Severity | Meaning |
|------|----------|---------|
| `undefined-in-source` | error | Used in code but not defined in any `.env` file |
| `duplicates` | error | Same key defined 2+ times in a single `.env` file |
| `public-prefix` | error | Secret-looking variable exposed to client bundles via a public prefix (`NEXT_PUBLIC_`, `VITE_`, `REACT_APP_`, …) |
| `type-mismatch` | error | A variable's inferred value type differs across environments (e.g. integer in one `.env`, string in another) |
| `unused` | warning | Defined in `.env` but never referenced in source |
| `environment-diff` | warning | Defined in some environment files but missing from others |
| `weak-secret` | warning | Secret-looking variable has a weak or placeholder value |
| `typo` | warning | Used name closely matches a defined name (likely a misspelling) |

Multiple `.env` files are grouped into environment labels by filename
(`.env`→`default`, `.env.local`→`local`, `.env.production`→`production`,
`.env.production.local`→`production`; `*.example` is skipped). Values are read
only to power detection and are **never** printed in any output.

Add `--json` to emit a JSON array of findings (keys `rule`, `severity`,
`name`, `message`, `file`, `line`) instead of the human report; the exit code
is unchanged.

Line comments and POD blocks (`=pod … =cut`) are stripped before scanning.
`scan` exits `1` on errors (or warnings with `--strict`). Uses only core
modules (`File::Find`, `File::Spec`, `JSON::PP`, `Test::More`).

## Development

```bash
cd perl
prove -Ilib t/
```

## Subcommands

Alongside `scan`, every port shares two environment subcommands:

```bash
envdoctor diff <envA> <envB>       # compare two environments (add --json)
envdoctor sync <from> <to>         # copy missing keys (add --dry-run)
```

`diff` reports which variable names are only in one environment; `sync` appends
the missing keys to the target `.env` file as empty `KEY=` placeholders — values
are never copied.

### init / fix

```bash
envdoctor init [-d DIR] [--force]  # scaffold .env.example + ENVIRONMENT.md
envdoctor fix  [-d DIR]            # (re)generate both files
```

Both generate `.env.example` and `ENVIRONMENT.md` at the project root from the
union of defined (`.env*`) and used (source/infra) variable names, sorted. Only
names are written — values are never emitted. `init` writes each file only when
absent (`--force` overwrites); `fix` always rewrites both. Output is identical
byte-for-byte across every envdoctor port.

## Schema validation

Add an `envdoctor.schema.json` at your project root to validate `.env` values:

```json
{
  "PORT":  { "type": "integer", "min": 1, "max": 65535 },
  "LEVEL": { "enum": ["debug", "info", "warn", "error"] },
  "TOKEN": { "type": "string", "optional": true }
}
```

Supported rule fields: `type` (string/integer/float/boolean/url/json), `enum`,
`regex`, `min`, `max`, `optional`. Values that fail are reported as
`schema-validation` errors (values are never printed).

## Other languages

envdoctor ships as a standalone native port for each ecosystem:

- [Node (reference)](..) · [Python](../python) · [Go](../go) · [Ruby](../ruby) · [PHP](../php) · [Java](../java)
- 📖 Docs: [arun-skg.github.io/envdoctor](https://arun-skg.github.io/envdoctor/)
- Main repository: [github.com/arun-skg/envdoctor](https://github.com/arun-skg/envdoctor)
