# Copyright 2026 The KubeAtlas Authors
# SPDX-License-Identifier: Apache-2.0
#
# cert-manager Certificate -> Issuer / ClusterIssuer "ISSUED_BY"
# edge.
#
# spec.issuerRef.{kind, name} points at the Issuer that signs this
# Certificate. Two flavours:
#
#   - kind=Issuer (the default when omitted): namespaced; same
#     namespace as the Certificate. cert-manager does not let an
#     Issuer reference cross namespaces.
#   - kind=ClusterIssuer: cluster-scoped; to.namespace is empty so
#     the resource ID is "/ClusterIssuer/<name>".
#
# We do NOT model the issuer's underlying type (CA / SelfSigned /
# ACME / Vault / …) — KubeAtlas tracks topology, not signing
# policy. Inspectors who need that detail read it off the Issuer
# node directly.
package kubeatlas.rules.cert_manager.issuer

import rego.v1

derive contains edge if {
	input.kind == "Certificate"
	input.spec.issuerRef.name != ""
	target_kind := issuer_kind
	target_ns := issuer_namespace(target_kind)
	edge := {
		"type": "ISSUED_BY",
		"from": {
			"kind": "Certificate",
			"namespace": input.metadata.namespace,
			"name": input.metadata.name,
		},
		"to": {
			"kind": target_kind,
			"namespace": target_ns,
			"name": input.spec.issuerRef.name,
		},
	}
}

# issuerRef.kind defaults to "Issuer" when absent — matches the
# cert-manager API server's defaulting webhook.
issuer_kind := k if {
	k := input.spec.issuerRef.kind
	k != ""
}

issuer_kind := "Issuer" if {
	not input.spec.issuerRef.kind
}

issuer_kind := "Issuer" if {
	input.spec.issuerRef.kind == ""
}

# ClusterIssuer is cluster-scoped — KubeAtlas's resource ID
# convention represents that with an empty namespace segment so the
# ID renders as "/ClusterIssuer/<name>". Issuer is namespaced and
# always lives alongside its Certificate.
issuer_namespace("ClusterIssuer") := ""

issuer_namespace(k) := input.metadata.namespace if {
	k != "ClusterIssuer"
}
