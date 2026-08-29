# Security Policy

This is the security policy for the Perl **Typesense-Client** distribution.

## Reporting a Vulnerability

**Please do not report security issues on public GitHub issues, pull requests
or any other public forum.**

Use GitHub's private vulnerability reporting:
<https://github.com/SeHarrys/typesense-client-perl/security/advisories/new>

Include enough information to reproduce the issue (Perl version, Typesense
server version, minimal code sample, expected vs observed behaviour). Do not
include API keys, tokens, or personal data in the report.

If you need help triaging or the issue is being actively exploited, you may
also contact the CPAN Security Group (CPANSec) at
<cpan-security@security.metacpan.org>.

## Supported Versions

Only the latest released version of Typesense::Client is supported with
security fixes. The distribution requires Perl 5.38 or later; older Perls are
out of scope. It is developed and tested against Typesense server 28.

## Handling API keys

This client exists to send an API key to a search engine, so a few notes on
where those keys can end up:

- **The key travels in the `X-TYPESENSE-API-KEY` header on every request.**
  `Mojo::UserAgent`'s own debug output prints request headers, so running with
  `MOJO_CLIENT_DEBUG=1` writes the key to STDERR in the clear. Do not enable it
  in production, and do not paste that output into a bug report.

- **`keys->create` returns the new key in the clear exactly once.** Typesense
  stores only a hash afterwards and cannot give it back. Whatever you do with
  that response, do not log it.

- **Error objects are safe to log.** `Typesense::Client::Error` carries the
  HTTP status, the method and path, and the server's own error body. It never
  carries the API key, so `warn $err` will not leak it.

## Scoped search keys

`keys->scoped` derives a key locally, by signing the embedded parameters. Three
things about it are easy to get wrong:

- **Derive it from a search-only key, never from the admin key.** A scoped key
  inherits the permissions of the key it was derived from; the embedded
  `filter_by` narrows the results, it does not narrow the permissions.

- **The embedded parameters are signed, not encrypted.** Anyone holding the
  scoped key can base64-decode it and read what is inside, exactly as intended
  by the design - the signature stops them changing it, not reading it. Do not
  embed anything that is itself a secret.

- **Set `expires_at`.** A scoped key handed to a browser is as long-lived as
  you made it.

## `filter_by` is a query language, not a bound parameter

This client passes search parameters through untouched, by design. Typesense's
filter syntax has boolean operators, so interpolating untrusted input into a
filter is an injection, in the same way SQL string-building is:

    # a caller-controlled $id is not a value here, it is an expression
    filter_by => "customer_id:=$id"

    # with $id = '7 || customer_id:>0', this matches every document
    # in the collection, not the seven customer's

That applies both to a filter sent with a search and to one baked into a scoped
key. Validate the value, or build the filter from data you control.

## Disclosure

The maintainer will acknowledge reports as soon as possible (no guaranteed
SLA - this is a volunteer project) and coordinate a fix and public disclosure
date with the reporter.

---

If this policy is more than two years old, check the latest version on
[CPAN](https://metacpan.org/dist/Typesense-Client) or the
[git repository](https://github.com/SeHarrys/typesense-client-perl).
