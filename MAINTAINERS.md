# Maintainers

Rule-pack maintenance follows the same maintainer set as the
core engine. The authoritative roster lives in the kubeatlas
main repository and is mirrored here so contributors do not
have to chase two pages:

  https://github.com/lithastra/kubeatlas/blob/main/MAINTAINERS.md

For rule-pack-specific decisions (which packs ship in the
default catalogue, semver bumps that affect downstream
KubeAtlas compat) the same maintainers act as approvers; no
separate pack-level governance until a pack ships its own
sub-team.

## Pack stewards

Long-running rule packs may designate stewards who shepherd
domain-specific changes (e.g. an OpenShift expert for the
`openshift/` pack, a cert-manager committer for
`cert-manager/`). Stewards have approver rights on the
relevant pack only; merging still requires a maintainer
review. Stewards register themselves in the pack's own
`metadata.yaml` `maintainers` list.

## Becoming a maintainer

The promotion path is documented in the kubeatlas
GOVERNANCE.md once that file is upgraded from placeholder to
full (planned for the v1.0 release window). Until then any
contributor with a sustained track record of merged rule packs
and reviews can ask in a GitHub Discussion.
