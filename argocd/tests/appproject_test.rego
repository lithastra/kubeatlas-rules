package kubeatlas.rules.argocd.appproject_test

import rego.v1

import data.kubeatlas.rules.argocd.appproject

# A literal destination namespace emits one ALLOWS_DESTINATION edge.
test_literal_destination_emits_allows_destination if {
	result := appproject.derive with input as {
		"kind": "AppProject",
		"apiVersion": "argoproj.io/v1alpha1",
		"metadata": {"name": "team-a", "namespace": "argocd"},
		"spec": {"destinations": [{"server": "https://kubernetes.default.svc", "namespace": "team-a-prod"}]},
	}
	count(result) == 1
	some edge in result
	edge.type == "ALLOWS_DESTINATION"
	edge.from.kind == "AppProject"
	edge.from.name == "team-a"
	edge.to.kind == "Namespace"
	edge.to.namespace == ""
	edge.to.name == "team-a-prod"
}

# Each distinct literal namespace yields its own edge.
test_multiple_literal_destinations if {
	result := appproject.derive with input as {
		"kind": "AppProject",
		"metadata": {"name": "p", "namespace": "argocd"},
		"spec": {"destinations": [
			{"namespace": "ns-a"},
			{"namespace": "ns-b"},
		]},
	}
	count(result) == 2
	names := {e.to.name | some e in result}
	names == {"ns-a", "ns-b"}
}

# The "*" wildcard is not a concrete namespace: skipped.
test_wildcard_destination_is_skipped if {
	result := appproject.derive with input as {
		"kind": "AppProject",
		"metadata": {"name": "p", "namespace": "argocd"},
		"spec": {"destinations": [{"namespace": "*"}]},
	}
	count(result) == 0
}

# A glob pattern is not a concrete namespace: skipped.
test_glob_destination_is_skipped if {
	result := appproject.derive with input as {
		"kind": "AppProject",
		"metadata": {"name": "p", "namespace": "argocd"},
		"spec": {"destinations": [{"namespace": "prod-*"}]},
	}
	count(result) == 0
}

# A negation entry is not a concrete namespace: skipped.
test_negation_destination_is_skipped if {
	result := appproject.derive with input as {
		"kind": "AppProject",
		"metadata": {"name": "p", "namespace": "argocd"},
		"spec": {"destinations": [{"namespace": "!kube-system"}]},
	}
	count(result) == 0
}

# An AppProject with no destinations derives nothing.
test_no_destinations_emits_no_edge if {
	result := appproject.derive with input as {
		"kind": "AppProject",
		"metadata": {"name": "p", "namespace": "argocd"},
		"spec": {"sourceRepos": ["*"]},
	}
	count(result) == 0
}

# A mix of literal and pattern destinations emits only the literals.
test_mixed_destinations_emit_only_literals if {
	result := appproject.derive with input as {
		"kind": "AppProject",
		"metadata": {"name": "p", "namespace": "argocd"},
		"spec": {"destinations": [
			{"namespace": "prod"},
			{"namespace": "*"},
			{"namespace": "!kube-system"},
		]},
	}
	count(result) == 1
	some edge in result
	edge.to.name == "prod"
}
