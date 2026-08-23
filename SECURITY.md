# Security Policy

## Supported versions

Only the latest released version of each KubeAtlas rule pack receives security
fixes. A new release of a pack supersedes every older release; the project does
not maintain parallel patch branches or backport fixes to older versions.

## Reporting a vulnerability

**Please do not report security issues via public GitHub issues.**

Email dev@lithastra.com with:

- A description of the vulnerability
- Steps to reproduce
- The affected version (commit SHA if pre-release)
- Your proposed fix, if any

We will acknowledge a report within 7 calendar days. The acknowledgement will
state the next update date. Resolution time depends on severity and complexity;
we coordinate publication with the reporter instead of promising a fixed
deadline before assessment.

## Scope

In scope:

- Rego modules, metadata, samples, and validation tooling maintained in this
  repository
- OCI rule-pack artifacts published to `ghcr.io/lithastra/rules/*`
- Signing, verification, release, and distribution configuration maintained in
  this repository

Out of scope:

- The KubeAtlas server, CLI, Helm Chart, and container images (report issues to
  the main KubeAtlas repository)
- Third-party dependencies and platforms (please report to the upstream
  project)
- User-authored rule packs and deployment misconfigurations
