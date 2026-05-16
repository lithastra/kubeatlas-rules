package kubeatlas.rules.aks.workload_identity_test

import rego.v1

import data.kubeatlas.rules.aks.workload_identity

# The workload-identity module is a discoverability placeholder: it
# derives the empty set regardless of input. The real
# SA -> ExternalIdentity edge is emitted by the built-in extractor
# pkg/extractor/aks_identity.go (P3-T24 / F-209), not by rego.

# With no input bound at all, derive is the empty set.
test_placeholder_derives_no_edges if {
	count(workload_identity.derive) == 0
}

# Even for the exact resource Workload Identity opts a workload in
# through — a ServiceAccount carrying azure.workload.identity/client-id —
# the rego module emits nothing. This pins the placeholder: a future
# "helpful" change that derives an edge from the annotation here
# (instead of in the built-in extractor) would fail this test.
test_placeholder_derives_no_edges_for_annotated_sa if {
	result := workload_identity.derive with input as {
		"kind": "ServiceAccount",
		"apiVersion": "v1",
		"metadata": {
			"name": "petclinic",
			"namespace": "petclinic",
			"annotations": {"azure.workload.identity/client-id": "00000000-0000-0000-0000-000000000000"},
		},
	}
	count(result) == 0
}
