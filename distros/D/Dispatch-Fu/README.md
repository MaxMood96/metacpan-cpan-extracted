# Dispatch::Fu

`Dispatch::Fu` is a small, production-worthy Perl module intended for production use. It turns arbitrary
input into a static dispatch key and then uses that key to select a handler
from a hash-based dispatch table.

It is intended for situations where ordinary hash dispatch is attractive, but
the value that determines the action is not already a convenient one-to-one
hash key. The `dispatch` block performs whatever classification or reduction
your application needs; the resulting static key is matched to a handler
registered with `on`.

The implementation is deliberately lightweight. Runtime dependencies are
limited to Perl core modules, and the public interface stays focused on five
routines:

- `dispatch` — compute a key and invoke the corresponding handler.
- `on` — register a static key/handler pair for a dispatch operation.
- `cases` — inspect the currently registered case names.
- `xdefault` — return a case name when it exists, otherwise a default key.
- `xshift_and_deref` — shift and dereference common reference types in one step.

The distribution includes regression tests for repeated dispatch, case
introspection, default handling, diagnostics, return-value behavior, reference
unpacking, invalid handlers, and false-but-valid dispatch keys.

## Example

```perl
use strict;
use warnings;
use Dispatch::Fu;    # exports dispatch, on, cases, xdefault, xshift_and_deref

my $input = [qw/1 2 3 4 5/];

my $result = dispatch {
    my $values = shift;

    return scalar(@$values) > 5
      ? q{bucket5}
      : sprintf q{bucket%d}, scalar @$values;
}
$input,
  on bucket0 => sub { return q{bucket 0} },
  on bucket1 => sub { return q{bucket 1} },
  on bucket2 => sub { return q{bucket 2} },
  on bucket3 => sub { return q{bucket 3} },
  on bucket4 => sub { return q{bucket 4} },
  on bucket5 => sub { return q{bucket 5} };

print "$result\n";    # bucket 5
```

The dispatch block is ordinary Perl. It can classify a range, inspect multiple
values stored in a reference, normalize external input, apply application
rules, or perform any other deterministic reduction that produces one of the
registered keys.

## Why use Dispatch::Fu?

A conventional Perl dispatch table is concise and fast when the decision is
already represented by a static string:

```perl
my $handlers = {
    start => sub { ... },
    stop  => sub { ... },
};

$handlers->{$action}->();
```

`Dispatch::Fu` keeps that simple final lookup while adding an explicit stage for
computing the key. This makes it useful for cases traditionally expressed as
long `if`/`elsif` chains, switch/case constructs, `given`/`when`, smartmatch
logic, or other ad hoc classification code.

```perl
my $result = dispatch {
    my $value = shift;

    return q{small}  if $value < 10;
    return q{medium} if $value < 100;
    return q{large};
}
$value,
  on small  => sub { ... },
  on medium => sub { ... },
  on large  => sub { ... };
```

## Defaults and introspection

`xdefault` is a shortcut for the common case where an input value should be
used directly when it exactly names a registered case. Matching is literal,
not substring or regular-expression matching, and false-but-defined keys such
as `"0"` are valid:

```perl
my $result = dispatch {
    xdefault shift;
}
$action,
  on default => sub { ... },
  on start   => sub { ... },
  on stop    => sub { ... };
```

`cases` returns the currently registered case names in sorted order. During
the classification block it includes the cases registered with `on` plus the
built-in `default` case. The table is reset before the selected handler runs,
so outside the classification block `cases` reflects only the built-in
`default` case. This keeps dispatch calls isolated from one another.

## CGI::Tiny example

A small CGI application is a natural fit when the action depends on more than
one request value. Here the dispatch key is derived from both the HTTP method
and request path, while the selected handler receives the original
`CGI::Tiny` object:

```perl
use strict;
use warnings;
use CGI::Tiny;
use Dispatch::Fu;

cgi {
    my $cgi = $_;

    dispatch {
        my $cgi = shift;
        my $method = $cgi->method;
        my $path   = $cgi->path;

        return q{home}
          if $method eq q{GET} and $path eq q{/};

        return q{create_item}
          if $method eq q{POST} and $path eq q{/item};

        return q{not_found};
    }
    $cgi,
      on home => sub {
          my $cgi = shift;
          return $cgi->render(html => q{<h1>Home</h1>});
      },
      on create_item => sub {
          my $cgi = shift;
          my $name = $cgi->param(q{name});
          return $cgi->render(text => qq{created: $name});
      },
      on not_found => sub {
          my $cgi = shift;
          $cgi->set_response_status(404);
          return $cgi->render(text => q{Not Found});
      };
};
```

This is useful for modest CGI programs with a small static set of actions; it
is not intended to replace a full routing framework.

## Reference unpacking

`dispatch` passes one scalar value to the classification block and selected
handler. When that scalar is a reference, `xshift_and_deref` can remove common
unpacking boilerplate:

```perl
my ($x, $y, $z) = xshift_and_deref @_;
```

It supports hash, array, and scalar references.

## Diagnostics

`Dispatch::Fu` detects common dispatch mistakes and reports them clearly. It
croaks when no cases are supplied, croaks when the computed key does not map to
a CODE handler, and warns when `on` is accidentally used in void or scalar
context (a common sign that a semicolon was used where a comma was intended).

## Stability

`Dispatch::Fu` is maintained as production code rather than a proof of concept.
The module intentionally keeps a small API and implementation surface, and
changes should preserve existing calling conventions and lightweight runtime
requirements. See `Changes` for release history and `t/` for executable usage
examples and regression coverage.

## License

Same terms as Perl itself.

