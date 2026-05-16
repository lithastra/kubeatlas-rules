package kubeatlas.rules.gke.fleet_test

import rego.v1

import data.kubeatlas.rules.gke.fleet

# The fleet module is a discoverability placeholder: a Membership
# has no K8s outbound reference, so derive is always the empty set.

test_placeholder_derives_no_edges if {
	count(fleet.derive) == 0
}

# Even given a full Membership object, the module emits nothing — a
# future change that tried to derive an edge to a GCP project /
# fleet identifier (a cloud resource) would fail this test.
test_placeholder_derives_no_edges_for_membership if {
	result := fleet.derive with input as {
		"kind": "Membership",
		"apiVersion": "hub.gke.io/v1",
		"metadata": {"name": "membership"},
		"spec": {"owner": {"id": "projects/example-project"}},
	}
	count(result) == 0
}
