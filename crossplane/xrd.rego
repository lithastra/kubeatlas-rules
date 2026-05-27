# Copyright 2026 The KubeAtlas Authors
# SPDX-License-Identifier: Apache-2.0
#
# CompositeResourceDefinition (XRD) -> Composition "USES_COMPOSITION".
#
# An XRD's spec.defaultCompositionRef.name names the Composition that
# Crossplane selects when no explicit compositionRef is set on a
# Composite Resource. Both XRDs and Compositions are cluster-scoped.
package kubeatlas.rules.crossplane.xrd

import rego.v1

derive contains edge if {
	input.kind == "CompositeResourceDefinition"
	input.spec.defaultCompositionRef.name != ""
	edge := {
		"type": "USES_COMPOSITION",
		"from": {
			"kind": "CompositeResourceDefinition",
			"namespace": "",
			"name": input.metadata.name,
		},
		"to": {
			"kind": "Composition",
			"namespace": "",
			"name": input.spec.defaultCompositionRef.name,
		},
	}
}
