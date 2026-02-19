[![Actions Status](https://github.com/kaz-utashiro/greple-md/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/kaz-utashiro/greple-md/actions?workflow=test) [![MetaCPAN Release](https://badge.fury.io/pl/App-Greple-md.svg)](https://metacpan.org/release/App-Greple-md)
# NAME

App::Greple::md - Greple module for Markdown syntax highlighting

# SYNOPSIS

    greple -Mmd file.md

    greple -Mmd --mode=dark -- file.md

    greple -Mmd --base-color=Crimson -- file.md

    greple -Mmd --cm h1=RD -- file.md

    greple -Mmd --no-table -- file.md

    greple -Mmd --foldlist -- file.md

    greple -Mmd -- --fold file.md

# DESCRIPTION

**App::Greple::md** is a [greple](https://metacpan.org/pod/App%3A%3AGreple) module for viewing
Markdown files in the terminal with syntax highlighting.

It colorizes headings, bold, italic, strikethrough, inline code,
fenced code blocks, HTML comments, blockquotes, horizontal rules,
links, and images.  Tables are formatted with aligned columns and
optional Unicode box-drawing borders.  Long lines in list items can
be folded with proper indentation.  Links become clickable via OSC 8
terminal hyperlinks in supported terminals.

Nested elements are handled with cumulative coloring: for example,
a link inside a heading retains both its link color and the heading
background color.

For a complete Markdown viewing experience with line folding,
multi-column output, and themes, see [App::mdee](https://metacpan.org/pod/App%3A%3Amdee), which uses this
module as its highlighting engine.

# COMMAND OPTIONS

The following options are defined as greple command options
(specified after `--`).

## **--fold**

Enable text folding for list items and definition lists.  Long lines
are wrapped with proper indentation using [ansifold(1)](https://metacpan.org/pod/App%3A%3Aansifold)
via [Greple::tee](https://metacpan.org/pod/Greple%3A%3Atee).  Code blocks, HTML comments, and tables are
excluded from folding.  The fold width is controlled by the
`foldwidth` config parameter (default: 80).

    greple -Mmd -- --fold file.md
    greple -Mmd::config(foldwidth=60) -- --fold file.md

Supported list markers: `*`, `-`, `1.`, `1)`, `#.`, `#)`.

The module option `--foldlist` is a convenient alternative that
enables folding via config.

# MODULE OPTIONS

Module options are specified before `--` to separate them from
greple's own options:

    greple -Mmd --mode=dark --cm h1=RD -- file.md

## **-m** _MODE_, **--mode**=_MODE_

Set color mode.  Available modes are `light` (default) and `dark`.

    greple -Mmd -m dark -- file.md

## **-B** _COLOR_, **--base-color**=_COLOR_

Override the base color used for headings, bold, links, and other
elements.  Accepts a named color (e.g., `Crimson`, `DarkCyan`) or a
[Term::ANSIColor::Concise](https://metacpan.org/pod/Term%3A%3AANSIColor%3A%3AConcise) color spec.

    greple -Mmd -B Crimson -- file.md

## **--\[no-\]colorize**

Enable or disable syntax highlighting.  Enabled by default.
When disabled, no color is applied to Markdown elements.

    greple -Mmd --no-colorize -- file.md

## **--\[no-\]foldlist**

Enable or disable text folding.  Disabled by default.  When
enabled, long lines in list items and definition lists are wrapped
with proper indentation.  The fold width is controlled by the
`foldwidth` config parameter (default: 80).

    greple -Mmd --foldlist -- file.md
    greple -Mmd::config(foldlist=1,foldwidth=60) file.md

See also the `--fold` command option.

## **--\[no-\]table**

Enable or disable table formatting.  When enabled (default),
Markdown tables (3 or more consecutive pipe-delimited rows) are
formatted with aligned columns using [App::ansicolumn](https://metacpan.org/pod/App%3A%3Aansicolumn).

    greple -Mmd --no-table -- file.md

## **--\[no-\]rule**

Enable or disable Unicode box-drawing characters for table borders.
When enabled (default), ASCII pipe characters (`|`) are replaced
with vertical lines (`│`), and separator row dashes become
horizontal rules (`─`) with corner pieces (`├`,
`┤`, `┼`).

    greple -Mmd --no-rule -- file.md

## **--colormap** _LABEL_=_SPEC_, **--cm** _LABEL_=_SPEC_

Override the color for a specific element.  _LABEL_ is one of
the color labels listed in ["COLOR LABELS"](#color-labels).  _SPEC_ follows
[Term::ANSIColor::Concise](https://metacpan.org/pod/Term%3A%3AANSIColor%3A%3AConcise) format and supports `sub{...}`
function specs via [Getopt::EX::Colormap](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3AColormap).

    greple -Mmd --cm h1=RD -- file.md
    greple -Mmd --cm bold='${base}D' -- file.md

## **--heading-markup**\[=_STEPS_\], **--hm**\[=_STEPS_\]

Control inline markup processing inside headings.  By default,
headings are rendered with uniform heading color without processing
bold, italic, strikethrough, or inline code inside them.  Links
are always processed as OSC 8 hyperlinks regardless of this option.

Without an argument, all inline formatting becomes visible within
headings using cumulative coloring.  With an argument, only the
specified steps are processed inside headings.  Steps are separated
by colons.

Available steps: `inline_code`, `horizontal_rules`, `bold`,
`italic`, `strike`.

    greple -Mmd --hm -- file.md                  # all markup
    greple -Mmd --hm=bold -- file.md              # bold only
    greple -Mmd --hm=bold:italic -- file.md       # bold and italic

## **--hashed** _LEVEL_=_VALUE_

Append closing hashes to headings.  For example, `### Title`
becomes `### Title ###`.  Set per heading level:

    greple -Mmd --hashed h3=1 --hashed h4=1 -- file.md

## **--show** _LABEL_\[=_VALUE_\]

Control which elements are highlighted.  This is useful for
focusing on specific elements or disabling unwanted highlighting.

    greple -Mmd --show bold=0 -- file.md          # disable bold
    greple -Mmd --show all= --show h1 -- file.md  # only h1

`--show LABEL=0` or `--show LABEL=` disables the label.
`--show LABEL` or `--show LABEL=1` enables it.
`all` is a special key that sets all labels at once.

# CONFIGURATION

Module parameters can also be set using the `config()` function
in the `-M` declaration:

    greple -Mmd::config(mode=dark,base_color=Crimson) file.md

Nested hash parameters use dot notation:

    greple -Mmd::config(hashed.h3=1,hashed.h4=1) file.md

Available parameters:

    mode            light or dark (default: light)
    base_color      base color override
    colorize        syntax highlighting (default: 1)
    foldlist        text folding (default: 0)
    foldwidth       fold width in columns (default: 80)
    table           table formatting (default: 1)
    rule            box-drawing characters (default: 1)
    osc8            OSC 8 hyperlinks (default: 1)
    heading_markup  inline markup in headings (default: 0)
                    0=off, 1/all=all, or colon-separated steps
    hashed.h1-h6    closing hashes per level (default: 0)

## OSC 8 Hyperlinks

Links are converted to clickable OSC 8 terminal hyperlinks in
supported terminals (iTerm2, Kitty, WezTerm, Ghostty, etc.).
Disable with:

    greple -Mmd::config(osc8=0) file.md

# COLOR LABELS

The following labels identify colorizable elements.  Use them
with `--colormap` (`--cm`) to customize colors or `--show` to control
visibility.  Default values are shown as `light / dark`.
Colors follow [Term::ANSIColor::Concise](https://metacpan.org/pod/Term%3A%3AANSIColor%3A%3AConcise) format.

## Headings

    LABEL   LIGHT                    DARK
    h1      L25D/${base};E           L00D/${base};E
    h2      L25D/${base}+y20;E       L00D/${base}-y15;E
    h3      L25DN/${base}+y30        L00DN/${base}-y25
    h4      ${base}UD                ${base}UD
    h5      ${base}U                 ${base}U
    h6      ${base}                  ${base}

## Inline Formatting

    LABEL   LIGHT / DARK
    bold    D
    italic  I
    strike  X

## Code

    LABEL        LIGHT              DARK
    code_mark    L20                L10
    code_tick    L15/L23            L15/L05
    code_info    ${base_name}=y70   L10
    code_block   /L23;E             /L05;E
    code_inline  L00/L23            L25/L05

## Block Elements

    LABEL            LIGHT / DARK
    blockquote       ${base}D
    horizontal_rule  L15
    comment          ${base}+r60

## Links

    LABEL        LIGHT / DARK
    link         I
    image        I
    image_link   I

# SEE ALSO

- [App::mdee](https://metacpan.org/pod/App%3A%3Amdee)

    Markdown viewer command with line folding, table formatting,
    multi-column layout, and themes.  Uses this module for syntax
    highlighting.

- [App::Greple](https://metacpan.org/pod/App%3A%3AGreple)

    General-purpose extensible grep tool that hosts this module.

- [Term::ANSIColor::Concise](https://metacpan.org/pod/Term%3A%3AANSIColor%3A%3AConcise)

    Concise ANSI color specification format used for color labels.

- [App::ansicolumn](https://metacpan.org/pod/App%3A%3Aansicolumn)

    ANSI-aware column formatting used for table alignment.

- [App::ansifold](https://metacpan.org/pod/App%3A%3Aansifold)

    ANSI-aware text folding used for line wrapping in list items.

# AUTHOR

Kazumasa Utashiro

# LICENSE

Copyright 2025-2026 Kazumasa Utashiro.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
