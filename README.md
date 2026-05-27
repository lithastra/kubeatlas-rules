# kubeatlas-rules

Community rule packs for the
[KubeAtlas](https://github.com/lithastra/kubeatlas) Rego engine.

KubeAtlas's core ships ten built-in edge types
(`OWNS`, `USES_CONFIGMAP`, `USES_SECRET`, …) that cover every
relationship in the core Kubernetes API. Anything beyond core
— OpenShift Routes, cert-manager Certificates, Argo
Applications, Istio VirtualServices, and more — lives in a Rego
rule pack here.

### Available packs

| Pack | Description |
|---|---|
| **aks** | Azure Kubernetes Service — AAD Pod Identity bindings |
| **argocd** | Argo CD Applications → managed resources |
| **cert-manager** | Certificate → Secret derivation |
| **eks** | Elastic Kubernetes Service — IRSA, VPC CNI, Karpenter |
| **gke** | Google Kubernetes Engine — Workload Identity, managed certs, BackendConfig |
| **istio** | VirtualService / DestinationRule / Gateway routing |
| **knative** | Knative Service → Configuration → Revision chain |
| **openshift** | Routes, DeploymentConfigs, BuildConfigs (also embedded in binary) |
| **strimzi** | Kafka / KafkaTopic / KafkaConnect operator resources |
| **tekton** | Pipeline → Task → Run execution chain |
| **velero** | Backup / Schedule / Restore relationships |

The KubeAtlas binary loads packs from this catalogue at
runtime via OCI artifacts. A typical install:

```yaml
# helm values.yaml
rulePacks:
  openshift: auto       # detected and embedded; no entry here
  extras:
    - oci://ghcr.io/lithastra/rules/cert-manager:0.1.0
    - oci://ghcr.io/lithastra/rules/argocd:0.1.0
```

## Five-minute tour of a rule pack

A pack is a directory plus a manifest. Everything is plain
text; nothing gets compiled.

```
cert-manager/
├── metadata.yaml          name, version, rego_api, modules
├── certificate.rego       Certificate -> Secret edge derivation
├── tests/
│   └── certificate_test.rego   opa test cases
└── samples/
    └── certificate.yaml   real CRD instance (used by integration test)
```

`metadata.yaml` is the engine's contract:

```yaml
name: cert-manager
version: 0.1.0
rego_api: v1                 # KubeAtlas Rego interface version
kubeatlas: ">= 1.0.0"        # semver constraint
modules:
  - name: certificate
    file: certificate.rego
    entrypoint: data.kubeatlas.cert_manager.certificate.derive
    match:
      group: cert-manager.io
      kind: Certificate
```

`certificate.rego` (Rego v1 syntax):

```rego
package kubeatlas.cert_manager.certificate

import rego.v1

derive contains edge if {
    input.kind == "Certificate"
    input.spec.secretName != ""
    edge := {
        "type": "STORES_IN",
        "from": {
            "kind": "Certificate",
            "namespace": input.metadata.namespace,
            "name": input.metadata.name,
        },
        "to": {
            "kind": "Secret",
            "namespace": input.metadata.namespace,
            "name": input.spec.secretName,
        },
    }
}
```

That's the whole shape. KubeAtlas matches the `match` block
against every resource it sees, calls the rule, decodes
`derive`'s output into edges, and adds them to the graph.

## Repo layout

```
kubeatlas-rules/
├── <pack-1>/              one folder per pack, flat
├── <pack-2>/
├── Makefile               check / test / integration entry points
├── CONTRIBUTING.md        how to ship a pack
├── MAINTAINERS.md
├── CODE_OF_CONDUCT.md
├── SECURITY.md
├── DCO
├── LICENSE                Apache 2.0
└── .github/workflows/
    ├── test.yml           per-PR opa check + opa test
    └── release.yml        tag-driven OCI push
```

The release workflow ships each pack as its own OCI artifact
on tag `<pack>/v<version>`. Tags belong to a single pack so
versioning stays independent — `cert-manager/v0.2.0` does
not force an `openshift/v0.2.0`.

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md). Required reading:
the four files every PR needs (metadata, rule, test, sample),
the Rego v1 syntax KubeAtlas runs, and the CI gates.

## Relationship to the main repo

This repository is purely Rego content — no Go code, no CI
that depends on the kubeatlas binary's source. The matching
engine lives in
[lithastra/kubeatlas](https://github.com/lithastra/kubeatlas)
under `pkg/extractor/rego/`. The OpenShift pack you see
embedded in the kubeatlas binary is mirrored here so external
contributors have a single place to land changes; release-time
tooling syncs the two paths.

## License

Apache 2.0 — see [LICENSE](./LICENSE).
