# perlomp

`perlomp` is a Perl-manual-style introduction to using OpenMP from Perl.

After installing it from CPAN:

```text
cpanm perlomp
perldoc perlomp
```

The manual explains how these pieces fit together:

- `OpenMP::Environment` — manages and validates OpenMP-related `%ENV` values.
- `OpenMP::Simple` — supplies OpenMP build/link configuration and `PerlOMP_*`
  helpers for `Inline::C`.
- `OpenMP` — convenience metapackage for installing and tying together the
  standard Perl OpenMP stack.
- `Alien::OpenMP` — discovers the compiler and OpenMP runtime configuration.

To install the full OpenMP stack rather than only this manual:

```text
cpanm OpenMP
```

## Development

This distribution uses Dist::Zilla.

```text
dzil test
dzil build
```

The indexed `lib/perlomp.pm` file exists only to give PAUSE/CPAN a package and
version to index. The actual manual is `lib/perlomp.pod`, following the same
basic pattern used by documentation distributions such as `perlfaq`.

## License

Same terms as Perl itself.
