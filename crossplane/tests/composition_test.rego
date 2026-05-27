package kubeatlas.rules.crossplane.composition_test

import rego.v1

import data.kubeatlas.rules.crossplane.composition

test_pipeline_single_function if {
	result := composition.derive with input as {
		"kind": "Composition",
		"apiVersion": "apiextensions.crossplane.io/v1",
		"metadata": {"name": "composition-aws-postgresql"},
		"spec": {
			"compositeTypeRef": {
				"apiVersion": "database.example.org/v1alpha1",
				"kind": "XPostgreSQLInstance",
			},
			"mode": "Pipeline",
			"pipeline": [{"step": "render", "functionRef": {"name": "function-patch-and-transform"}}],
		},
	}
	count(result) == 1
	some edge in result
	edge.type == "USES_FUNCTION"
	edge.from.kind == "Composition"
	edge.from.name == "composition-aws-postgresql"
	edge.to.kind == "Function"
	edge.to.name == "function-patch-and-transform"
}

test_pipeline_multiple_functions if {
	result := composition.derive with input as {
		"kind": "Composition",
		"apiVersion": "apiextensions.crossplane.io/v1",
		"metadata": {"name": "composition-multi"},
		"spec": {
			"compositeTypeRef": {
				"apiVersion": "infra.example.org/v1alpha1",
				"kind": "XCluster",
			},
			"pipeline": [
				{"step": "render-xr", "functionRef": {"name": "function-patch-and-transform"}},
				{"step": "ready-check", "functionRef": {"name": "function-auto-ready"}},
				{"step": "sequence", "functionRef": {"name": "function-sequencer"}},
			],
		},
	}
	count(result) == 3
	names := {e.to.name | some e in result}
	names == {"function-patch-and-transform", "function-auto-ready", "function-sequencer"}
}

test_duplicate_function_deduped if {
	result := composition.derive with input as {
		"kind": "Composition",
		"apiVersion": "apiextensions.crossplane.io/v1",
		"metadata": {"name": "composition-dup"},
		"spec": {
			"pipeline": [
				{"step": "step-1", "functionRef": {"name": "function-patch-and-transform"}},
				{"step": "step-2", "functionRef": {"name": "function-patch-and-transform"}},
			],
		},
	}
	# derive is a set — identical edges are deduplicated
	count(result) == 1
}

test_no_pipeline if {
	result := composition.derive with input as {
		"kind": "Composition",
		"apiVersion": "apiextensions.crossplane.io/v1",
		"metadata": {"name": "composition-classic"},
		"spec": {
			"compositeTypeRef": {
				"apiVersion": "database.example.org/v1alpha1",
				"kind": "XPostgreSQLInstance",
			},
			"resources": [{"name": "rds", "base": {"apiVersion": "rds.aws.upbound.io/v1beta1", "kind": "Instance"}}],
		},
	}
	count(result) == 0
}

test_kind_mismatch if {
	result := composition.derive with input as {
		"kind": "CompositeResourceDefinition",
		"apiVersion": "apiextensions.crossplane.io/v1",
		"metadata": {"name": "xrd"},
		"spec": {"pipeline": [{"step": "x", "functionRef": {"name": "fn"}}]},
	}
	count(result) == 0
}
