package kubeatlas.rules.openshift.scc_test

import rego.v1

import data.kubeatlas.rules.openshift.scc

# Happy path: each "system:serviceaccount:<ns>:<sa>" entry produces
# one SCC_BINDS edge to the ServiceAccount.
test_serviceaccount_users if {
	result := scc.derive with input as {
		"kind": "SecurityContextConstraints",
		"apiVersion": "security.openshift.io/v1",
		"metadata": {"name": "anyuid"},
		"users": [
			"system:serviceaccount:demo:builder",
			"system:serviceaccount:demo:deployer",
			"system:serviceaccount:other:default",
		],
	}
	count(result) == 3
	pairs := {[edge.to.namespace, edge.to.name] | some edge in result}
	pairs == {
		["demo", "builder"],
		["demo", "deployer"],
		["other", "default"],
	}
	every edge in result {
		edge.type == "SCC_BINDS"
		edge.from.kind == "SecurityContextConstraints"
		edge.from.namespace == ""
		edge.from.name == "anyuid"
		edge.to.kind == "ServiceAccount"
	}
}

# Plain user names ("alice") have no graph endpoint and are skipped.
test_plain_user_names_skipped if {
	result := scc.derive with input as {
		"kind": "SecurityContextConstraints",
		"apiVersion": "security.openshift.io/v1",
		"metadata": {"name": "restricted"},
		"users": ["alice", "system:authenticated"],
	}
	count(result) == 0
}

# Malformed SA strings (wrong segment count or wrong prefix) are
# skipped without erroring.
test_malformed_user_strings_skipped if {
	result := scc.derive with input as {
		"kind": "SecurityContextConstraints",
		"apiVersion": "security.openshift.io/v1",
		"metadata": {"name": "weird"},
		"users": [
			"system:serviceaccount:demo",
			"system:serviceaccount:demo:builder:extra",
			"weird:serviceaccount:demo:builder",
		],
	}
	count(result) == 0
}

# Empty namespace or empty SA name segment is treated as malformed.
test_empty_segments_skipped if {
	result := scc.derive with input as {
		"kind": "SecurityContextConstraints",
		"apiVersion": "security.openshift.io/v1",
		"metadata": {"name": "edge"},
		"users": [
			"system:serviceaccount::builder",
			"system:serviceaccount:demo:",
		],
	}
	count(result) == 0
}

# Mixed list — only the well-formed SA bindings make it.
test_mixed_users if {
	result := scc.derive with input as {
		"kind": "SecurityContextConstraints",
		"apiVersion": "security.openshift.io/v1",
		"metadata": {"name": "mixed"},
		"users": [
			"alice",
			"system:serviceaccount:demo:builder",
			"system:authenticated",
			"system:serviceaccount:demo:deployer",
		],
	}
	count(result) == 2
	to_names := {edge.to.name | some edge in result}
	to_names == {"builder", "deployer"}
}

# Kind mismatch on input.
test_skipped_when_input_not_scc if {
	result := scc.derive with input as {
		"kind": "Role",
		"apiVersion": "rbac.authorization.k8s.io/v1",
		"metadata": {"name": "x"},
		"users": ["system:serviceaccount:demo:builder"],
	}
	count(result) == 0
}
