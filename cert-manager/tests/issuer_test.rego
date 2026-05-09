package kubeatlas.rules.cert_manager.issuer_test

import rego.v1

import data.kubeatlas.rules.cert_manager.issuer

# kind=Issuer (default-shaped Certificate): edge target lives in
# the Certificate's own namespace.
test_namespaced_issuer if {
	result := issuer.derive with input as {
		"kind": "Certificate",
		"apiVersion": "cert-manager.io/v1",
		"metadata": {"namespace": "demo", "name": "example"},
		"spec": {
			"secretName": "example-tls",
			"issuerRef": {"kind": "Issuer", "name": "selfsigned"},
		},
	}
	count(result) == 1
	some edge in result
	edge.type == "ISSUED_BY"
	edge.to.kind == "Issuer"
	edge.to.namespace == "demo"
	edge.to.name == "selfsigned"
}

# issuerRef.kind defaults to "Issuer" when omitted — matches the
# cert-manager API webhook defaulting. The rule must produce the
# same edge whether kind is set or absent.
test_default_kind_is_issuer if {
	result := issuer.derive with input as {
		"kind": "Certificate",
		"apiVersion": "cert-manager.io/v1",
		"metadata": {"namespace": "demo", "name": "example"},
		"spec": {
			"secretName": "x",
			"issuerRef": {"name": "selfsigned"},
		},
	}
	count(result) == 1
	some edge in result
	edge.to.kind == "Issuer"
	edge.to.namespace == "demo"
}

# kind=ClusterIssuer: cluster-scoped; to.namespace must be empty so
# the resource ID renders "/ClusterIssuer/<name>".
test_cluster_issuer_no_namespace if {
	result := issuer.derive with input as {
		"kind": "Certificate",
		"apiVersion": "cert-manager.io/v1",
		"metadata": {"namespace": "demo", "name": "example"},
		"spec": {
			"secretName": "x",
			"issuerRef": {"kind": "ClusterIssuer", "name": "letsencrypt-prod"},
		},
	}
	count(result) == 1
	some edge in result
	edge.to.kind == "ClusterIssuer"
	edge.to.namespace == ""
	edge.to.name == "letsencrypt-prod"
}

# Empty issuerRef.name — invalid Certificate; skip rather than
# emit a malformed ISSUED_BY edge.
test_empty_issuer_name_skipped if {
	result := issuer.derive with input as {
		"kind": "Certificate",
		"apiVersion": "cert-manager.io/v1",
		"metadata": {"namespace": "demo", "name": "broken"},
		"spec": {"issuerRef": {"kind": "Issuer", "name": ""}},
	}
	count(result) == 0
}

# Missing issuerRef block entirely.
test_missing_issuer_ref_skipped if {
	result := issuer.derive with input as {
		"kind": "Certificate",
		"apiVersion": "cert-manager.io/v1",
		"metadata": {"namespace": "demo", "name": "stub"},
		"spec": {"secretName": "x"},
	}
	count(result) == 0
}

# Kind mismatch on input.
test_input_kind_mismatch_skipped if {
	result := issuer.derive with input as {
		"kind": "Issuer",
		"apiVersion": "cert-manager.io/v1",
		"metadata": {"namespace": "demo", "name": "loop"},
		"spec": {"issuerRef": {"name": "self"}},
	}
	count(result) == 0
}
