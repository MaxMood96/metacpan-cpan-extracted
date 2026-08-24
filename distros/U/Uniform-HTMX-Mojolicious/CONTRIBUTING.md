# Contributing to Uniform::HTMX::Mojolicious

Thank you for considering contributing! Community feedback and pull requests help keep this module reliable and secure.

---

## Development Setup

1. **Fork and Clone the Repository:**
   ```bash
   git clone [https://github.com/haxmeister/perl-Uniform-HTMX-Mojolicious.git](https://github.com/haxmeister/perl-Uniform-HTMX-Mojolicious.git)
   cd perl-Uniform-HTMX-Mojolicious
   ```

2. **Install Dependencies:**
   Ensure `Uniform::HTMX` and `Mojolicious` dependencies are installed:
   ```bash
   cpanm --installdeps .
   ```

3. **Run the Test Suite:**
   All pull requests must pass the test suite cleanly:
   ```bash
   prove -Ilib -v t/
   ```

---

## Guidelines

* **Code Style:** Follow standard Perl best practices (`use strict; use warnings;`).
* **Test Coverage:** Any bug fix or new feature must include corresponding unit tests in `t/`.
* **Backward Compatibility:** Ensure changes maintain support for standard `Mojolicious::Controller` objects.

---

## Pull Request Process

1. Create a feature branch off `main` (`git checkout -b feature/my-feature`).
2. Commit your changes with clear, descriptive commit messages.
3. Push to your branch and submit a Pull Request on GitHub.
