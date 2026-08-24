# Uniform::HTMX::Dancer2

[![CPAN version](https://badge.fury.io/pl/Uniform-HTMX-Dancer2.svg)](https://metacpan.org/pod/Uniform::HTMX::Dancer2)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A lightweight, seamless HTMX integration plugin for [Dancer2](https://metacpan.org/pod/Dancer2) applications, built on the [Uniform::HTMX](https://metacpan.org/pod/Uniform::HTMX) base layer.

---

## Features

* **Zero-Boilerplate Inspection:** Quickly check if a request came from HTMX via `is_htmx`.
* **Clean Response Mutators:** Easily set `HX-Trigger`, `HX-Retarget`, `HX-Redirect`, and other HTMX response headers.
* **Automatic Header Flushing:** Accumulated response headers are written back onto the Dancer2 response for you via an `after` hook — no manual `apply()` call required.
* **Unified API:** Shared engine with `Uniform::HTMX`, so the same method names and behavior carry over across PSGI, PAGI, and Mojolicious integrations.

---

## Installation

Install directly from CPAN using `cpanm`:

```bash
cpanm Uniform::HTMX::Dancer2
```

Or from a checkout of this distribution:

```bash
cpanm --installdeps .
perl Makefile.PL
make
make test
make install
```

---

## Synopsis

```perl
use Dancer2;
use Uniform::HTMX::Dancer2;

get '/items' => sub {
    if (is_htmx) {
        htmx->res_retarget('#item-list');
        htmx->res_trigger('itemsLoaded', { count => 10 });
        return template 'partials/items' => {}, { layout => undef };
    }

    return template 'full_page';
};

start;
```

A runnable demo app lives in [`examples/app.pl`](examples/app.pl).

---

## Documentation

Full method documentation lives in the module's POD:

```bash
perldoc Uniform::HTMX::Dancer2
```

or on [MetaCPAN](https://metacpan.org/pod/Uniform::HTMX::Dancer2) once released.

---

## Testing

```bash
prove -Ilib -v t/
```

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Security

See [SECURITY.md](SECURITY.md).

## License

This software is Copyright (c) 2026 by Joshua S. Day.

This is free software, licensed under the [MIT License](LICENSE).
