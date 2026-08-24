# Uniform::HTMX::PSGI

[![CPAN version](https://badge.fury.io/pl/Uniform-HTMX-PSGI.svg)](https://metacpan.org/pod/Uniform::HTMX::PSGI)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Framework-agnostic htmx adapter for the PSGI/Plack ecosystem.

`Uniform::HTMX::PSGI` bridges the `Uniform::HTMX` protocol handler with standard PSGI web applications and Plack response objects. It automatically translates CGI/PSGI environment headers (`HTTP_HX_*`) and injects accumulated outbound htmx response headers directly into PSGI response data structures.

---

## Installation

Install using `cpanm` or your preferred CPAN client:

```bash
cpanm Uniform::HTMX::PSGI
```

---

## Synopsis

```perl
use Uniform::HTMX::PSGI;

my $app = sub {
    my $env  = shift;
    my $htmx = Uniform::HTMX::PSGI->new($env);

    # Inspect incoming htmx request attributes
    if ($htmx->is_htmx) {
        my $target = $htmx->target;
        
        # Queue outbound htmx response headers
        $htmx->res_trigger('itemSaved', { id => 42 })
             ->res_reswap('innerHTML');
    }

    my $res = [ 200, [ 'Content-Type' => 'text/html' ], [ '<div>Saved!</div>' ] ];

    # Inject queued headers into the PSGI response
    return $htmx->apply($res);
};
```

---

## Key Features

* **Zero-Configuration Environment Mapping:** Automatically converts PSGI `%ENV` keys (e.g., `HTTP_HX_REQUEST`, `HTTP_HX_TARGET`) into standard htmx inspection methods.
* **Flexible Response Application:** `apply()` accepts standard PSGI array references `[ $status, \@headers, \@body ]` as well as objects implementing `headers()` or `header()` methods (such as `Plack::Response`).
* **Header Injection Safety:** Inherits strict response validation from `Uniform::HTMX` to prevent CRLF line-injection vulnerabilities.

---

## Local Development & Testing

Run the test suite using `prove`:

```bash
prove -Ilib t/
```

To run the interactive test application locally:

```bash
plackup -Ilib app.psgi
```

---

## License and Copyright

This software is Copyright (c) 2026 by Joshua S. Day `<HAX@cpan.org>`.

This is free software, licensed under:

```text
The MIT (X11) License
```
