package kubeatlas.rules.velero.schedule_test

import rego.v1

import data.kubeatlas.rules.velero.schedule

# spec.template.storageLocation resolves to a BackupStorageLocation.
test_template_storage_location_emits_stored_in if {
	result := schedule.derive with input as {
		"kind": "Schedule",
		"apiVersion": "velero.io/v1",
		"metadata": {"name": "nightly", "namespace": "velero"},
		"spec": {
			"schedule": "0 1 * * *",
			"template": {"storageLocation": "default"},
		},
	}
	count(result) == 1
	some edge in result
	edge.type == "STORED_IN"
	edge.from.kind == "Schedule"
	edge.from.name == "nightly"
	edge.to.kind == "BackupStorageLocation"
	edge.to.namespace == "velero"
	edge.to.name == "default"
}

# Each volume-snapshot location in the template yields its own edge.
test_template_volume_snapshot_locations_emit_edge_each if {
	result := schedule.derive with input as {
		"kind": "Schedule",
		"metadata": {"name": "nightly", "namespace": "velero"},
		"spec": {"template": {"volumeSnapshotLocations": ["aws-east", "aws-west"]}},
	}
	count(result) == 2
	some edge in result
	edge.type == "USES_SNAPSHOT_LOCATION"
	names := {e.to.name | some e in result}
	names == {"aws-east", "aws-west"}
}

# A Schedule with no template derives nothing.
test_no_template_emits_no_edge if {
	result := schedule.derive with input as {
		"kind": "Schedule",
		"metadata": {"name": "nightly", "namespace": "velero"},
		"spec": {"schedule": "0 1 * * *"},
	}
	count(result) == 0
}
