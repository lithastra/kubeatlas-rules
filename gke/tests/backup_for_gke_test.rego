package kubeatlas.rules.gke.backup_for_gke_test

import rego.v1

import data.kubeatlas.rules.gke.backup_for_gke

# BackupPlan with selectedNamespaces emits one BACKS_UP edge per
# namespace, each to the cluster-scoped Namespace node.
test_backup_plan_selected_namespaces_emits_edge_per_namespace if {
	result := backup_for_gke.derive with input as {
		"kind": "BackupPlan",
		"apiVersion": "gkebackup.gke.io/v1",
		"metadata": {"name": "nightly"},
		"spec": {"backupConfig": {"selectedNamespaces": {"namespaces": ["petclinic", "payments"]}}},
	}
	count(result) == 2
	every edge in result {
		edge.type == "BACKS_UP"
		edge.from.kind == "BackupPlan"
		edge.from.name == "nightly"
		edge.to.kind == "Namespace"
		edge.to.namespace == ""
	}
	{e.to.name | some e in result} == {"petclinic", "payments"}
}

# BackupPlan with selectedApplications emits one BACKS_UP edge per
# ProtectedApplication.
test_backup_plan_selected_applications_emits_edge_per_app if {
	result := backup_for_gke.derive with input as {
		"kind": "BackupPlan",
		"apiVersion": "gkebackup.gke.io/v1",
		"metadata": {"name": "apps"},
		"spec": {"backupConfig": {"selectedApplications": {"namespacedNames": [
			{"namespace": "petclinic", "name": "petclinic-app"},
		]}}},
	}
	count(result) == 1
	some edge in result
	edge.type == "BACKS_UP"
	edge.to.kind == "ProtectedApplication"
	edge.to.namespace == "petclinic"
	edge.to.name == "petclinic-app"
}

# allNamespaces=true must NOT fan out into per-namespace edges —
# the BackupPlan node alone carries cluster-wide scope.
test_backup_plan_all_namespaces_emits_no_edge if {
	result := backup_for_gke.derive with input as {
		"kind": "BackupPlan",
		"apiVersion": "gkebackup.gke.io/v1",
		"metadata": {"name": "everything"},
		"spec": {"backupConfig": {"allNamespaces": true}},
	}
	count(result) == 0
}

# An empty namespace name in the list is skipped.
test_backup_plan_empty_namespace_is_skipped if {
	result := backup_for_gke.derive with input as {
		"kind": "BackupPlan",
		"apiVersion": "gkebackup.gke.io/v1",
		"metadata": {"name": "nightly"},
		"spec": {"backupConfig": {"selectedNamespaces": {"namespaces": ["", "payments"]}}},
	}
	count(result) == 1
	some edge in result
	edge.to.name == "payments"
}

# RestorePlan emits one RESTORES_FROM edge to its BackupPlan.
test_restore_plan_emits_edge_to_backup_plan if {
	result := backup_for_gke.derive with input as {
		"kind": "RestorePlan",
		"apiVersion": "gkebackup.gke.io/v1",
		"metadata": {"name": "dr-restore"},
		"spec": {"backupPlan": "nightly"},
	}
	count(result) == 1
	some edge in result
	edge.type == "RESTORES_FROM"
	edge.from.kind == "RestorePlan"
	edge.from.name == "dr-restore"
	edge.to.kind == "BackupPlan"
	edge.to.name == "nightly"
}

# RestorePlan with an empty spec.backupPlan emits no edge.
test_restore_plan_empty_backup_plan_emits_no_edge if {
	result := backup_for_gke.derive with input as {
		"kind": "RestorePlan",
		"apiVersion": "gkebackup.gke.io/v1",
		"metadata": {"name": "broken"},
		"spec": {"backupPlan": ""},
	}
	count(result) == 0
}

# Kind mismatch: an unrelated kind fires neither branch.
test_unrelated_kind_emits_no_edge if {
	result := backup_for_gke.derive with input as {
		"kind": "ConfigMap",
		"apiVersion": "v1",
		"metadata": {"name": "cm", "namespace": "petclinic"},
	}
	count(result) == 0
}
