# App::Greple::md Module Design

Date: 2026-02-16

## Motivation

mdee currently builds greple command lines in Bash, passing patterns and colors as `-E` and `--cm` arguments. This has two limitations:

1. **No nested pattern processing** -- patterns are independent `-E` entries, so links inside headings cannot receive both heading color and link treatment (OSC 8 hyperlinks).
2. **Bash complexity** -- pattern definitions, color expansion, and `add_pattern` logic are implemented in Bash.

Moving highlight processing into a greple module (`App::Greple::md`) solves both issues by handling all colorization in Perl with cumulative coloring.

## Design Overview

### Module Location

`App::Greple::md` -- existing stub at `~/Git/tecolicom/Greple/public/md/`.

### Standalone Usage

```bash
greple -Mmd file.md                          # light mode (default)
greple -Mmd::config(mode=dark) file.md       # dark mode
greple -Mmd --cm h1='L25DE/<RoyalBlue>' file.md  # override color
```

### Usage from mdee

```bash
greple -Mmd::config(mode=$mode) \
    --cm "h1=${colors[h1]}" --cm "h2=${colors[h2]}" ... \
    "$@"
```

mdee's theme system remains in Bash. The module defines default colors; mdee overrides them via `--cm` passthrough.

## Architecture

### `__DATA__` Section

Static defaults defined in the module's `__DATA__` section:

```
option default \
    --all --need=0 \
    --cm h1=... --cm h2=... --cm h3=... \
    --cm h4=... --cm h5=... --cm h6=... \
    --cm bold=... --cm italic=... --cm strike=... \
    --cm code_block=... --cm inline_code=... \
    --cm link=... --cm image=... --cm image_link=... \
    --cm blockquote=... --cm horizontal_rule=... \
    --cm comment=... \
    -E '(?!)' \
    --print &__PACKAGE__::colorize
```

- `--cm LABEL=spec`: Default colors for each element (light mode defaults)
- `-E '(?!)'`: Dummy pattern (never matches, but required for greple to invoke the print function)
- `--print &colorize`: Custom function handles all output processing
- `--all --need=0`: Output all lines even without matches

Mode-specific option sets:

```
option --md-light \
    --cm h1=L25DE/${base} --cm h2=... ...

option --md-dark \
    --cm h1=L00DE/${base} --cm h2=... ...
```

### `Getopt::EX::Config` Parameters

```perl
my $config = Getopt::EX::Config->new(
    mode  => '',      # light / dark / auto
    osc8  => 1,       # OSC 8 hyperlinks
    base  => '',      # base color override
);
```

- `mode`: Terminal mode (light/dark/auto). Determines which color set to apply.
- `osc8`: Enable/disable OSC 8 hyperlink generation.
- `base`: Base color override (e.g., `RoyalBlue`). Empty means use built-in default.

### `finalize()` Function

Handles dynamic configuration that cannot be expressed in `__DATA__`:

```perl
sub finalize {
    my($mod, $argv) = @_;
    # Apply mode-specific colors
    if ($config->{mode} eq 'dark') {
        $mod->setopt(default => '--md-dark');
    } else {
        $mod->setopt(default => '--md-light');
    }
}
```

Only mode switching logic lives here. All static defaults are in `__DATA__`.

### `colorize()` Function

The core processing function, called via `--print &colorize`. Receives each line in `$_` and returns colorized output.

```perl
sub colorize {
    # Process patterns in priority order
    # Each pattern match applies color via main::color(label, text)

    # 1. Code blocks (fenced) -- protect from further processing
    # 2. Inline code -- protect from further processing
    # 3. HTML comments -- protect from further processing
    # 4. Links (with OSC 8) -- process before headings
    # 5. Headings -- apply on top of link colors (cumulative)
    # 6. Bold, italic, strikethrough
    # 7. Blockquotes, horizontal rules
    # 8. Other elements
}
```

Key design decisions:

- **Processing order matters**: Links are processed before headings. When heading color is applied on top of link-colored text, cumulative coloring preserves both the OSC 8 hyperlink and the heading appearance.
- **Code protection**: Code blocks and inline code are identified first and excluded from further pattern matching.
- **`main::color(label, text)`**: Uses greple's built-in color resolution. Labels are looked up in the `--cm` colormap, so mdee can override any color by passing `--cm LABEL=new_spec`.

### Cumulative Coloring

`Term::ANSIColor::Concise`'s `ansi_color()` supports cumulative coloring: applying a color to already-colored text preserves both color sequences. This is critical for:

```
## See the [documentation](https://example.com) for details
```

Processing flow:
1. `colorize()` identifies `[documentation](url)` as a link
2. Applies link color + OSC 8 wrapping via `main::color('link', ...)`
3. Identifies `## ...` as an h2 heading
4. Applies h2 color to the entire line via `main::color('h2', ...)`
5. Result: heading color wraps the line, link color and OSC 8 are preserved inside

### Pattern Definitions

Patterns are defined as Perl regexes within the `colorize()` function (or as module-level constants). They correspond to current mdee patterns:

| Label | Description | Current mdee source |
|-------|-------------|-------------------|
| h1-h6 | Headers | `patterns_default` h1-h6 |
| bold | `**text**`, `__text__` | `patterns_default` bold |
| italic | `*text*`, `_text_` | `patterns_default` italic |
| strike | `~~text~~` | `patterns_default` strike |
| code_block | Fenced code blocks | `patterns_default` code_block |
| inline_code | `` `code` `` | `patterns_default` inline_code |
| link | `[text](url)` | `patterns_default` link |
| image | `![alt](url)` | `patterns_default` image |
| image_link | `[![alt](img)](url)` | `patterns_default` image_link |
| blockquote | `> text` | `patterns_default` blockquote |
| horizontal_rule | `---`, `***`, `___` | `patterns_default` horizontal_rule |
| comment | `<!-- ... -->` | `patterns_default` comment |

### OSC 8 Hyperlinks

Link processing generates OSC 8 sequences when `$config->{osc8}` is enabled:

```perl
use URI::Escape;

sub osc8 {
    my($url, $text) = @_;
    my $escaped = uri_escape_utf8($url, "^\\x20-\\x7e");
    "\e]8;;${escaped}\e\\${text}\e]8;;\e\\";
}
```

The `osc8()` function is used within link/image/image_link color functions, similar to current mdee implementation.

## What Stays in mdee (Bash)

- Theme system (`theme_light`/`theme_dark`, theme files, `--theme` option)
- Color expansion (`expand_theme`, `${base}` resolution)
- `--show` field visibility
- Style system (`--style`, fold/table/nup/pager pipeline)
- Fold processing (`run_fold` via `-Mtee "&ansifold"`)
- Table processing (`run_table` via `-Mtee "&ansicolumn"`)
- Table rule fix (`run_table_fix`)
- Mode detection (`detect_terminal_mode`)
- User configuration (`config.sh`)

mdee constructs `--cm` arguments from its theme system and passes them to greple, overriding the module's defaults.

## What Moves to App::Greple::md (Perl)

- All pattern definitions (regex)
- All colorization logic (`colorize()`)
- Default color definitions (in `__DATA__`)
- OSC 8 hyperlink generation
- Mode-specific color switching (light/dark via `finalize()`)

## Data Flow

```
mdee (Bash)
  ├── Theme resolution → colors[] array
  ├── Build --cm overrides from colors[]
  └── Invoke greple pipeline:
        greple -Mmd::config(mode=dark,osc8=1) \
            --cm "h1=${colors[h1]}" ... \
            "$@"
        │
        ├── App::Greple::md (__DATA__)
        │     └── Default --cm, --print &colorize
        ├── finalize() → mode-specific --cm
        ├── greple processes options (later --cm wins)
        └── colorize() → pattern match + main::color()
```

## Migration Path

Phase 1: Implement `App::Greple::md` with all patterns and colors. Verify `greple -Mmd` works standalone.

Phase 2: Modify mdee's `run_greple()` to use `-Mmd` instead of building `-E`/`--cm` pairs. Pass theme colors via `--cm` overrides.

Phase 3: Remove pattern/color definitions from mdee. Clean up unused Bash functions.
