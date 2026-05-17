package kubeatlas.rules.velero.backup_test

import rego.v1

import data.kubeatlas.rules.velero.backup

# spec.storageLocation resolves to a BackupStorageLocation.
test_storage_location_emits_stored_in if {
	result := backup.derive with input as {
		"kind": "Backup",
		"apiVersion": "velero.io/v1",
		"metadata": {"name": "nightly-1", "namespace": "velero"},
		"spec": {"storageLocation": "default"},
	}
	count(result) == 1
	some edge in result
	edge.type == "STORED_IN"
	edge.from.kind == "Backup"
	edge.from.namespace == "velero"
	edge.from.name == "nightly-1"
	edge.to.kind == "BackupStorageLocation"
	edge.to.namespace == "velero"
	edge.to.name == "default"
}

# Each volume-snapshot location yields its own edge.
test_volume_snapshot_locations_emit_edge_each if {
	result := backup.derive with input as {
		"kind": "Backup",
		"metadata": {"name": "nightly-1", "namespace": "velero"},
		"spec": {"volumeSnapshotLocations": ["aws-east", "aws-west"]},
	}
	count(result) == 2
	some edge in result
	edge.type == "USES_SNAPSHOT_LOCATION"
	names := {e.to.name | some e in result}
	names == {"aws-east", "aws-west"}
}

# Storage and snapshot locations together emit both edge types.
test_full_backup_emits_both_edge_types if {
	result := backup.derive with input as {
		"kind": "Backup",
		"metadata": {"name": "nightly-1", "namespace": "velero"},
		"spec": {
			"storageLocation": "default",
			"volumeSnapshotLocations": ["aws-east"],
		},
	}
	count(result) == 2
	types := {e.type | some e in result}
	types == {"STORED_IN", "USES_SNAPSHOT_LOCATION"}
}

# An empty storageLocation derives no STORED_IN edge.
test_empty_storage_location_emits_no_edge if {
	result := backup.derive with input as {
		"kind": "Backup",
		"metadata": {"name": "nightly-1", "namespace": "velero"},
		"spec": {"storageLocation": ""},
	}
	count(result) == 0
}

# A Backup with no spec derives nothing.
test_no_spec_emits_no_edge if {
	result := backup.derive with input as {
		"kind": "Backup",
		"metadata": {"name": "nightly-1", "namespace": "velero"},
	}
	count(result) == 0
}
