# Uniform::Upload::PAGI

[![CPAN version](https://badge.fury.io/pl/Uniform-Upload-PAGI.svg)](https://metacpan.org/pod/Uniform::Upload::PAGI)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Asynchronous PAGI framework adapter for `Uniform::Upload`.

`Uniform::Upload::PAGI` bridges asynchronous PAGI application HTTP request streams with the `Uniform::Upload` file validation and extraction engine.

---

## Installation

Install using `cpanm` or your preferred CPAN client:

```bash
cpanm Uniform::Upload::PAGI
```

---

## Synopsis

```perl
use Uniform::Upload::PAGI;

# Initialize driver with a PAGI scope and options
my $uploader = Uniform::Upload::PAGI->new(
    $scope,
    max_size      => '10M',
    allowed_types => [qw( image/png image/jpeg application/pdf )],
);

# Asynchronously read payload stream and extract wrapped file objects
$uploader->extract_async($receive)->then(sub {
    my ($files) = @_; # Arrayref of Uniform::Upload::File objects

    for my $file (@$files) {
        if ($file->is_valid) {
            $file->copy_to('/var/uploads/' . $file->sanitized_filename);
        } else {
            warn "Upload invalid: " . $file->error;
        }
    }
});
```

---

## Running the Example

Run the included PAGI upload simulation script:

```bash
perl -Ilib examples/demo.pl
```

---

## Local Development & Testing

Execute the test suite using `prove`:

```bash
prove -Ilib -v t/
```

---

## License and Copyright

This software is Copyright (c) 2026 by Joshua S. Day `<HAX@cpan.org>`.

This is free software, licensed under:

```text
The MIT (X11) License
```
