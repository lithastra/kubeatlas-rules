# Copyright 2026 The KubeAtlas Authors
# SPDX-License-Identifier: Apache-2.0
#
# Velero Backup: storage-location edges.
#
# A Backup (velero.io) writes its object payload to one
# BackupStorageLocation and its volume snapshots to zero or more
# VolumeSnapshotLocations:
#
#   * spec.storageLocation            -> BackupStorageLocation
#                                        (STORED_IN)
#   * spec.volumeSnapshotLocations[]  -> VolumeSnapshotLocation
#                                        (USES_SNAPSHOT_LOCATION)
#
# Velero keeps every CR in its install namespace, so each location
# is resolved in the Backup's own namespace.
#
# Anti-patterns guarded:
#   * No edge for an empty location name.
package kubeatlas.rules.velero.backup

import rego.v1

derive contains edge if {
	loc := input.spec.storageLocation
	loc != ""
	edge := {
		"type": "STORED_IN",
		"from": {
			"kind": "Backup",
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
	some loc in object.get(input.spec, "volumeSnapshotLocations", [])
	loc != ""
	edge := {
		"type": "USES_SNAPSHOT_LOCATION",
		"from": {
			"kind": "Backup",
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
