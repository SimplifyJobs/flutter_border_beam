# Security Policy

## Supported versions

Fixes land on the latest published minor of `flutter_border_beam`. Older
minors are not patched — upgrade to the newest release on
[pub.dev](https://pub.dev/packages/flutter_border_beam) before reporting.

| Version | Supported |
| --- | --- |
| Latest minor | Yes |
| Anything older | No — upgrade first |

## Reporting a vulnerability

**Do not open a public issue for a security report.**

Use GitHub's private vulnerability reporting: go to the
[Security tab](https://github.com/SimplifyJobs/flutter_border_beam/security)
of the repository and press **Report a vulnerability**. That opens a private
advisory visible only to you and the maintainers.

If you cannot use that form, email **support@simplify.jobs** instead.

Helpful things to include: the package version, the Flutter version and
platform, a minimal reproduction, and what an attacker gains.

## What to expect

- **Acknowledgement within 5 business days.**
- An assessment — whether it is in scope, and the severity we assign it —
  once we have reproduced it.
- A fix released on the latest minor, and a GitHub Security Advisory
  published when the issue warrants one. We are happy to credit you unless
  you would rather stay anonymous.

Please give us a reasonable window to ship a fix before disclosing publicly.

## Scope

This is a **rendering package**. It draws animated borders with Flutter's
canvas API: it opens no sockets, reads and writes no files, stores nothing,
and collects nothing. It has no runtime dependencies beyond the Flutter SDK.
Most of the vulnerability classes a security report usually covers simply
have no surface here.

In scope:

- Attacker-controllable input to the public API — colors, radii, durations,
  a `BeamContour` path — that causes a crash, an unbounded allocation, a hang,
  or an unrecoverable render-loop failure in a host app.
- A compromise of the release path: the publishing workflow, the pub.dev
  automated-publishing configuration, or the published archive's contents.
- Anything in the package that reaches the network or the filesystem. There
  should be nothing; if you find something, that is the report.

Out of scope:

- Visual bugs, jank, and performance that is merely disappointing — those are
  ordinary [issues](https://github.com/SimplifyJobs/flutter_border_beam/issues).
- Frame-rate or battery cost of an animation configured to be expensive.
- Vulnerabilities in Flutter, Dart, or a browser engine — report those to
  their own projects.
- The example gallery and the hosted playground, which contain no data and
  no accounts.
