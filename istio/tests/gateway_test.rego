package kubeatlas.rules.istio.gateway_test

import rego.v1

import data.kubeatlas.rules.istio.gateway

# A TLS server names a Secret through credentialName.
test_server_with_credential_name_emits_uses_tls_secret if {
	result := gateway.derive with input as {
		"kind": "Gateway",
		"apiVersion": "networking.istio.io/v1",
		"metadata": {"name": "bookinfo-gateway", "namespace": "bookinfo"},
		"spec": {"servers": [{
			"port": {"number": 443, "name": "https", "protocol": "HTTPS"},
			"tls": {"mode": "SIMPLE", "credentialName": "bookinfo-cert"},
			"hosts": ["bookinfo.example.com"],
		}]},
	}
	count(result) == 1
	some edge in result
	edge.type == "USES_TLS_SECRET"
	edge.from.kind == "Gateway"
	edge.from.namespace == "bookinfo"
	edge.from.name == "bookinfo-gateway"
	edge.to.kind == "Secret"
	edge.to.namespace == "bookinfo"
	edge.to.name == "bookinfo-cert"
}

# Distinct credentials across servers emit one edge each.
test_multiple_servers_distinct_credentials if {
	result := gateway.derive with input as {
		"kind": "Gateway",
		"metadata": {"name": "gw", "namespace": "ns"},
		"spec": {"servers": [
			{"tls": {"credentialName": "cert-a"}},
			{"tls": {"credentialName": "cert-b"}},
		]},
	}
	count(result) == 2
	names := {e.to.name | some e in result}
	names == {"cert-a", "cert-b"}
}

# The same credential on two servers collapses to one edge.
test_duplicate_credential_name_deduplicated if {
	result := gateway.derive with input as {
		"kind": "Gateway",
		"metadata": {"name": "gw", "namespace": "ns"},
		"spec": {"servers": [
			{"tls": {"credentialName": "shared-cert"}},
			{"tls": {"credentialName": "shared-cert"}},
		]},
	}
	count(result) == 1
}

# A plain-HTTP server has no tls block and derives nothing.
test_server_without_tls_emits_no_edge if {
	result := gateway.derive with input as {
		"kind": "Gateway",
		"metadata": {"name": "gw", "namespace": "ns"},
		"spec": {"servers": [{"port": {"number": 80, "protocol": "HTTP"}}]},
	}
	count(result) == 0
}

# TLS PASSTHROUGH uses no Secret — no credentialName, no edge.
test_tls_passthrough_without_credential_emits_no_edge if {
	result := gateway.derive with input as {
		"kind": "Gateway",
		"metadata": {"name": "gw", "namespace": "ns"},
		"spec": {"servers": [{"tls": {"mode": "PASSTHROUGH"}}]},
	}
	count(result) == 0
}

# An empty credentialName is skipped.
test_empty_credential_name_emits_no_edge if {
	result := gateway.derive with input as {
		"kind": "Gateway",
		"metadata": {"name": "gw", "namespace": "ns"},
		"spec": {"servers": [{"tls": {"credentialName": ""}}]},
	}
	count(result) == 0
}

# A Gateway with only a selector (no servers) derives nothing.
test_no_servers_emits_no_edge if {
	result := gateway.derive with input as {
		"kind": "Gateway",
		"metadata": {"name": "gw", "namespace": "ns"},
		"spec": {"selector": {"istio": "ingressgateway"}},
	}
	count(result) == 0
}
