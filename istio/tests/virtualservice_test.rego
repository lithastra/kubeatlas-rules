package kubeatlas.rules.istio.virtualservice_test

import rego.v1

import data.kubeatlas.rules.istio.virtualservice

# A short host on an http route resolves in the VirtualService's
# namespace and emits one ROUTES_TO edge.
test_http_route_short_host_emits_routes_to if {
	result := virtualservice.derive with input as {
		"kind": "VirtualService",
		"apiVersion": "networking.istio.io/v1",
		"metadata": {"name": "reviews", "namespace": "bookinfo"},
		"spec": {"http": [{"route": [{"destination": {"host": "reviews"}}]}]},
	}
	count(result) == 1
	some edge in result
	edge.type == "ROUTES_TO"
	edge.from.kind == "VirtualService"
	edge.from.namespace == "bookinfo"
	edge.from.name == "reviews"
	edge.to.kind == "Service"
	edge.to.namespace == "bookinfo"
	edge.to.name == "reviews"
}

# A cluster FQDN carries its own namespace.
test_http_route_fqdn_host_parses_namespace if {
	result := virtualservice.derive with input as {
		"kind": "VirtualService",
		"metadata": {"name": "vs", "namespace": "default"},
		"spec": {"http": [{"route": [{"destination": {"host": "reviews.bookinfo.svc.cluster.local"}}]}]},
	}
	count(result) == 1
	some edge in result
	edge.to.kind == "Service"
	edge.to.namespace == "bookinfo"
	edge.to.name == "reviews"
}

# tcp route destinations are covered too.
test_tcp_route_emits_routes_to if {
	result := virtualservice.derive with input as {
		"kind": "VirtualService",
		"metadata": {"name": "vs", "namespace": "ns"},
		"spec": {"tcp": [{"route": [{"destination": {"host": "db"}}]}]},
	}
	count(result) == 1
	some edge in result
	edge.type == "ROUTES_TO"
	edge.to.name == "db"
}

# tls route destinations are covered too.
test_tls_route_emits_routes_to if {
	result := virtualservice.derive with input as {
		"kind": "VirtualService",
		"metadata": {"name": "vs", "namespace": "ns"},
		"spec": {"tls": [{"route": [{"destination": {"host": "secure"}}]}]},
	}
	count(result) == 1
	some edge in result
	edge.to.name == "secure"
}

# An external host (a real domain) is not a cluster Service: skipped.
test_external_host_emits_no_routes_to if {
	result := virtualservice.derive with input as {
		"kind": "VirtualService",
		"metadata": {"name": "vs", "namespace": "ns"},
		"spec": {"http": [{"route": [{"destination": {"host": "api.example.com"}}]}]},
	}
	count(result) == 0
}

# Multiple route blocks each emit their own edge.
test_multiple_routes_emit_multiple_edges if {
	result := virtualservice.derive with input as {
		"kind": "VirtualService",
		"metadata": {"name": "vs", "namespace": "ns"},
		"spec": {"http": [
			{"route": [{"destination": {"host": "a"}}]},
			{"route": [{"destination": {"host": "b"}}]},
		]},
	}
	names := {e.to.name | some e in result; e.type == "ROUTES_TO"}
	names == {"a", "b"}
}

# A bare gateway name binds in the VirtualService's namespace.
test_gateway_short_name_emits_binds_gateway if {
	result := virtualservice.derive with input as {
		"kind": "VirtualService",
		"metadata": {"name": "vs", "namespace": "bookinfo"},
		"spec": {"gateways": ["bookinfo-gw"]},
	}
	count(result) == 1
	some edge in result
	edge.type == "BINDS_GATEWAY"
	edge.to.kind == "Gateway"
	edge.to.namespace == "bookinfo"
	edge.to.name == "bookinfo-gw"
}

# A "<namespace>/<name>" gateway entry carries its own namespace.
test_gateway_qualified_name_parses_namespace if {
	result := virtualservice.derive with input as {
		"kind": "VirtualService",
		"metadata": {"name": "vs", "namespace": "default"},
		"spec": {"gateways": ["istio-system/shared-gw"]},
	}
	count(result) == 1
	some edge in result
	edge.type == "BINDS_GATEWAY"
	edge.to.namespace == "istio-system"
	edge.to.name == "shared-gw"
}

# The reserved "mesh" gateway is the sidecar mesh, not a resource.
test_reserved_mesh_gateway_emits_no_edge if {
	result := virtualservice.derive with input as {
		"kind": "VirtualService",
		"metadata": {"name": "vs", "namespace": "ns"},
		"spec": {"gateways": ["mesh"]},
	}
	count(result) == 0
}

# Routes and gateways together emit both edge types.
test_route_and_gateway_combined if {
	result := virtualservice.derive with input as {
		"kind": "VirtualService",
		"metadata": {"name": "vs", "namespace": "ns"},
		"spec": {
			"gateways": ["gw"],
			"http": [{"route": [{"destination": {"host": "svc"}}]}],
		},
	}
	count(result) == 2
	types := {e.type | some e in result}
	types == {"ROUTES_TO", "BINDS_GATEWAY"}
}

# An empty spec derives nothing.
test_empty_spec_emits_no_edge if {
	result := virtualservice.derive with input as {
		"kind": "VirtualService",
		"metadata": {"name": "vs", "namespace": "ns"},
		"spec": {},
	}
	count(result) == 0
}

# An empty host string is skipped.
test_empty_host_emits_no_edge if {
	result := virtualservice.derive with input as {
		"kind": "VirtualService",
		"metadata": {"name": "vs", "namespace": "ns"},
		"spec": {"http": [{"route": [{"destination": {"host": ""}}]}]},
	}
	count(result) == 0
}
