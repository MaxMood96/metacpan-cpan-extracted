# Contributing to Uniform::Upload

Thank you for considering contributing to `Uniform::Upload`! Community contributions keep the `Uniform::*` ecosystem secure and robust.

---

## Development Setup

1. **Fork and Clone the Repository:**
   ```bash
   git clone [https://github.com/haxmeister/perl-Uniform-Upload.git](https://github.com/haxmeister/perl-Uniform-Upload.git)
   cd perl-Uniform-Upload
   ```

2. **Install Dependencies:**
   Install build prerequisites (`Uniform::Exceptions` and `Uniform::Utils`)[cite: 10]:
   ```bash
   cpanm --installdeps .
   ```

3. **Run the Test Suite:**
   All PRs must pass tests cleanly:
   ```bash
   prove -Ilib -v t/
   ```

---

## Creating Extension Drivers

When creating framework drivers (e.g., `Uniform::Upload::Plack` or `Uniform::Upload::Catalyst`), inherit directly from `Uniform::Upload` and delegate constructor arguments using `SUPER::new`:

```perl
package Uniform::Upload::MyFramework;

use strict;
use warnings;
use parent 'Uniform::Upload';

sub new {
    my ($class, $req, %args) = @_;
    return $class->SUPER::new(in => $req, %args);
}

sub extract {
    my ($self) = @_;
    # Extract payload hash refs and invoke $self->wrap(%hash)
}

1;
```

---

## Pull Request Process

1. Create a topic branch off `main` (`git checkout -b feature/my-feature`).
2. Add tests in `t/` for new functionality.
3. Submit a Pull Request on GitHub.
