package kubeatlas.rules.kyverno.cluster_policy_test

import rego.v1

import data.kubeatlas.rules.kyverno.cluster_policy

# Happy path: a ClusterPolicy rule that loads a ConfigMap into its
# context produces one REFERENCES_CONTEXT edge to that ConfigMap.
test_context_configmap_present if {
	result := cluster_policy.derive with input as {
		"kind": "ClusterPolicy",
		"apiVersion": "kyverno.io/v1",
		"metadata": {"name": "require-labels"},
		"spec": {"rules": [{
			"name": "check",
			"context": [{"name": "labels", "configMap": {"name": "allowed-labels", "namespace": "kyverno"}}],
			"validate": {"message": "x"},
		}]},
	}
	count(result) == 1
	some edge in result
	edge.type == "REFERENCES_CONTEXT"
	edge.from.kind == "ClusterPolicy"
	edge.from.name == "require-labels"
	edge.to.kind == "ConfigMap"
	edge.to.namespace == "kyverno"
	edge.to.name == "allowed-labels"
}

# A rule with no context block produces nothing — that match-only case
# is the built-in ENFORCES extractor's job.
test_no_context_skipped if {
	result := cluster_policy.derive with input as {
		"kind": "ClusterPolicy",
		"metadata": {"name": "p"},
		"spec": {"rules": [{"name": "r", "validate": {"message": "x"}}]},
	}
	count(result) == 0
}

# A context that loads from an apiCall rather than a ConfigMap is not a
# ConfigMap reference.
test_context_without_configmap_skipped if {
	result := cluster_policy.derive with input as {
		"kind": "ClusterPolicy",
		"metadata": {"name": "p"},
		"spec": {"rules": [{"name": "r", "context": [{"name": "api", "apiCall": {"urlPath": "/x"}}]}]},
	}
	count(result) == 0
}

# A namespaced Policy whose context ConfigMap omits a namespace defaults
# it to the policy's own namespace.
test_namespaced_policy_defaults_namespace if {
	result := cluster_policy.derive with input as {
		"kind": "Policy",
		"apiVersion": "kyverno.io/v1",
		"metadata": {"name": "p", "namespace": "team-a"},
		"spec": {"rules": [{"name": "r", "context": [{"name": "cm", "configMap": {"name": "data"}}]}]},
	}
	count(result) == 1
	some edge in result
	edge.from.namespace == "team-a"
	edge.to.namespace == "team-a"
	edge.to.name == "data"
}

# Two rules each with a ConfigMap context produce two edges.
test_multiple_rules if {
	result := cluster_policy.derive with input as {
		"kind": "ClusterPolicy",
		"apiVersion": "kyverno.io/v1",
		"metadata": {"name": "multi"},
		"spec": {"rules": [
			{"name": "a", "context": [{"name": "x", "configMap": {"name": "cm-a", "namespace": "ns"}}]},
			{"name": "b", "context": [{"name": "y", "configMap": {"name": "cm-b", "namespace": "ns"}}]},
		]},
	}
	count(result) == 2
}

# Catch-all routing: a non-Kyverno resource that happens to carry a
# rules/context shape must be ignored.
test_non_kyverno_apiversion_skipped if {
	result := cluster_policy.derive with input as {
		"kind": "Thing",
		"apiVersion": "example.com/v1",
		"metadata": {"name": "t"},
		"spec": {"rules": [{"name": "r", "context": [{"name": "c", "configMap": {"name": "cm"}}]}]},
	}
	count(result) == 0
}
