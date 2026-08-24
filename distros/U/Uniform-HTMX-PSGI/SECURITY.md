# Security Policy

## Supported Versions

Security updates are applied to the latest major release of `Uniform::HTMX::PSGI`.

Version 1.03

---

## Reporting a Vulnerability

If you discover a potential security vulnerability in `Uniform::HTMX::PSGI`, please report it privately rather than opening a public issue.

* **Email Contact:** Joshua S. Day `<HAX@cpan.org>`
* **Response Time:** You will receive an acknowledgment within 48 hours and regular updates on resolution progress.

Please include:
* A description of the vulnerability and potential impact.
* A minimal reproduction script or PSGI payload.
* Suggested fix (if available).

---

## Security Architecture Notes

* **HTTP Header Injection:** Outbound header values passed through `res_*` methods are sanitized via `Uniform::HTMX` base validation to reject carriage return (`\r`) and linefeed (`\n`) characters, preventing response-splitting attacks.
* **Input Normalization:** Header key extraction strictly verifies data structure types and ignores non-scalar or malformed inputs.
