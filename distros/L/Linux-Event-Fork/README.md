# Linux::Event::Fork

[![CI](https://github.com/haxmeister/perl-linux-event-fork/actions/workflows/ci.yml/badge.svg)](https://github.com/haxmeister/perl-linux-event-fork/actions/workflows/ci.yml)

Minimal async child spawning on top of **Linux::Event**.

---

## CI Notes

If GitHub Actions fails during:

```
Run shogo82148/actions-setup-perl@v1
install perl
Error: Error: failed to verify ...
```

This is an upstream attestation verification issue in the action, not a problem
with this distribution.

If it occurs, you can fix CI by either:

1. Pinning to a specific action release tag instead of `@v1`
2. Disabling verification in the action config (if supported)
3. Switching to `actions/setup-perl` alternative

This does not affect CPAN builds.
