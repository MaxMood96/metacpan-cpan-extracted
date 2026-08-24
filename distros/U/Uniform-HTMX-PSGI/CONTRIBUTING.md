# Contributing to Uniform::HTMX::PSGI

Thank you for considering contributing! Community feedback and pull requests help keep this module reliable and secure.

---

## Development Setup

1. **Fork and Clone the Repository:**
   ```bash
   git clone [https://github.com/your-username/Uniform-HTMX-PSGI.git](https://github.com/your-username/Uniform-HTMX-PSGI.git)
   cd Uniform-HTMX-PSGI
   ```

2. **Install Dependencies:**
   Ensure you have `Uniform::HTMX` installed or cloned locally:
   ```bash
   cpanm --installdeps .
   ```

3. **Run the Test Suite:**
   All pull requests must pass the test suite cleanly:
   ```bash
   prove -Ilib -v t/
   ```

4. **Test Live in Browser:**
   Use the included PSGI script to verify browser interaction end-to-end:
   ```bash
   plackup -Ilib app.psgi
   ```

---

## Guidelines

* **Code Style:** Follow standard Perl best practices (`use strict; use warnings;`).
* **Minimal Dependencies:** Avoid adding heavy runtime dependencies unless strictly required.
* **Test Coverage:** Any bug fix or new feature must include a corresponding test in `t/`.
* **Backward Compatibility:** Ensure changes do not break standard PSGI arrayref responses or `Plack::Response` object handling.

---

## Pull Request Process

1. Create a feature branch off `main` (`git checkout -b feature/my-feature`).
2. Commit your changes with clear, descriptive commit messages.
3. Push to your branch and submit a Pull Request.
4. Ensure all continuous integration checks pass.
