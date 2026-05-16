# Copyright 2026 The KubeAtlas Authors
# SPDX-License-Identifier: Apache-2.0
#
# Backup for GKE (gkebackup.gke.io): BackupPlan + RestorePlan edges.
#
#   BackupPlan   — names what to back up via spec.backupConfig:
#       selectedNamespaces.namespaces[]            -> Namespace
#       selectedApplications.namespacedNames[]     -> ProtectedApplication
#       allNamespaces: true                        -> (no edges)
#     Edge: BackupPlan -> selected target (BACKS_UP).
#
#   RestorePlan  — names the BackupPlan it restores from via
#     spec.backupPlan.
#     Edge: RestorePlan -> BackupPlan (RESTORES_FROM).
#
# The module is registered under two (group, kind) matches
# (BackupPlan and RestorePlan); `derive` branches on input.kind.
#
# BackupPlan and RestorePlan are treated as cluster-scoped (a backup
# plan spans namespaces), so the `from` side carries an empty
# namespace — the same convention karpenter.rego uses for NodePool.
#
# Anti-patterns guarded:
#   * allNamespaces=true is NOT expanded into one edge per namespace
#     — that fan-out would dwarf the rest of the graph. The
#     BackupPlan node by itself represents cluster-wide scope; a
#     consumer that needs the distinction reads spec.backupConfig.
#   * No edge with an empty namespace / application / plan name.
#   * Namespace is cluster-scoped, so BACKS_UP -> Namespace targets
#     carry an empty namespace.
package kubeatlas.rules.gke.backup_for_gke

import rego.v1

# BackupPlan -> each namespace it explicitly selects.
derive contains edge if {
	input.kind == "BackupPlan"
	some ns in input.spec.backupConfig.selectedNamespaces.namespaces
	ns != ""
	edge := {
		"type": "BACKS_UP",
		"from": {
			"kind": "BackupPlan",
			"namespace": "",
			"name": input.metadata.name,
		},
		"to": {
			"kind": "Namespace",
			"namespace": "",
			"name": ns,
		},
	}
}

# BackupPlan -> each ProtectedApplication it explicitly selects.
derive contains edge if {
	input.kind == "BackupPlan"
	some app in input.spec.backupConfig.selectedApplications.namespacedNames
	app.namespace != ""
	app.name != ""
	edge := {
		"type": "BACKS_UP",
		"from": {
			"kind": "BackupPlan",
			"namespace": "",
			"name": input.metadata.name,
		},
		"to": {
			"kind": "ProtectedApplication",
			"namespace": app.namespace,
			"name": app.name,
		},
	}
}

# RestorePlan -> the BackupPlan it restores from.
derive contains edge if {
	input.kind == "RestorePlan"
	plan := input.spec.backupPlan
	plan != ""
	edge := {
		"type": "RESTORES_FROM",
		"from": {
			"kind": "RestorePlan",
			"namespace": "",
			"name": input.metadata.name,
		},
		"to": {
			"kind": "BackupPlan",
			"namespace": "",
			"name": plan,
		},
	}
}
