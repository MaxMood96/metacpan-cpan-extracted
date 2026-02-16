# Contributing to Concierge::Auth

Thank you for your interest in contributing to Concierge::Auth.

## Bug Reports

Open an issue at <https://github.com/bwva/Concierge-Auth/issues> with:

- Perl version (`perl -v`)
- Operating system
- Module version
- Minimal reproduction steps
- Expected vs actual behaviour

## Feature Requests

Open an issue describing the use case and proposed behaviour. Discussion
before implementation helps ensure alignment with the project direction.

## Pull Requests

1. Fork the repository
2. Create a topic branch from `main`
3. Make your changes
4. Ensure all tests pass:

```bash
perl Makefile.PL
make test           # Core tests (t/)
```

5. Submit a pull request against `main`

### Code Style

- Perl v5.36+ features (signatures, `use v5.36`)
- Tabs for indentation in Perl source
- POD documentation for public API changes
- ASCII-only in POD sections

### Tests

- New features should include tests in `t/`
- Use Test2::V0

## License

By contributing, you agree that your contributions will be licensed under
the Artistic License 2.0.
