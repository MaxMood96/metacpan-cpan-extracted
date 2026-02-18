# App::Greple::md Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement `App::Greple::md` module that colorizes Markdown syntax with cumulative coloring for nested elements (links inside headings), usable standalone via `greple -Mmd` and from mdee via `--cm` overrides.

**Architecture:** Module uses `--print &colorize` to handle all colorization in a custom Perl function. Patterns are processed in priority order: code protection → links (OSC 8) → headings (cumulative) → emphasis → other. Colors are registered via `--cm LABEL=spec` in `__DATA__`, overridable by later `--cm` options. State variable tracks fenced code blocks across lines.

**Tech Stack:** Perl 5.24+, App::Greple 9.23+, Getopt::EX::Config, URI::Escape, Term::ANSIColor::Concise (via `main::color()`)

**Working directory:** `/Users/utashiro/Git/tecolicom/Greple/public/md/`

**Reference files:**
- Design doc: `/Users/utashiro/Git/tecolicom/App-mdee/docs/plans/2026-02-16-greple-md-module-design.md`
- Current mdee patterns/colors: `/Users/utashiro/Git/tecolicom/App-mdee/script/mdee` lines 169-257
- Test markdown: `/Users/utashiro/Git/tecolicom/App-mdee/t/test.md`
- Reference module (stripe): `/Users/utashiro/Git/tecolicom/Greple/public/stripe/lib/App/Greple/stripe.pm`
- Reference module (tee): `/Users/utashiro/Git/tecolicom/Greple/public/tee/lib/App/Greple/tee.pm`

---

## Phase 1: Module Implementation

### Task 1: Module Skeleton

Set up the module structure with Config, finalize(), empty colorize(), and minimal `__DATA__`.

**Files:**
- Modify: `lib/App/Greple/md.pm`
- Modify: `cpanfile` (add URI::Escape dependency)

**Step 1: Write module skeleton**

Replace the stub `lib/App/Greple/md.pm` with:

```perl
package App::Greple::md;

use 5.024;
use warnings;

our $VERSION = "0.01";

use Getopt::EX::Config;

my $config = Getopt::EX::Config->new(
    mode => '',      # light / dark
    osc8 => 1,       # OSC 8 hyperlinks
);

sub finalize {
    my($mod, $argv) = @_;
    if ($config->{mode} eq 'dark') {
        $mod->setopt(default => '--md-dark');
    }
}

sub colorize {
    $_;
}

1;

__DATA__

option default \
    -G --all --need=0 --filestyle=once --color=always \
    -E '(?!)' \
    --print &__PACKAGE__::colorize

option --md-light

option --md-dark
```

Note: Start with `-G` (grep mode, per-line processing). The `colorize()` function will receive one line at a time in `$_`.

**Step 2: Add URI::Escape to cpanfile**

Add `requires 'URI::Escape';` to cpanfile.

**Step 3: Verify compilation**

Run: `prove t/00_compile.t`
Expected: PASS

**Step 4: Verify greple -Mmd runs**

Run: `greple -Mmd -Ilib t/test.md 2>/dev/null | head -5` (create a small `t/test.md` if needed, or use `/Users/utashiro/Git/tecolicom/App-mdee/t/test.md`)
Expected: Uncolored passthrough of first 5 lines

**Step 5: Commit**

```bash
git add lib/App/Greple/md.pm cpanfile
git commit -m "feat: module skeleton with Config, finalize, and __DATA__"
```

---

### Task 2: Verify --print Behavior and Code Block State Machine

Determine how `--print` delivers text (per-line with `-G`), then implement fenced code block detection using a state machine.

**Files:**
- Modify: `lib/App/Greple/md.pm`

**Step 1: Verify per-line delivery**

Run test to confirm `--print` gets one line at a time with `-G`:

```bash
greple -G -e '(?!)' --all --need=0 \
    --print 'sub{ "[" . length($_) . "]" . $_ }' \
    -Ilib t/test.md | head -10
```

Expected: Each line prefixed with its length, confirming per-line delivery.

**Step 2: Implement code block state machine**

In `md.pm`, add state variables and code block detection to `colorize()`:

```perl
my $in_code_block = 0;
my $code_fence_re;

sub colorize {
    # Code block state tracking
    if ($in_code_block) {
        if (/^ {0,3}$code_fence_re\s*$/) {
            $in_code_block = 0;
            return main::color('code_fence', $_);
        }
        return main::color('code_body', $_);
    }
    if (/^( {0,3})(`{3,}|~{3,})(.*)/) {
        $in_code_block = 1;
        my $char = quotemeta(substr($2, 0, 1));
        my $len = length($2);
        $code_fence_re = qr/${char}{${len},}/;
        my $fence_line = "$1$2";
        my $lang = $3;
        my $result = main::color('code_fence', $fence_line);
        $result .= main::color('code_lang', $lang) if length($lang);
        $result .= "\n" if /\n$/;
        return $result;
    }

    # (other patterns will be added in subsequent tasks)
    $_;
}
```

**Step 3: Add code block colors to __DATA__**

```
option default \
    -G --all --need=0 --filestyle=once --color=always \
    --cm code_fence=L20 \
    --cm code_lang=L18 \
    --cm code_body=/L23;E \
    -E '(?!)' \
    --print &__PACKAGE__::colorize
```

Note: The current mdee `code_block` key uses comma-separated colors for 4 capture groups: `'L20 , L18 , /L23;E , L20'`. In the module, these become separate `--cm` labels: `code_fence` (opening+closing), `code_lang` (language specifier), `code_body` (body with background).

**Step 4: Test code block colorization**

Run: `greple -Mmd -Ilib /Users/utashiro/Git/tecolicom/App-mdee/t/test.md 2>/dev/null | head -30`
Expected: Code blocks should be visibly colored (gray text/background)

**Step 5: Commit**

```bash
git add lib/App/Greple/md.pm
git commit -m "feat: code block colorization with state machine"
```

---

### Task 3: Inline Code and Comment Protection

Add inline code and HTML comment colorization. These must be processed early to protect their content from emphasis/link matching.

**Files:**
- Modify: `lib/App/Greple/md.pm`

**Step 1: Add inline code pattern**

In `colorize()`, after the code block check, add inline code replacement. Use a protection mechanism: replace matched regions with placeholders, process other patterns, then restore.

```perl
# Protection mechanism: replace regions with NUL-delimited placeholders
my @protected;

sub protect {
    my $text = shift;
    push @protected, $text;
    "\x00" . $#protected . "\x00";
}

sub restore {
    my $s = shift;
    $s =~ s/\x00(\d+)\x00/$protected[$1]/g;
    $s;
}

sub colorize {
    @protected = ();

    # ... code block handling (return early) ...

    # Inline code: protect from further processing
    s/((`++)(?:(?!\g{-2}).)+\g{-2})/protect(main::color('inline_code', $1))/ge;

    # HTML comments: protect from further processing
    s/(^<!--(?![->]).*?-->)/protect(main::color('comment', $1))/gme;

    # (links, headings, emphasis in later tasks)

    $_ = restore($_);
    $_;
}
```

Note: The `protect/restore` mechanism ensures inline code like `` `**bold**` `` is not processed as bold. NUL bytes are safe as placeholders since they don't appear in normal text.

**Step 2: Add colors to __DATA__**

Add to `option default`:
```
    --cm inline_code=L15/L23 \
    --cm comment=CM+r60 \
```

Note: `comment` color in mdee is `${base}+r60` (base color + reddish). For standalone default, use a hardcoded approximation. mdee will override via `--cm`.

**Step 3: Test inline code protection**

Create test: a line with `` `**not bold**` `` should show inline code color, NOT bold.
Run: `echo '`**not bold**` but **this is bold**' | greple -Mmd -Ilib 2>/dev/null`
Expected: First part colored as inline code, second part not yet colored (bold not implemented yet)

**Step 4: Commit**

```bash
git add lib/App/Greple/md.pm
git commit -m "feat: inline code and comment colorization with protection"
```

---

### Task 4: Link Patterns with OSC 8

Add link, image, and image_link patterns with OSC 8 hyperlink generation.

**Files:**
- Modify: `lib/App/Greple/md.pm`

**Step 1: Add osc8 function and link patterns**

```perl
use URI::Escape;

sub osc8 {
    return $_[1] unless $config->{osc8};
    my($url, $text) = @_;
    my $escaped = uri_escape_utf8($url, "^\\x20-\\x7e");
    "\e]8;;${escaped}\e\\${text}\e]8;;\e\\";
}
```

**Step 2: Add link processing to colorize()**

After inline code protection, before headings:

```perl
# Link text inner pattern
my $LT = qr/(?:`[^`\n]*+`|\\.|[^`\\\n\]]++)+/;

# Image links: [![alt](img)](url) → !linked to img + [alt] linked to url
s{\[!\[($LT)\]\(([^)\n]+)\)\]\(<?([^>)\s\n]+)>?\)}{
    protect(
        osc8($2, main::color('image_link', "!"))
        . osc8($3, main::color('image_link', "[$1]"))
    )
}ge;

# Images: ![alt](url)
s{!\[($LT)\]\(<?([^>)\s\n]+)>?\)}{
    protect(osc8($2, main::color('image', "![$1]")))
}ge;

# Links: [text](url) (not preceded by !)
s{(?<!!)  \[($LT)\]\(<?([^>)\s\n]+)>?\)}{
    protect(osc8($2, main::color('link', "[$1]")))
}xge;
```

Links are protected so heading colorization can be applied cumulatively on top.

**Step 3: Add link colors to __DATA__**

```
    --cm link=CU \
    --cm image=CU \
    --cm image_link=CU \
```

Note: In mdee, link/image/image_link use `sub{...}` function specs for OSC 8. In the module, OSC 8 is handled directly in `colorize()`, so `--cm` colors are simple color specs. The default `CU` (cyan underline) is a reasonable standalone default. mdee can override.

**Step 4: Test link colorization**

Run: `echo '[click here](https://example.com)' | greple -Mmd -Ilib 2>/dev/null | cat -v`
Expected: Output contains OSC 8 escape sequences wrapping the link text

**Step 5: Commit**

```bash
git add lib/App/Greple/md.pm
git commit -m "feat: link/image/image_link with OSC 8 hyperlinks"
```

---

### Task 5: Heading Patterns with Cumulative Coloring

Add h1-h6 heading patterns. Apply AFTER link processing so heading color wraps around link-colored text (cumulative coloring).

**Files:**
- Modify: `lib/App/Greple/md.pm`

**Step 1: Add heading patterns to colorize()**

After link processing, before emphasis:

```perl
# Headings: apply color to entire line (cumulative over links)
# Process h6 first (most #'s) to avoid h1 matching h6 lines
s/^(######+\h+.*)$/main::color('h6', $1)/me;
s/^(#####\h+.*)$/main::color('h5', $1)/me;
s/^(####\h+.*)$/main::color('h4', $1)/me;
s/^(###\h+.*)$/main::color('h3', $1)/me;
s/^(##\h+.*)$/main::color('h2', $1)/me;
s/^(#\h+.*)$/main::color('h1', $1)/me;
```

Note: Process from h6 to h1. Each regex is anchored with `^...$` and `m` flag for multiline. Since links are already colored (and protected), heading color is applied cumulatively on top.

**Step 2: Add heading colors to __DATA__**

Light mode defaults (in `option default` or `option --md-light`):
```
    --cm h1=L25DE/<RoyalBlue>=y25 \
    --cm h2=L25DE/<RoyalBlue>=y25+y20 \
    --cm h3=L25DN/<RoyalBlue>=y25+y30 \
    --cm h4=<RoyalBlue>=y25;UD \
    --cm h5=<RoyalBlue>=y25;U \
    --cm h6=<RoyalBlue>=y25 \
```

Dark mode overrides (in `option --md-dark`):
```
option --md-dark \
    --cm h1=L00DE/<RoyalBlue>=y80 \
    --cm h2=L00DE/<RoyalBlue>=y80-y15 \
    --cm h3=L00DN/<RoyalBlue>=y80-y25 \
    --cm h4=<RoyalBlue>=y80;UD \
    --cm h5=<RoyalBlue>=y80;U \
    --cm h6=<RoyalBlue>=y80 \
```

Note: mdee's `${base}` expansion is done in Bash. For module defaults, the base color is hardcoded. mdee will override all colors via `--cm` passthrough anyway.

**Step 3: Test cumulative heading + link coloring**

Run: `echo '## See [docs](https://example.com) here' | greple -Mmd -Ilib 2>/dev/null | cat -v`
Expected: The line has both h2 color (background) and link color (inside the link text), with OSC 8 sequences preserved.

**Step 4: Commit**

```bash
git add lib/App/Greple/md.pm
git commit -m "feat: heading colorization with cumulative coloring over links"
```

---

### Task 6: Emphasis Patterns (Bold, Italic, Strike)

Add bold, italic, and strikethrough patterns. These are processed after headings.

**Files:**
- Modify: `lib/App/Greple/md.pm`

**Step 1: Add emphasis patterns to colorize()**

After heading processing:

```perl
# Bold: **text** and __text__
s/(?<![\\`])\*\*.*?(?<!\\)\*\*/main::color('bold', $&)/ge;
s/(?<![\\`\w])__.*?(?<!\\)__(?!\w)/main::color('bold', $&)/ge;

# Italic: _text_ and *text*
s/(?<![\\`\w])_(?:(?!_).)+(?<!\\)_(?!\w)/main::color('italic', $&)/ge;
s/(?<![\\`\*])\*(?:(?!\*).)+(?<!\\)\*(?!\*)/main::color('italic', $&)/ge;

# Strikethrough: ~~text~~
s/(?<![\\`])~~.+?(?<!\\)~~/main::color('strike', $&)/ge;
```

Note: These patterns are identical to current mdee patterns. The `(?<![\\`])` lookbehind provides backslash and backtick protection. The protect/restore mechanism handles inline code, so backtick protection in the regex is belt-and-suspenders safety.

**Step 2: Add emphasis colors to __DATA__**

```
    --cm bold=<RoyalBlue>=y25;D \
    --cm italic=I \
    --cm strike=X \
```

**Step 3: Test emphasis inside headings**

Run:
```bash
printf '## This is **bold** in heading\n**standalone bold**\n`**not bold**`\n' \
    | greple -Mmd -Ilib 2>/dev/null | cat -v
```
Expected: Bold inside heading gets both heading and bold styling. Inline code content is not bolded.

**Step 4: Commit**

```bash
git add lib/App/Greple/md.pm
git commit -m "feat: bold, italic, and strikethrough patterns"
```

---

### Task 7: Blockquote and Horizontal Rule

Add remaining elements.

**Files:**
- Modify: `lib/App/Greple/md.pm`

**Step 1: Add blockquote and horizontal rule to colorize()**

```perl
# Blockquote marker: > at start of line
s/^(>+\h?)(.*)$/main::color('blockquote', $1) . $2/me;

# Horizontal rule: 3+ of -, *, or _ (possibly with spaces)
s/^([ ]{0,3}(?:[-*_][ ]*){3,})$/main::color('horizontal_rule', $1)/me;
```

Note: For blockquotes, only the `>` marker is colored (not the content), matching typical Markdown viewer behavior. Content may contain other elements (bold, links) which are already processed.

**Step 2: Add colors to __DATA__**

```
    --cm blockquote=<RoyalBlue>=y25;D \
    --cm horizontal_rule=L15 \
```

**Step 3: Test**

Run: `printf '> quoted **bold** text\n---\n' | greple -Mmd -Ilib 2>/dev/null | cat -v`
Expected: `>` marker colored, bold within quote colored, `---` colored as horizontal rule.

**Step 4: Commit**

```bash
git add lib/App/Greple/md.pm
git commit -m "feat: blockquote and horizontal rule patterns"
```

---

### Task 8: Complete __DATA__ Color Definitions

Finalize the `__DATA__` section with complete light and dark mode color definitions.

**Files:**
- Modify: `lib/App/Greple/md.pm`

**Step 1: Write complete __DATA__ section**

```
__DATA__

option default \
    -G --all --need=0 --filestyle=once --color=always \
    --cm code_fence=L20 \
    --cm code_lang=L18 \
    --cm code_body=/L23;E \
    --cm inline_code=L15/L23 \
    --cm comment=L15 \
    --cm link=CU \
    --cm image=CU \
    --cm image_link=CU \
    --cm h1=L25DE/<RoyalBlue>=y25 \
    --cm h2=L25DE/<RoyalBlue>=y25+y20 \
    --cm h3=L25DN/<RoyalBlue>=y25+y30 \
    --cm h4=<RoyalBlue>=y25;UD \
    --cm h5=<RoyalBlue>=y25;U \
    --cm h6=<RoyalBlue>=y25 \
    --cm bold=<RoyalBlue>=y25;D \
    --cm italic=I \
    --cm strike=X \
    --cm blockquote=<RoyalBlue>=y25;D \
    --cm horizontal_rule=L15 \
    -E '(?!)' \
    --print &__PACKAGE__::colorize

option --md-dark \
    --cm code_fence=L10 \
    --cm code_lang=L12 \
    --cm code_body=/L05;E \
    --cm inline_code=L12/L05 \
    --cm h1=L00DE/<RoyalBlue>=y80 \
    --cm h2=L00DE/<RoyalBlue>=y80-y15 \
    --cm h3=L00DN/<RoyalBlue>=y80-y25 \
    --cm h4=<RoyalBlue>=y80;UD \
    --cm h5=<RoyalBlue>=y80;U \
    --cm h6=<RoyalBlue>=y80 \
    --cm bold=<RoyalBlue>=y80;D \
    --cm blockquote=<RoyalBlue>=y80;D
```

Note: Dark mode only overrides colors that differ from light. Labels like `italic`, `strike`, `link`, `image`, `image_link`, `horizontal_rule` are the same in both modes, so they only appear in `option default`.

**Step 2: Test light mode**

Run: `greple -Mmd -Ilib /Users/utashiro/Git/tecolicom/App-mdee/t/test.md 2>/dev/null | head -30`
Expected: Colored output with light mode colors

**Step 3: Test dark mode**

Run: `greple -Mmd::config(mode=dark) -Ilib /Users/utashiro/Git/tecolicom/App-mdee/t/test.md 2>/dev/null | head -30`
Expected: Colored output with dark mode colors

**Step 4: Commit**

```bash
git add lib/App/Greple/md.pm
git commit -m "feat: complete light/dark color definitions in __DATA__"
```

---

### Task 9: Add Tests

Add functional tests beyond the compilation test.

**Files:**
- Create: `t/01_colorize.t`
- Create: `t/test.md` (small test markdown file)

**Step 1: Create test markdown file**

```markdown
# Heading 1

## Heading 2 with [link](https://example.com)

Normal text with **bold** and *italic*.

`inline code with **not bold**`

```bash
code block
```

> blockquote

---

~~strikethrough~~
```

**Step 2: Write colorize test**

```perl
use strict;
use Test::More;
use open qw(:std :encoding(utf-8));

# Test that module loads
use_ok('App::Greple::md');

# Test that greple -Mmd produces output
my $test_md = 't/test.md';
plan skip_all => "greple not found" unless `which greple`;

my $out = `greple -Mmd -Ilib $test_md 2>/dev/null`;
ok(length($out) > 0, "greple -Mmd produces output");

# Output should contain ANSI escape sequences (colored)
like($out, qr/\e\[/, "output contains ANSI color sequences");

# Test that code blocks are protected
my $code_test = '`**not bold**`';
my $code_out = `echo '$code_test' | greple -Mmd -Ilib 2>/dev/null`;
# The **not bold** should NOT have bold ANSI codes applied separately

# Test dark mode
my $dark_out = `greple '-Mmd::config(mode=dark)' -Ilib $test_md 2>/dev/null`;
ok(length($dark_out) > 0, "dark mode produces output");

done_testing;
```

**Step 3: Run tests**

Run: `prove -v t/`
Expected: All tests pass

**Step 4: Commit**

```bash
git add t/01_colorize.t t/test.md
git commit -m "test: add functional tests for colorize"
```

---

### Task 10: Integration Test with mdee's test.md

Verify the module handles all Markdown elements in mdee's comprehensive test file.

**Files:**
- No new files

**Step 1: Full visual test with light mode**

Run: `greple -Mmd -Ilib /Users/utashiro/Git/tecolicom/App-mdee/t/test.md 2>/dev/null | less -R`

Verify:
- [ ] Headers h1-h6 are colored with decreasing prominence
- [ ] Bold text is bold with base color
- [ ] Italic text is italic
- [ ] Strikethrough has strikethrough styling
- [ ] Inline code has background color
- [ ] Code blocks have background color, fence and language colored differently
- [ ] Links show as `[text]` with clickable OSC 8 (on supported terminals)
- [ ] Images show as `![alt]` with clickable OSC 8
- [ ] Blockquote `>` marker is colored
- [ ] Horizontal rules are colored
- [ ] HTML comments are colored
- [ ] Links inside headings have both heading color AND link color
- [ ] Bold inside inline code is NOT processed as bold

**Step 2: Full visual test with dark mode**

Run: `greple '-Mmd::config(mode=dark)' -Ilib /Users/utashiro/Git/tecolicom/App-mdee/t/test.md 2>/dev/null | less -R`

Verify same elements with dark-appropriate colors.

**Step 3: Test --cm override**

Run: `greple -Mmd --cm h1=RD -Ilib /Users/utashiro/Git/tecolicom/App-mdee/t/test.md 2>/dev/null | head -5`
Expected: h1 heading should be red+bold instead of default blue

**Step 4: Fix any issues found and commit**

```bash
git add -A
git commit -m "fix: address integration test findings"
```

---

## Phase 2: mdee Integration

### Task 11: Modify mdee's run_greple to Use -Mmd

Replace mdee's pattern/color building logic with `-Mmd` module invocation.

**Files:**
- Modify: `/Users/utashiro/Git/tecolicom/App-mdee/script/mdee`

**Step 1: Modify run_greple()**

The current `run_greple()` passes many `--cm`/`-E` pairs built by `add_pattern`. Replace with:

```bash
run_greple() {
    local -a md_opts=()

    # Pass mode via config
    md_opts+=("-Mmd::config(mode=${mode})")

    # Pass all color overrides from theme
    for name in "${!colors[@]}"; do
        [[ $name == base ]] && continue
        md_opts+=(--cm "${name}=${colors[$name]}")
    done

    # Pass show visibility (disable hidden fields)
    for name in "${!show[@]}"; do
        local val=${show[$name]}
        [[ ! $val || $val == 0 ]] && md_opts+=(--cm "${name}=")
    done

    invoke greple "${md_opts[@]}" \
        --filestyle=once --color=always \
        "$@"
}
```

Note: The module's `__DATA__` `option default` defines base options (`-G --all --need=0 -E '(?!)' --print &colorize`). mdee only needs to pass mode config and color overrides.

**Step 2: Remove old pattern/color building code**

Remove from mdee:
- `osc8_prologue`, `link_func`, `image_func`, `image_link_func` variables (lines 174-177)
- `greple_opts` array initialization (line 564)
- `add_pattern()` function (lines 566-571)
- The `for _name in ...` loop that builds greple_opts (lines 575-577)

Keep:
- `patterns_default` array (still needed for fold/table patterns)
- `pattern` associative array (still needed for fold/table)
- Theme system, colors array, expand_theme

**Step 3: Handle color label mapping**

mdee's theme uses `code_block` and `inline_code` as single keys with comma-separated values. The module uses `code_fence`, `code_lang`, `code_body` as separate labels.

In the color override loop, split these:

```bash
# Split composite color keys for module compatibility
if [[ $name == code_block ]]; then
    IFS=', ' read -ra parts <<< "${colors[$name]}"
    md_opts+=(--cm "code_fence=${parts[0]:-}")
    md_opts+=(--cm "code_lang=${parts[1]:-}")
    md_opts+=(--cm "code_body=${parts[2]:-}")
    continue
fi
if [[ $name == inline_code ]]; then
    # Module uses single inline_code label
    IFS=', ' read -ra parts <<< "${colors[$name]}"
    md_opts+=(--cm "inline_code=${parts[1]:-}")  # use middle part (body)
    continue
fi
```

**Step 4: Test mdee with -Mmd**

Run: `./script/mdee -f /Users/utashiro/Git/tecolicom/App-mdee/t/test.md`
Expected: Colored output matching previous mdee behavior (approximately)

**Step 5: Test mdee pipeline (fold + table)**

Run: `./script/mdee /Users/utashiro/Git/tecolicom/App-mdee/t/test.md`
Expected: Full pipeline (highlight → fold → table → nup) works

**Step 6: Commit**

```bash
cd /Users/utashiro/Git/tecolicom/App-mdee
git add script/mdee
git commit -m "feat: use App::Greple::md module for highlight processing"
```

---

### Task 12: mdee Cleanup

Remove code that is now handled by the module.

**Files:**
- Modify: `/Users/utashiro/Git/tecolicom/App-mdee/script/mdee`

**Step 1: Remove unused highlighting code**

Remove:
- `osc8_prologue` variable
- `link_func`, `image_func`, `image_link_func` variables
- `add_pattern()` function
- The pattern-to-greple-opts loop
- `greple_opts` array (replaced by `md_opts` in `run_greple`)

Keep:
- `patterns_default` (fold/table patterns: `item_prefix`, `def_pattern`, `autoindent`, `table`, `code_block`, `comment`)
- `pattern` associative array
- All theme/color code (themes still need `code_block`, `inline_code` etc. for `--list-themes` display)

**Step 2: Verify all mdee features still work**

```bash
# Filter mode
./script/mdee -f t/test.md

# Pager mode
./script/mdee -p t/test.md

# Nup mode
./script/mdee t/test.md

# Dark mode
./script/mdee --mode=dark -f t/test.md

# Theme override
./script/mdee --no-theme -f t/test.md

# Show field visibility
./script/mdee --show all= --show bold -f t/test.md

# List themes
./script/mdee --list-themes
```

**Step 3: Commit**

```bash
cd /Users/utashiro/Git/tecolicom/App-mdee
git add script/mdee
git commit -m "refactor: remove highlighting code replaced by App::Greple::md"
```

---

## Key Design Decisions

### Color Label Mapping (mdee → module)

| mdee theme key | Module --cm label(s) | Notes |
|---|---|---|
| `h1`-`h6` | `h1`-`h6` | Direct mapping |
| `bold` | `bold` | Direct |
| `italic` | `italic` | Direct |
| `strike` | `strike` | Direct |
| `comment` | `comment` | Direct |
| `code_block` | `code_fence`, `code_lang`, `code_body` | Split into 3 labels |
| `inline_code` | `inline_code` | Module uses single label |
| `link` | `link` | mdee's `sub{...}` func spec → module's simple color |
| `image` | `image` | Same as link |
| `image_link` | `image_link` | Same as link |

### Protection Mechanism

NUL-byte placeholders protect processed regions (inline code, comments, links) from being matched by later patterns. This replaces the current approach where greple handles pattern independence through separate `-E` entries.

### State Machine vs Multiline Regex

Code blocks use a per-line state machine instead of multiline regex because `-G` mode delivers one line at a time to `--print`. This is simpler and avoids questions about non-`-G` mode behavior with `--print`.
