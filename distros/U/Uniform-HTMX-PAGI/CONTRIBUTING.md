# Contributing to Uniform::HTMX::PAGI

Thank you for considering contributing! Community feedback and pull requests help keep this module reliable and secure.

---

## Development Setup

1. **Fork and Clone the Repository:**
   ```bash
   git clone [https://github.com/haxmeister/perl-Uniform-HTMX-PAGI.git](https://github.com/haxmeister/perl-Uniform-HTMX-PAGI.git)
   cd perl-Uniform-HTMX-PAGI
   ```

2. **Install Dependencies:**
   Ensure `Uniform::HTMX` (v0.15+) and test requirements are installed[cite: 7]:
   ```bash
   cpanm --installdeps .
   ```

3. **Run the Test Suite:**
   All pull requests must pass the full test suite cleanly:
   ```bash
   prove -Ilib -v t/
   ```

---

## Guidelines

* **Code Style:** Follow standard Perl best practices (`use strict; use warnings;`).
* **Test Coverage:** Any bug fix or new feature must include unit tests in `t/`[cite: 8].
* **Backward Compatibility:** Maintain proper handling for standard PAGI response structure arrays[cite: 5].

---

## Pull Request Process

1. Create a feature branch off `main` (`git checkout -b feature/my-feature`).
2. Commit your changes with concise commit messages.
3. Push to your branch and submit a Pull Request on GitHub[cite: 7].
