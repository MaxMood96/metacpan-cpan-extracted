# Uniform::HTMX::Mojolicious

[![CPAN version](https://badge.fury.io/pl/Uniform-HTMX-Mojolicious.svg)](https://metacpan.org/pod/Uniform::HTMX::Mojolicious)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Framework-agnostic htmx adapter for the Mojolicious ecosystem.

`Uniform::HTMX::Mojolicious` inherits directly from `Uniform::HTMX` to bridge Mojolicious controllers with htmx request inspection and response manipulation methods.

---

## Installation

Install using `cpanm` or your preferred CPAN client:

```bash
cpanm Uniform::HTMX::Mojolicious
```

---

## Synopsis

```perl
use Mojolicious::Lite;
use Uniform::HTMX::Mojolicious;

get '/time' => sub {
    my $c    = shift;
    my $htmx = Uniform::HTMX::Mojolicious->new($c);

    if ($htmx->is_htmx) {
        $htmx->res_reswap('innerHTML')
             ->res_trigger('timeUpdated', { time => scalar localtime });

        $htmx->apply($c);
        return $c->render(text => '<div>Time updated!</div>');
    }

    $c->render(text => 'Standard request');
};

app->start;
```

---

## Key Features

* **Controller Integration:** Native extraction of `HX-*` request headers directly from `Mojolicious::Controller` objects.
* **Direct Response Application:** Injects queued htmx response headers straight into `$c->res->headers`.
* **Header Injection Safety:** Sanitizes response values to prevent CRLF injection vulnerabilities.

---

## Local Development & Testing

Run the test suite using `prove`:

```bash
prove -Ilib t/
```

Run the live example application using `morbo`:

```bash
morbo examples/app.pl
```

---

## License and Copyright

This software is Copyright (c) 2026 by Joshua S. Day `<HAX@cpan.org>`.

This is free software, licensed under:

```text
The MIT (X11) License
```
