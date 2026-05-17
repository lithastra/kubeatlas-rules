# Copyright 2026 The KubeAtlas Authors
# SPDX-License-Identifier: Apache-2.0
#
# Istio VirtualService: traffic-routing edges.
#
# A VirtualService (networking.istio.io) defines how requests for a
# set of hosts are routed inside the mesh. Two relationships are
# soundly derivable from the VirtualService alone:
#
#   * Route destinations -> Service. Every spec.http[].route[],
#     spec.tcp[].route[] and spec.tls[].route[] entry carries a
#     destination.host. Edge: VirtualService -> Service (ROUTES_TO).
#
#   * Gateway attachment. spec.gateways[] lists the Gateways the
#     VirtualService binds to. Edge: VirtualService -> Gateway
#     (BINDS_GATEWAY). The reserved value "mesh" denotes the sidecar
#     mesh, not a Gateway resource, and is skipped.
#
# Host resolution follows Istio's own rule: a host with no dots is a
# Service in the VirtualService's namespace; a host containing
# ".svc" is a cluster FQDN (<name>.<namespace>.svc[.cluster.local]).
# Anything else is an external host (handled by a ServiceEntry, out
# of scope) and derives no edge — staying sound rather than emitting
# a dangling edge to a Service that does not exist.
#
# Anti-patterns guarded:
#   * No edge for the reserved gateway value "mesh".
#   * No edge for an empty host or empty gateway name.
#   * Ambiguous two-label hosts (e.g. "api.example") are treated as
#     external and skipped.
package kubeatlas.rules.istio.virtualservice

import rego.v1

# service_ref resolves an Istio host string to a {name, namespace}
# Service reference. It is undefined for external hosts.

# Short host (no dots): a Service in the VirtualService's namespace.
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

# route_hosts collects every destination.host across the http, tcp
# and tls route blocks.
route_hosts contains host if {
	some proto in ["http", "tcp", "tls"]
	some route in object.get(input.spec, proto, [])
	some entry in object.get(route, "route", [])
	host := entry.destination.host
}

derive contains edge if {
	some host in route_hosts
	ref := service_ref(host, input.metadata.namespace)
	edge := {
		"type": "ROUTES_TO",
		"from": {
			"kind": "VirtualService",
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

# gateway_ref resolves a spec.gateways[] entry to a {name, namespace}
# Gateway reference. An entry is either "<name>" (current namespace)
# or "<namespace>/<name>". The reserved value "mesh" is skipped.
gateway_ref(g, default_ns) := ref if {
	g != ""
	g != "mesh"
	not contains(g, "/")
	ref := {"name": g, "namespace": default_ns}
}

gateway_ref(g, _) := ref if {
	parts := split(g, "/")
	count(parts) == 2
	parts[0] != ""
	parts[1] != ""
	ref := {"name": parts[1], "namespace": parts[0]}
}

derive contains edge if {
	some g in object.get(input.spec, "gateways", [])
	ref := gateway_ref(g, input.metadata.namespace)
	edge := {
		"type": "BINDS_GATEWAY",
		"from": {
			"kind": "VirtualService",
			"namespace": input.metadata.namespace,
			"name": input.metadata.name,
		},
		"to": {
			"kind": "Gateway",
			"namespace": ref.namespace,
			"name": ref.name,
		},
	}
}
