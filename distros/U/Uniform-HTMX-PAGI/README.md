# Uniform::HTMX::PAGI

[![CPAN version](https://badge.fury.io/pl/Uniform-HTMX-PAGI.svg)](https://metacpan.org/pod/Uniform::HTMX::PAGI)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Framework-agnostic htmx adapter for the PAGI asynchronous web application environment.

`Uniform::HTMX::PAGI` inherits directly from `Uniform::HTMX`[cite: 5] to bridge incoming PAGI environment headers with outbound htmx response triggers and headers in asynchronous execution pipelines[cite: 5].

---

## Installation

Install using `cpanm` or your preferred CPAN client:

```bash
cpanm Uniform::HTMX::PAGI
```

---

## Synopsis

```perl
use strict;
use warnings;
use Uniform::HTMX::PAGI;

my $app = sub {
    my $env  = shift;
    my $htmx = Uniform::HTMX::PAGI->new($env);

    if ($htmx->is_htmx) {
        my $target = $htmx->target;

        # Accumulate outbound htmx headers via native base methods
        $htmx->res_trigger('itemSaved', { id => 42 })
             ->res_reswap('innerHTML');
    }

    my $res = [ 200, [ 'Content-Type' => 'text/html' ], [ '<div>Saved via PAGI!</div>' ] ];

    # Inject accumulated headers into response structure
    return $htmx->apply($res);
};
```

---

## Key Features

* **Direct Object Inheritance:** Subclasses `Uniform::HTMX` directly using native base initialization[cite: 5].
* **Asynchronous Response Support:** Flattens and injects htmx response headers directly into PAGI response arrays[cite: 5].
* **Header Injection Safety:** Sanitizes response values to prevent CRLF injection vulnerabilities.

---

## Local Development & Testing

Run the test suite using `prove`:

```bash
prove -Ilib t/
```

---

## License and Copyright

This software is Copyright (c) 2026 by Joshua S. Day `<HAX@cpan.org>`[cite: 6, 7].

This is free software, licensed under:

```text
The MIT (X11) License
```
