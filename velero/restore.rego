# Copyright 2026 The KubeAtlas Authors
# SPDX-License-Identifier: Apache-2.0
#
# Velero Restore: source edges.
#
# A Restore (velero.io) replays either one named Backup or the most
# recent Backup of a named Schedule — spec.backupName and
# spec.scheduleName are mutually exclusive:
#
#   * spec.backupName   -> Backup   (RESTORES_FROM)
#   * spec.scheduleName -> Schedule (RESTORES_FROM)
#
# Both source CRs live in the Restore's own namespace (the Velero
# install namespace).
#
# Anti-patterns guarded:
#   * No edge for an empty backupName / scheduleName.
package kubeatlas.rules.velero.restore

import rego.v1

derive contains edge if {
	backup := input.spec.backupName
	backup != ""
	edge := {
		"type": "RESTORES_FROM",
		"from": {
			"kind": "Restore",
			"namespace": input.metadata.namespace,
			"name": input.metadata.name,
		},
		"to": {
			"kind": "Backup",
			"namespace": input.metadata.namespace,
			"name": backup,
		},
	}
}

derive contains edge if {
	schedule := input.spec.scheduleName
	schedule != ""
	edge := {
		"type": "RESTORES_FROM",
		"from": {
			"kind": "Restore",
			"namespace": input.metadata.namespace,
			"name": input.metadata.name,
		},
		"to": {
			"kind": "Schedule",
			"namespace": input.metadata.namespace,
			"name": schedule,
		},
	}
}
