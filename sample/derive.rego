# Reference derive rule. Inputs follow KubeAtlas's Rego v1 input
# shape (see docs/concepts/rego-rules.md in the main repo); the
# expected output is a SET of edge maps.
package kubeatlas.sample

import rego.v1

# A SampleResource with a non-empty spec.targetName produces one
# edge to a SampleTarget in the same namespace. The rule
# intentionally has both a positive AND a negative path so the
# accompanying test file can exercise rule-skip behaviour.
derive contains edge if {
	input.kind == "SampleResource"
	input.spec.targetName != ""
	edge := {
		"type": "SAMPLE_DERIVED",
		"from": {
			"kind": "SampleResource",
			"namespace": input.metadata.namespace,
			"name": input.metadata.name,
		},
		"to": {
			"kind": "SampleTarget",
			"namespace": input.metadata.namespace,
			"name": input.spec.targetName,
		},
	}
}
