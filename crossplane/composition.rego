# Copyright 2026 The KubeAtlas Authors
# SPDX-License-Identifier: Apache-2.0
#
# Composition -> Function "USES_FUNCTION".
#
# Pipeline-mode Compositions (spec.mode == "Pipeline" or, since
# Crossplane 1.17+, the default when spec.pipeline is present)
# reference Functions by name in each pipeline step:
#
#   spec.pipeline[]:
#     step: render-xr
#     functionRef:
#       name: function-patch-and-transform
#
# Each distinct functionRef.name produces one USES_FUNCTION edge.
# Both Compositions and Functions are cluster-scoped.
#
# Classic resources-array Compositions (spec.resources[]) contain
# inline templates — not references to live resources — so no edges
# are derived from them.
package kubeatlas.rules.crossplane.composition

import rego.v1

derive contains edge if {
	input.kind == "Composition"
	some step in input.spec.pipeline
	step.functionRef.name != ""
	edge := {
		"type": "USES_FUNCTION",
		"from": {
			"kind": "Composition",
			"namespace": "",
			"name": input.metadata.name,
		},
		"to": {
			"kind": "Function",
			"namespace": "",
			"name": step.functionRef.name,
		},
	}
}
