package kubeatlas.rules.cert_manager.certificate_test

import rego.v1

import data.kubeatlas.rules.cert_manager.certificate

# Happy path: a Certificate with secretName produces one STORES_IN
# edge to the Secret in the same namespace.
test_secret_name_present if {
	result := certificate.derive with input as {
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
	edge.type == "STORES_IN"
	edge.from.namespace == "demo"
	edge.from.name == "example"
	edge.to.kind == "Secret"
	edge.to.namespace == "demo"
	edge.to.name == "example-tls"
}

# Empty secretName — Certificate is invalid per cert-manager schema
# but the rule must not produce a malformed STORES_IN.
test_empty_secret_name_skipped if {
	result := certificate.derive with input as {
		"kind": "Certificate",
		"apiVersion": "cert-manager.io/v1",
		"metadata": {"namespace": "demo", "name": "broken"},
		"spec": {"secretName": ""},
	}
	count(result) == 0
}

# No spec.secretName at all (defaulted-to-empty scenario).
test_missing_secret_name_skipped if {
	result := certificate.derive with input as {
		"kind": "Certificate",
		"apiVersion": "cert-manager.io/v1",
		"metadata": {"namespace": "demo", "name": "stub"},
		"spec": {},
	}
	count(result) == 0
}

# Kind mismatch: the rule only fires for Certificate inputs.
test_kind_mismatch_skipped if {
	result := certificate.derive with input as {
		"kind": "Secret",
		"apiVersion": "v1",
		"metadata": {"namespace": "demo", "name": "x"},
		"spec": {"secretName": "y"},
	}
	count(result) == 0
}
