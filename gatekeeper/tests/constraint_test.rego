package kubeatlas.rules.gatekeeper.constraint_test

import rego.v1

import data.kubeatlas.rules.gatekeeper.constraint

# Happy path: a Constraint whose parameters come from a ConfigMap
# produces one REFERENCES_PARAM edge to that ConfigMap.
test_configmap_param_present if {
	result := constraint.derive with input as {
		"kind": "K8sRequiredLabels",
		"apiVersion": "constraints.gatekeeper.sh/v1beta1",
		"metadata": {"name": "all"},
		"spec": {"parameters": {"configMap": {"namespace": "gatekeeper-system", "name": "label-params"}}},
	}
	count(result) == 1
	some edge in result
	edge.type == "REFERENCES_PARAM"
	edge.from.kind == "K8sRequiredLabels"
	edge.from.name == "all"
	edge.to.kind == "ConfigMap"
	edge.to.namespace == "gatekeeper-system"
	edge.to.name == "label-params"
}

# Inlined parameters (no ConfigMap) produce no edge — that case is
# already covered by the built-in ENFORCES extractor.
test_inline_parameters_skipped if {
	result := constraint.derive with input as {
		"kind": "K8sRequiredLabels",
		"apiVersion": "constraints.gatekeeper.sh/v1beta1",
		"metadata": {"name": "inline"},
		"spec": {"parameters": {"labels": ["app"]}},
	}
	count(result) == 0
}

# An empty ConfigMap name is malformed; do not emit a broken edge.
test_empty_configmap_name_skipped if {
	result := constraint.derive with input as {
		"kind": "K8sRequiredLabels",
		"metadata": {"name": "broken"},
		"spec": {"parameters": {"configMap": {"name": ""}}},
	}
	count(result) == 0
}

# A Constraint with no parameters block at all.
test_no_parameters_skipped if {
	result := constraint.derive with input as {
		"kind": "K8sRequiredLabels",
		"metadata": {"name": "stub"},
		"spec": {"match": {"kinds": []}},
	}
	count(result) == 0
}

# The referenced ConfigMap may omit a namespace (defaults to empty,
# i.e. resolved later); the edge still forms on a non-empty name.
test_configmap_param_without_namespace if {
	result := constraint.derive with input as {
		"kind": "K8sAllowedRepos",
		"apiVersion": "constraints.gatekeeper.sh/v1beta1",
		"metadata": {"name": "repos"},
		"spec": {"parameters": {"configMap": {"name": "repo-list"}}},
	}
	count(result) == 1
	some edge in result
	edge.to.namespace == ""
	edge.to.name == "repo-list"
}

# Catch-all routing means the module sees every resource; a configMap
# param on a non-Gatekeeper object must be ignored.
test_non_gatekeeper_apiversion_skipped if {
	result := constraint.derive with input as {
		"kind": "Widget",
		"apiVersion": "example.com/v1",
		"metadata": {"name": "w"},
		"spec": {"parameters": {"configMap": {"name": "cm"}}},
	}
	count(result) == 0
}
