# Copyright 2026 The KubeAtlas Authors
# SPDX-License-Identifier: Apache-2.0
#
# Velero Schedule: storage-location edges.
#
# A Schedule (velero.io) periodically creates Backups from the
# Backup spec embedded at spec.template. The same storage-location
# edges the backup module derives are read here from that template:
#
#   * spec.template.storageLocation           -> BackupStorageLocation
#                                                (STORED_IN)
#   * spec.template.volumeSnapshotLocations[] -> VolumeSnapshotLocation
#                                                (USES_SNAPSHOT_LOCATION)
#
# Anti-patterns guarded:
#   * No edge for an empty location name.
#   * A Schedule with no spec.template derives nothing.
package kubeatlas.rules.velero.schedule

import rego.v1

derive contains edge if {
	loc := input.spec.template.storageLocation
	loc != ""
	edge := {
		"type": "STORED_IN",
		"from": {
			"kind": "Schedule",
			"namespace": input.metadata.namespace,
			"name": input.metadata.name,
		},
		"to": {
			"kind": "BackupStorageLocation",
			"namespace": input.metadata.namespace,
			"name": loc,
		},
	}
}

derive contains edge if {
	some loc in object.get(input.spec.template, "volumeSnapshotLocations", [])
	loc != ""
	edge := {
		"type": "USES_SNAPSHOT_LOCATION",
		"from": {
			"kind": "Schedule",
			"namespace": input.metadata.namespace,
			"name": input.metadata.name,
		},
		"to": {
			"kind": "VolumeSnapshotLocation",
			"namespace": input.metadata.namespace,
			"name": loc,
		},
	}
}
