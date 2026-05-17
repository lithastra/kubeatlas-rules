# Copyright 2026 The KubeAtlas Authors
# SPDX-License-Identifier: Apache-2.0
#
# Istio DestinationRule: traffic-policy edge.
#
# A DestinationRule (networking.istio.io) declares the traffic
# policy — load balancing, connection pool, outlier detection, TLS —
# applied to requests bound for a host. spec.host names that host.
#
# Edge: DestinationRule -> Service (CONFIGURES).
#
# Host resolution is identical to the virtualservice module: a host
# with no dots resolves in the DestinationRule's namespace; a ".svc"
# FQDN carries its own namespace; anything else is an external host
# and derives no edge.
package kubeatlas.rules.istio.destinationrule

import rego.v1

# service_ref resolves an Istio host string to a {name, namespace}
# Service reference. It is undefined for external hosts.

# Short host (no dots): a Service in the DestinationRule's namespace.
service_ref(host, default_ns) := ref if {
	host != ""
	not contains(host, ".")
	ref := {"name": host, "namespace": default_ns}
}

# Cluster FQDN: <name>.<namespace>.svc[.cluster.local].
service_ref(host, _) := ref if {
	parts := split(host, ".")
	count(parts) >= 3
	parts[2] == "svc"
	parts[0] != ""
	parts[1] != ""
	ref := {"name": parts[0], "namespace": parts[1]}
}

derive contains edge if {
	ref := service_ref(input.spec.host, input.metadata.namespace)
	edge := {
		"type": "CONFIGURES",
		"from": {
			"kind": "DestinationRule",
			"namespace": input.metadata.namespace,
			"name": input.metadata.name,
		},
		"to": {
			"kind": "Service",
			"namespace": ref.namespace,
			"name": ref.name,
		},
	}
}
