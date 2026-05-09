# Contributing rule packs

KubeAtlas's edge model is extensible: anything beyond the
eight built-in edge types (OWNS, USES_CONFIGMAP, …) lives in
a Rego rule pack. This repository is the home of community-
maintained packs that the engine pulls in via OCI artifacts.

If you can write a small Rego rule that derives an edge from
a CRD's spec, you can ship a pack here in a single PR.

## Repo layout

Each pack is a top-level directory:

```
<pack-name>/
├── metadata.yaml       — pack manifest (name, version, rego_api, modules)
├── *.rego              — one file per module
├── tests/
│   └── *_test.rego     — opa test cases
└── samples/
    └── *.yaml          — real CRD samples integration tests load
```

Keep packs flat — one pack = one folder, no nested children.
The release-time `release.yml` workflow walks the top-level
directories and ships each as its own OCI artifact.

## Required files for a new pack

A PR that adds a pack must include all four of:

1. `metadata.yaml` — see `sample/metadata.yaml` for the exact
   shape; `rego_api: v1` is the engine's current contract.
2. At least one `.rego` module under the pack root.
3. A matching `tests/<module>_test.rego` with `opa test`
   cases that pin the rule's expected output for both the
   happy path and at least one negative case (input that
   should NOT produce an edge).
4. A `samples/*.yaml` real-world CRD example. The
   `make integration` target loads this through the engine
   in P2-T13's `kubeatlas rules-test` CLI to assert the rule
   produces the documented edge end-to-end.

## Rego style

The engine runs OPA v1 syntax — that means `if` is required
in rule bodies and `:=` for assignments. Quick reference:

```rego
package kubeatlas.rules.<pack>.<module>

import rego.v1

derive contains edge if {
    input.kind == "<Kind>"
    edge := {
        "type": "<EDGE_TYPE>",
        "from": { "kind": ..., "namespace": ..., "name": ... },
        "to":   { "kind": ..., "namespace": ..., "name": ... },
    }
}
```

`derive` is a SET of edge maps. Each entry MUST have `type`,
`from`, and `to`. `from` and `to` carry exactly the three
fields `kind`, `namespace`, `name`; the engine refuses any
other shape (see `pkg/extractor/rego/decode.go`).

Do not write rules that produce edges the built-in extractor
already covers — `OwnerReference` is handled in core, so a
pack that emits `OWNS` for the OwnerReference relationship is
a duplicate. Use a pack-specific edge type (`ROUTES_TO`,
`STORES_IN`, etc.) for relationships the core does not model.

## CI gates

Every PR runs three jobs:

- `make check` — `opa check` for syntax + reference errors
  across every pack you touched.
- `make test` — `opa test` for the unit cases in `tests/`.
- `make integration` — loads each modified pack into the
  KubeAtlas engine via the `kubeatlas rules-test` CLI and
  asserts each `samples/` YAML produces at least one edge.

All three must be green before merge. There are no
"skip checks for typos" exceptions; the gates are 0.5s cheap.

## Versioning + release

Each pack tracks its own semver in `metadata.yaml`. Bumps
follow the standard rules (patch = bug fix, minor = new edges
without breaking existing, major = breaking change to edge
type names or shapes). When a pack reaches a stable state, a
maintainer pushes a tag `<pack>/v<version>`; the release
workflow packs the directory into an OCI artifact and pushes
to `ghcr.io/lithastra/rules/<pack>:<version>`.

Tag format: forward slash separated. Example:
`openshift/v0.1.0`, `cert-manager/v0.2.1`. The CI relies on
this layout to discover which pack a tag belongs to.

## Conventional Commits + DCO

Same rules as the kubeatlas main repo:

- Subject lines follow Conventional Commits
  (`feat(<pack>): …`, `fix(<pack>): …`, `docs:`, `chore:`).
  The `<pack>` scope is optional for cross-cutting changes
  but expected for pack-local edits.
- Every commit is signed off (`git commit -s`). The DCO bot
  blocks merges that miss this.
- English only in source, comments, commits, and PR bodies.
  Localised docs (if any) live under `docs/<locale>/`.

## Filing a PR

1. Fork + branch.
2. Add the pack folder, populate the four required files.
3. Run `make check test integration` locally; all green.
4. Open the PR. Expect a maintainer review within a few days;
   tag a relevant steward (see `MAINTAINERS.md`) for faster
   domain feedback.

A trivial new pack can land within a day. Larger packs
(20+ rules, custom samples, dependency on a beta CRD) may
need design discussion in a GitHub Issue first — please open
one before writing 1000 lines of Rego.
