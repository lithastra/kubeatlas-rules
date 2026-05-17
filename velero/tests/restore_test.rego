package kubeatlas.rules.velero.restore_test

import rego.v1

import data.kubeatlas.rules.velero.restore

# spec.backupName resolves to the source Backup.
test_backup_name_emits_restores_from_backup if {
	result := restore.derive with input as {
		"kind": "Restore",
		"apiVersion": "velero.io/v1",
		"metadata": {"name": "restore-1", "namespace": "velero"},
		"spec": {"backupName": "nightly-1"},
	}
	count(result) == 1
	some edge in result
	edge.type == "RESTORES_FROM"
	edge.from.kind == "Restore"
	edge.from.name == "restore-1"
	edge.to.kind == "Backup"
	edge.to.namespace == "velero"
	edge.to.name == "nightly-1"
}

# spec.scheduleName resolves to the source Schedule.
test_schedule_name_emits_restores_from_schedule if {
	result := restore.derive with input as {
		"kind": "Restore",
		"metadata": {"name": "restore-2", "namespace": "velero"},
		"spec": {"scheduleName": "nightly"},
	}
	count(result) == 1
	some edge in result
	edge.type == "RESTORES_FROM"
	edge.to.kind == "Schedule"
	edge.to.namespace == "velero"
	edge.to.name == "nightly"
}

# A Restore with neither source field derives nothing.
test_no_source_emits_no_edge if {
	result := restore.derive with input as {
		"kind": "Restore",
		"metadata": {"name": "restore-3", "namespace": "velero"},
		"spec": {"includedNamespaces": ["app"]},
	}
	count(result) == 0
}
