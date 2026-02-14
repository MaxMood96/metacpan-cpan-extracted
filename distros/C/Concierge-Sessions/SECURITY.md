# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.9.x   | Yes                |
| < 0.9.0 | No                 |

## Reporting a Vulnerability

If you discover a security vulnerability in Concierge::Sessions, please
report it responsibly.

**Contact:** Bruce Van Allen <bva@cruzio.com>

**Response timeline:**

- Acknowledgement within 48 hours
- Initial assessment within 7 days
- Fix or mitigation plan within 30 days

Please include:

- A description of the vulnerability
- Steps to reproduce the issue
- Any potential impact assessment
- Suggested fix, if available

**Do not** open a public GitHub issue for security vulnerabilities. Use the
email address above for responsible disclosure.

## Known CVEs

- **CVE-2026-2439**: Insecure session ID generation via `uuidgen`/`rand`
  fallback. Fixed in v0.8.5. Session IDs are now generated using
  cryptographically secure random bytes via Crypt::PRNG.

## Best Practices

When using Concierge::Sessions in production:

- Keep the module updated to the latest supported version
- Use the SQLite backend (`database`) for production deployments
- Set appropriate `session_timeout` values for your use case
- Call `cleanup_sessions()` periodically to remove expired sessions
- Store session database files in directories with restricted permissions (0700)
- Use HTTPS for all session ID transport
