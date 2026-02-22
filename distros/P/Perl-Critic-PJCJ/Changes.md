# Revision history for Perl::Critic::PJCJ

## v0.2.2 - 2026-02-21

- Close release ticket automatically when PR is merged

## v0.2.1 - 2026-02-21

- Fix set -e exit in `detect_version` when verbose is off
- Skip git hooks during `dzil release` via `$ENV{DZIL_RELEASING}`
- Set release commit message to `Release vX.Y.Z`

## v0.2.0 - 2026-02-21

- Add `allow_lines_matching` parameter to ProhibitLongLines for exempting lines
  that match regex patterns (e.g. long package declarations, URLs)
- Add missing List::Util runtime prerequisite
- Remove dead code in RequireConsistentQuoting
- Unify release workflow with confirmation checkpoints (`make release`)
- Move setup recipe into `utils/run`; skip in CI environments
- Fix experimental signatures warning in `dev/append_postamble`
- Add Perl 5.42 to CI matrix

## v0.1.4 - 2025-08-31

- No changes from v0.1.3-TRIAL

## v0.1.3-TRIAL - 2025-08-31

- Enhance use/no statement handling in RequireConsistentQuoting policy:
  - Add interpolation detection
    - Statements requiring variable interpolation follow normal rules
  - Add support for `no` statements
  - Add fat comma (=>) detection
    - Statements with hash-style arguments have no parentheses
  - Add complex expression detection
    - Statements with variables, conditionals, etc. have no parentheses
    - Add version number exemption
- Improve single quote and q() handling

## v0.1.2 - 2025-07-26

- Initial release
- Perl::Critic::Policy::ValuesAndExpressions::RequireConsistentQuoting policy
- Perl::Critic::Policy::CodeLayout::ProhibitLongLines policy
