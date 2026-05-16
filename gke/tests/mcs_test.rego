package kubeatlas.rules.gke.mcs_test

import rego.v1

import data.kubeatlas.rules.gke.mcs

# A ServiceExport emits one MCS_EXPORTS edge to the Service of the
# same namespace + name.
test_service_export_emits_edge_to_service if {
	result := mcs.derive with input as {
		"kind": "ServiceExport",
		"apiVersion": "multicluster.x-k8s.io/v1alpha1",
		"metadata": {"name": "petclinic", "namespace": "petclinic"},
	}
	count(result) == 1
	some edge in result
	edge.type == "MCS_EXPORTS"
	edge.from.kind == "ServiceExport"
	edge.from.namespace == "petclinic"
	edge.from.name == "petclinic"
	edge.to.kind == "Service"
	edge.to.namespace == "petclinic"
	edge.to.name == "petclinic"
}

# A ServiceImport emits one MCS_IMPORTS edge to the Service of the
# same namespace + name.
test_service_import_emits_edge_to_service if {
	result := mcs.derive with input as {
		"kind": "ServiceImport",
		"apiVersion": "multicluster.x-k8s.io/v1alpha1",
		"metadata": {"name": "petclinic", "namespace": "petclinic"},
	}
	count(result) == 1
	some edge in result
	edge.type == "MCS_IMPORTS"
	edge.from.kind == "ServiceImport"
	edge.to.kind == "Service"
	edge.to.name == "petclinic"
}

# Kind mismatch: a plain Service must not fire either branch.
test_unrelated_kind_emits_no_edge if {
	result := mcs.derive with input as {
		"kind": "Service",
		"apiVersion": "v1",
		"metadata": {"name": "petclinic", "namespace": "petclinic"},
	}
	count(result) == 0
}
