<p align="center">
  <img src="assets/jinja2tt2.png" alt="Jinja2tt2 Logo">
</p>

# Jinja2tt2

[![License: LGPL v2.1](https://img.shields.io/badge/License-LGPL_v2.1-blue.svg)](https://www.gnu.org/licenses/lgpl-2.1)
[![Perl Version](https://img.shields.io/badge/perl-5.20+-blue.svg)](https://www.perl.org/)
[![CPAN](https://img.shields.io/badge/CPAN-Jinja2--TT2-blue.svg)](https://metacpan.org/pod/Jinja2::TT2)

**Jinja2 to Template Toolkit Transpiler**

A Perl transpiler that converts Jinja2 templates to Template Toolkit 2 (TT2) syntax.

## Description

Jinja2 is deeply integrated with Python, making a direct port impractical. However, since TT2 and Jinja2 share similar concepts and syntax patterns, this transpiler performs a **mechanical translation** between the two template languages.

### Why TT2?

TT2 and Jinja2 share:

- Variable interpolation: `{{ var }}` maps to `[% var %]`
- Control structures: `{% if %}` / `{% for %}` map to `[% IF %]` / `[% FOREACH %]`
- Filters: `{{ name|upper }}` maps to `[% name | upper %]`
- Includes, blocks, and inheritance (conceptually similar)
- Expression grammar close enough to map mechanically

## Installation

No external dependencies beyond core Perl 5.20+.

```bash
git clone https://github.com/lucianofedericopereira/jinja2tt2
cd jinja2tt2
```

## Usage

### Command Line

```bash
# Transpile a file to stdout
./bin/jinja2tt2 template.j2

# Transpile with output to file
./bin/jinja2tt2 template.j2 -o template.tt

# Transpile in-place (creates .tt file)
./bin/jinja2tt2 -i template.j2

# From stdin
echo '{{ name|upper }}' | ./bin/jinja2tt2

# Debug mode (shows tokens and AST)
./bin/jinja2tt2 --debug template.j2
```

### Programmatic Usage

```perl
use Jinja2::TT2;

my $transpiler = Jinja2::TT2->new();

# From string
my $tt2 = $transpiler->transpile('{{ user.name|upper }}');
# Result: [% user.name.upper %]

# From file
my $tt2 = $transpiler->transpile_file('template.j2');
```

## Supported Constructs

### Variables

```jinja2
{{ foo }}           →  [% foo %]
{{ user.name }}     →  [% user.name %]
{{ items[0] }}      →  [% items.0 %]
```

### Filters

```jinja2
{{ name|upper }}              →  [% name.upper %]
{{ name|lower|trim }}         →  [% name.lower.trim %]
{{ items|join(", ") }}        →  [% items.join(', ') %]
{{ name|default("Guest") }}   →  [% (name || 'Guest') %]
```

### Conditionals

```jinja2
{% if user %}          →  [% IF user %]
{% elif admin %}       →  [% ELSIF admin %]
{% else %}             →  [% ELSE %]
{% endif %}            →  [% END %]
```

### Loops

```jinja2
{% for item in items %}    →  [% FOREACH item IN items %]
{{ loop.index }}           →  [% loop.count %]
{{ loop.first }}           →  [% loop.first %]
{{ loop.last }}            →  [% loop.last %]
{% endfor %}               →  [% END %]
```

### Blocks and Macros

```jinja2
{% block content %}        →  [% BLOCK content %]
{% endblock %}             →  [% END %]

{% macro btn(text) %}      →  [% MACRO btn(text) BLOCK %]
{% endmacro %}             →  [% END %]
```

### Comments

```jinja2
{# This is a comment #}    →  [%# This is a comment %]
```

### Whitespace Control

```jinja2
{{- name -}}               →  [%- name -%]
{%- if x -%}               →  [%- IF x -%]
```

### Other Constructs

- `{% include "file.html" %}` → `[% INCLUDE file.html %]`
- `{% set x = 42 %}` → `[% x = 42 %]`
- Ternary: `{{ x if cond else y }}` → `[% (cond ? x : y) %]`
- Boolean literals: `true`/`false` → `1`/`0`

## Filter Mapping

| Jinja2 | TT2 Equivalent |
|--------|----------------|
| `upper` | `.upper` |
| `lower` | `.lower` |
| `trim` | `.trim` |
| `first` | `.first` |
| `last` | `.last` |
| `length` | `.size` |
| `join` | `.join` |
| `reverse` | `.reverse` |
| `sort` | `.sort` |
| `escape` / `e` | `\| html_entity` |
| `default` | `\|\|` operator |
| `replace` | `.replace` |

Some filters require TT2 plugins (e.g., `tojson` needs `Template::Plugin::JSON`).

## Loop Variable Mapping

| Jinja2 | TT2 |
|--------|-----|
| `loop.index` | `loop.count` |
| `loop.index0` | `loop.index` |
| `loop.first` | `loop.first` |
| `loop.last` | `loop.last` |
| `loop.length` | `loop.size` |

## Limitations

- **Template inheritance** (`{% extends %}`) requires manual adjustment for TT2's `WRAPPER` pattern
- **Autoescape** is not directly supported in TT2
- Some filters need custom TT2 plugins or vmethods
- Complex Python expressions may need review

## Running Tests

```bash
prove -l t/
```

## Project Structure

```
jinja2tt2/
├── assets/
│   └── jinja2tt2.png       # Logo
├── bin/
│   └── jinja2tt2           # CLI tool
├── lib/Jinja2/
│   ├── TT2.pm              # Main module
│   └── TT2/
│       ├── Tokenizer.pm    # Lexical analysis
│       ├── Parser.pm       # Syntax analysis → AST
│       ├── Emitter.pm      # AST → TT2 code
│       └── Filters.pm      # Filter mapping table
├── t/                      # Test suite
└── examples/               # Example templates
```

## Architecture

1. **Tokenizer**: Splits Jinja2 source into tokens (text, variables, statements, comments)
2. **Parser**: Builds an Abstract Syntax Tree (AST) from the token stream
3. **Emitter**: Walks the AST and generates equivalent TT2 code

## Credits

- **Luciano Federico Pereira** - Author

## License

This is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License (LGPL) version 2.1 as published by the Free Software Foundation.

See the [LICENSE](LICENSE) file for the full license text.
