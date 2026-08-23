# Security Policy for Alien-SNMP

This is the Security Policy for the CPAN distribution Alien-SNMP.

## How to report a security vulnerability

Security vulnerabilities can be reported via the project's GitHub repository
Security Advisories, at
<https://github.com/ollyg/Alien-SNMP/security/advisories>. On that page, click
the "Report a vulnerability" button.

If you do not have access to GitHub, or if you would like help triaging the
issue, or if the issue is being actively exploited, please report it to the
CPAN Security Group (CPANSec) at cpan-security@security.metacpan.org.

Please do not use the public GitHub issue tracker to report security
vulnerabilities, and please do not disclose a vulnerability in public forums
until the maintainers or CPANSec have made it public. That includes patches,
pull requests and mitigation advice.

Please include as many details as possible, including code samples or test
cases, so that the issue can be reproduced. Check that your report does not
expose any sensitive data, such as passwords, tokens, or personal information.

The maintainers will normally credit the reporter when a vulnerability is
disclosed or fixed. If you do not want to be credited publicly, please say so
in your report.

For more information, see [Report a Security
Issue](https://security.metacpan.org/docs/report.html) on the CPANSec website.

### What to expect

This distribution is maintained by volunteers in their spare time, and no rapid
response can be guaranteed. If you have not received a response within a week,
please send a reminder and copy the report to CPANSec at
cpan-security@security.metacpan.org.

The initial response will be an acknowledgement, possibly with a request for
more information. It will not necessarily include a fix.

The maintainers may forward the report to the security contacts of other
projects where it is relevant, including Net-SNMP upstream, and to CPANSec.

## What this policy covers

Alien-SNMP downloads, builds and installs the Net-SNMP C library and the Perl
`SNMP` and `NetSNMP::*` XS modules bundled with it. This policy covers:

  * vulnerabilities in Alien-SNMP's own code and build configuration, including
    the integrity of the source tarball it downloads and verifies, and the
    options it configures Net-SNMP with;
  * the Net-SNMP version this distribution pins, where a newer Net-SNMP release
    fixes a known vulnerability that affects users of Alien-SNMP.

Vulnerabilities in Net-SNMP itself should be reported to the Net-SNMP project
at <https://github.com/net-snmp/net-snmp>. Where such a vulnerability affects
users of Alien-SNMP, the maintainers will pin a fixed Net-SNMP release. The
security policy of the Net-SNMP source this distribution builds is included in
that source and is not modified by this distribution.

Vulnerabilities in prerequisite modules, in Perl itself, or in software that
merely uses Alien-SNMP, are not covered by this policy unless Alien-SNMP can be
used to exploit them.

## Which versions are supported

The maintainers will release security fixes for the latest released version of
Alien-SNMP only.

Each release pins exactly one Net-SNMP version, recorded in this distribution's
version number and in the `alienfile`. Security fixes to the bundled Net-SNMP
are delivered by pinning a newer Net-SNMP release, not by patching an older one.

## Installation and usage notes

This distribution always builds Net-SNMP from source; it never links against a
Net-SNMP already installed on the system. A vulnerability in the operating
system's Net-SNMP packages therefore does not affect the library this
distribution installs, and vice versa.

The distribution metadata specifies minimum versions of its prerequisites.
Some of those prerequisites may have their own vulnerabilities, and you should
keep them up to date.

## About this policy

This policy was updated on 2026-08-22.

If this policy or this release is more than two years old, then you should
check for a more recent version of Alien-SNMP on CPAN, or on the master branch
of the Alien-SNMP git repository.

This text is based on the CPAN Security Group's Guidelines for Adding a
Security Policy to Perl Distributions (version 1.5.0),
<https://security.metacpan.org/docs/guides/security-policy-for-authors.html>.
