# Uniform::Upload

[![CPAN version](https://badge.fury.io/pl/Uniform-Upload.svg)](https://metacpan.org/pod/Uniform::Upload)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Framework-agnostic upload manager and base driver engine for Perl.

`Uniform::Upload` provides a unified interface for inspecting, validating, and managing file upload payloads across web applications. It serves as both a standalone file upload factory and an abstract base engine for framework-specific drivers.

---

## Installation

Install using `cpanm` or your preferred CPAN client:

```bash
cpanm Uniform::Upload
```

---

## Synopsis

```perl
use Uniform::Upload;

# Initialize standalone manager
my $upload = Uniform::Upload->new(
    max_size      => '5MB',
    allowed_types => [qw( image/png image/jpeg application/pdf )],
);

# Wrap raw upload payload hashes into validated objects
my $file = $upload->wrap(
    name     => 'avatar',
    filename => 'user_photo.png',
    tmp_path => '/tmp/cpan_upload_12345',
    size     => 2048576,
    type     => 'image/png',
);

if ($file->is_valid) {
    $file->copy_to('/var/uploads/' . $file->sanitized_filename);
} else {
    die "Upload failed validation: " . $file->error;
}
```

---

## Key Features

* **Flexible Limit Parsing:** Human-readable size constraints (e.g., `'10MB'`, `'500KB'`) parsed via `Uniform::Utils`.
* **Automated Sanitization:** Strips path traversal constructs (`../../../etc/passwd`) from user filenames.
* **Extensible Architecture:** Designed for subclassing using `parent` and `SUPER::new` constructor delegation[cite: 2].
* **Structured Error Exceptions:** Uses `Uniform::Exceptions` for file handling failures.

---

## Local Development & Testing

Run the test suite using `prove`:

```bash
prove -Ilib t/
```

---

## License and Copyright

This software is Copyright (c) 2026 by Joshua S. Day `<HAX@cpan.org>`[cite: 9, 10].

This is free software, licensed under:

```text
The MIT (X11) License
```
