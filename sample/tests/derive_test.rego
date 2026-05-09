package kubeatlas.sample_test

import rego.v1

import data.kubeatlas.sample

# Happy path: a SampleResource with a populated targetName produces
# exactly one SAMPLE_DERIVED edge with the expected endpoints.
test_happy_path if {
	result := sample.derive with input as {
		"kind": "SampleResource",
		"apiVersion": "example.com/v1",
		"metadata": {"namespace": "demo", "name": "foo"},
		"spec": {"targetName": "foo-target"},
	}
	count(result) == 1
	some edge in result
	edge.type == "SAMPLE_DERIVED"
	edge.from.namespace == "demo"
	edge.from.name == "foo"
	edge.to.namespace == "demo"
	edge.to.name == "foo-target"
}

# Negative: empty targetName means the rule should produce no edges.
test_skipped_when_target_empty if {
	result := sample.derive with input as {
		"kind": "SampleResource",
		"apiVersion": "example.com/v1",
		"metadata": {"namespace": "demo", "name": "foo"},
		"spec": {"targetName": ""},
	}
	count(result) == 0
}

# Negative: kind mismatch (rule shouldn't fire for non-SampleResource
# inputs even if they happen to have a targetName field).
test_skipped_when_kind_mismatch if {
	result := sample.derive with input as {
		"kind": "Pod",
		"apiVersion": "v1",
		"metadata": {"namespace": "demo", "name": "x"},
		"spec": {"targetName": "y"},
	}
	count(result) == 0
}
