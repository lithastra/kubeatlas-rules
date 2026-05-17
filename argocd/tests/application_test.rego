package kubeatlas.rules.argocd.application_test

import rego.v1

import data.kubeatlas.rules.argocd.application

# spec.project resolves to an AppProject in the Application's namespace.
test_project_emits_belongs_to_project if {
	result := application.derive with input as {
		"kind": "Application",
		"apiVersion": "argoproj.io/v1alpha1",
		"metadata": {"name": "guestbook", "namespace": "argocd"},
		"spec": {"project": "default"},
	}
	count(result) == 1
	some edge in result
	edge.type == "BELONGS_TO_PROJECT"
	edge.from.kind == "Application"
	edge.from.namespace == "argocd"
	edge.from.name == "guestbook"
	edge.to.kind == "AppProject"
	edge.to.namespace == "argocd"
	edge.to.name == "default"
}

# spec.destination.namespace resolves to a cluster Namespace.
test_destination_namespace_emits_deploys_to if {
	result := application.derive with input as {
		"kind": "Application",
		"metadata": {"name": "guestbook", "namespace": "argocd"},
		"spec": {"destination": {"server": "https://kubernetes.default.svc", "namespace": "guestbook"}},
	}
	count(result) == 1
	some edge in result
	edge.type == "DEPLOYS_TO"
	edge.to.kind == "Namespace"
	edge.to.namespace == ""
	edge.to.name == "guestbook"
}

# A single-source Application emits one SOURCED_FROM edge.
test_source_repo_emits_sourced_from if {
	result := application.derive with input as {
		"kind": "Application",
		"metadata": {"name": "guestbook", "namespace": "argocd"},
		"spec": {"source": {"repoURL": "https://github.com/argoproj/argocd-example-apps.git", "path": "guestbook"}},
	}
	count(result) == 1
	some edge in result
	edge.type == "SOURCED_FROM"
	edge.to.kind == "GitRepo"
	edge.to.namespace == ""
	edge.to.name == "https://github.com/argoproj/argocd-example-apps.git"
}

# A multi-source Application emits one edge per repoURL.
test_multi_source_emits_edge_per_repo if {
	result := application.derive with input as {
		"kind": "Application",
		"metadata": {"name": "multi", "namespace": "argocd"},
		"spec": {"sources": [
			{"repoURL": "https://github.com/org/a.git"},
			{"repoURL": "https://github.com/org/b.git"},
		]},
	}
	count(result) == 2
	urls := {e.to.name | some e in result}
	urls == {"https://github.com/org/a.git", "https://github.com/org/b.git"}
}

# A fully-specified Application emits all three edge types.
test_full_application_emits_all_three_edges if {
	result := application.derive with input as {
		"kind": "Application",
		"metadata": {"name": "guestbook", "namespace": "argocd"},
		"spec": {
			"project": "team-a",
			"source": {"repoURL": "https://github.com/org/apps.git"},
			"destination": {"namespace": "team-a-prod"},
		},
	}
	count(result) == 3
	types := {e.type | some e in result}
	types == {"BELONGS_TO_PROJECT", "DEPLOYS_TO", "SOURCED_FROM"}
}

# An empty project string derives nothing.
test_empty_project_emits_no_edge if {
	result := application.derive with input as {
		"kind": "Application",
		"metadata": {"name": "a", "namespace": "argocd"},
		"spec": {"project": ""},
	}
	count(result) == 0
}

# An Application with only a project has no destination / source edge.
test_project_only_emits_single_edge if {
	result := application.derive with input as {
		"kind": "Application",
		"metadata": {"name": "a", "namespace": "argocd"},
		"spec": {"project": "default"},
	}
	count(result) == 1
	some edge in result
	edge.type == "BELONGS_TO_PROJECT"
}
