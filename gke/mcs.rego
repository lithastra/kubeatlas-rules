# Copyright 2026 The KubeAtlas Authors
# SPDX-License-Identifier: Apache-2.0
#
# Multi-cluster Services (multicluster.x-k8s.io): ServiceExport and
# ServiceImport edges.
#
# MCS lets a Service in one cluster be consumed from others:
#
#   ServiceExport <ns>/<name>  — marks the Service <ns>/<name> in
#     THIS cluster as exported to the ClusterSet. MCS keys the export
#     on the same namespace + name as the Service it exports.
#     Edge: ServiceExport -> Service (MCS_EXPORTS).
#
#   ServiceImport <ns>/<name>  — the ClusterSet-wide handle for a
#     service exported by some cluster(s). On a cluster that consumes
#     it, MCS realises a derived Service of the same namespace + name.
#     Edge: ServiceImport -> Service (MCS_IMPORTS).
#
# Both edges follow the MCS same-namespace-same-name convention, so
# each is derivable from the export/import resource alone. The module
# is registered under two (group, kind) matches; `derive` branches on
# input.kind.
#
# Anti-patterns guarded:
#   * No firing for kinds other than ServiceExport / ServiceImport.
#   * The to-side Service shares the resource's namespace + name —
#     no spec field is consulted (MCS does not carry one).
package kubeatlas.rules.gke.mcs

import rego.v1

derive contains edge if {
	input.kind == "ServiceExport"
	edge := {
		"type": "MCS_EXPORTS",
		"from": {
			"kind": "ServiceExport",
			"namespace": input.metadata.namespace,
			"name": input.metadata.name,
		},
		"to": {
			"kind": "Service",
			"namespace": input.metadata.namespace,
			"name": input.metadata.name,
		},
	}
}

derive contains edge if {
	input.kind == "ServiceImport"
	edge := {
		"type": "MCS_IMPORTS",
		"from": {
			"kind": "ServiceImport",
			"namespace": input.metadata.namespace,
			"name": input.metadata.name,
		},
		"to": {
			"kind": "Service",
			"namespace": input.metadata.namespace,
			"name": input.metadata.name,
		},
	}
}
