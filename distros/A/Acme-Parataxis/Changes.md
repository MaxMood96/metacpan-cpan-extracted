# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v0.0.5] - 2026-02-18

### Changed
- I'm honeslty just throwing stuff at the wall. Between my local machines and GH CI workflows, I cannot replicate some of the failures I'm seeing from smokers which makes them virtually impossible to resolve.

## [v0.0.4] - 2026-02-17

### Changed

  - Attempt to only spawn max X threads in `t/006_parallel.t` where X is 3 or the `get_thread_pool_size()`? See https://www.cpantesters.org/cpan/report/ecf1410e-0c46-11f1-8628-aee76d8775ea
  - Recalculate `PL_curpad = AvARRAY(PL_comppad)` in `swap_perl_state`? See https://www.cpantesters.org/cpan/report/e7244bd8-0c44-11f1-b3ab-94362698fc84

## [v0.0.3] - 2026-02-17

### Changed
  - Adding an optional timeout to `await_read` and `await_write`.
  - Allow fibers to return complex data (AV*, HV*).

## [v0.0.2] - 2026-02-17

### Fixed
  - Fixed segfault in `coro_yield` by adding NULL checks for destroyed or missing fibers.
  - Resolved stall in exception handling by introducing `last_sender` tracking to prevent `parent_id` cycles.

### Changed
  - Made unit tests a lot more noisy

## [v0.0.1] - 2026-02-16

### Changes
  - It exists! It shouldn't but it does.

[Unreleased]: https://github.com/sanko/Acme-Parataxis.pm/compare/v0.0.5...HEAD
[v0.0.5]: https://github.com/sanko/Acme-Parataxis.pm/compare/v0.0.4...v0.0.5
[v0.0.4]: https://github.com/sanko/Acme-Parataxis.pm/compare/v0.0.3...v0.0.4
[v0.0.3]: https://github.com/sanko/Acme-Parataxis.pm/compare/v0.0.2...v0.0.3
[v0.0.2]: https://github.com/sanko/Acme-Parataxis.pm/compare/v0.0.1...v0.0.2
[v0.0.1]: https://github.com/sanko/Acme-Parataxis.pm/releases/tag/v0.0.1
