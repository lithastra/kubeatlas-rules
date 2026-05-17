# Copyright 2026 The KubeAtlas Authors
# SPDX-License-Identifier: Apache-2.0
#
# Istio Gateway: TLS-credential edge.
#
# A Gateway (networking.istio.io) configures an L4-L6 load balancer
# at the edge of the mesh. A server that terminates TLS names the
# Kubernetes Secret holding its certificate through
# spec.servers[].tls.credentialName.
#
# Edge: Gateway -> Secret (USES_TLS_SECRET). Istio resolves the
# credentialName Secret in the namespace of the Gateway resource, so
# that is the Secret's namespace.
#
# Anti-patterns guarded:
#   * Servers without TLS (plain HTTP), or with a TLS mode that uses
#     no Secret (PASSTHROUGH, or file-mounted certs), carry no
#     credentialName and derive no edge.
#   * No edge for an empty credentialName.
#   * The Gateway's spec.selector (a pod label selector) is NOT
#     turned into an edge — label-selector fan-out needs a cluster
#     listing the per-resource rego engine does not provide.
package kubeatlas.rules.istio.gateway

import rego.v1

derive contains edge if {
	some server in object.get(input.spec, "servers", [])
	name := server.tls.credentialName
	name != ""
	edge := {
		"type": "USES_TLS_SECRET",
		"from": {
			"kind": "Gateway",
			"namespace": input.metadata.namespace,
			"name": input.metadata.name,
		},
		"to": {
			"kind": "Secret",
			"namespace": input.metadata.namespace,
			"name": name,
		},
	}
}
