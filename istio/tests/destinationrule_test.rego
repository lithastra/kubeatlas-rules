package kubeatlas.rules.istio.destinationrule_test

import rego.v1

import data.kubeatlas.rules.istio.destinationrule

# A short host resolves in the DestinationRule's namespace.
test_short_host_emits_configures if {
	result := destinationrule.derive with input as {
		"kind": "DestinationRule",
		"apiVersion": "networking.istio.io/v1",
		"metadata": {"name": "reviews-dr", "namespace": "bookinfo"},
		"spec": {"host": "reviews"},
	}
	count(result) == 1
	some edge in result
	edge.type == "CONFIGURES"
	edge.from.kind == "DestinationRule"
	edge.from.namespace == "bookinfo"
	edge.from.name == "reviews-dr"
	edge.to.kind == "Service"
	edge.to.namespace == "bookinfo"
	edge.to.name == "reviews"
}

# A cluster FQDN carries its own namespace.
test_fqdn_host_parses_namespace if {
	result := destinationrule.derive with input as {
		"kind": "DestinationRule",
		"metadata": {"name": "dr", "namespace": "default"},
		"spec": {"host": "reviews.bookinfo.svc.cluster.local"},
	}
	count(result) == 1
	some edge in result
	edge.to.namespace == "bookinfo"
	edge.to.name == "reviews"
}

# An external host is not a cluster Service: skipped.
test_external_host_emits_no_edge if {
	result := destinationrule.derive with input as {
		"kind": "DestinationRule",
		"metadata": {"name": "dr", "namespace": "ns"},
		"spec": {"host": "api.stripe.com"},
	}
	count(result) == 0
}

# A DestinationRule with no spec.host derives nothing.
test_missing_host_emits_no_edge if {
	result := destinationrule.derive with input as {
		"kind": "DestinationRule",
		"metadata": {"name": "dr", "namespace": "ns"},
		"spec": {},
	}
	count(result) == 0
}
