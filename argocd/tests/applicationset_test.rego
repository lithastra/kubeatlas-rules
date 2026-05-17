package kubeatlas.rules.argocd.applicationset_test

import rego.v1

import data.kubeatlas.rules.argocd.applicationset

# A static project in the template resolves to an AppProject.
test_template_static_project_emits_belongs_to_project if {
	result := applicationset.derive with input as {
		"kind": "ApplicationSet",
		"apiVersion": "argoproj.io/v1alpha1",
		"metadata": {"name": "appset", "namespace": "argocd"},
		"spec": {"template": {"spec": {"project": "default"}}},
	}
	count(result) == 1
	some edge in result
	edge.type == "BELONGS_TO_PROJECT"
	edge.from.kind == "ApplicationSet"
	edge.from.name == "appset"
	edge.to.kind == "AppProject"
	edge.to.name == "default"
}

# A static repoURL in the template emits one SOURCED_FROM edge.
test_template_static_repo_emits_sourced_from if {
	result := applicationset.derive with input as {
		"kind": "ApplicationSet",
		"metadata": {"name": "appset", "namespace": "argocd"},
		"spec": {"template": {"spec": {"source": {"repoURL": "https://github.com/org/apps.git"}}}},
	}
	count(result) == 1
	some edge in result
	edge.type == "SOURCED_FROM"
	edge.to.kind == "GitRepo"
	edge.to.name == "https://github.com/org/apps.git"
}

# A multi-source template emits one edge per repoURL.
test_template_multi_source_emits_edge_per_repo if {
	result := applicationset.derive with input as {
		"kind": "ApplicationSet",
		"metadata": {"name": "appset", "namespace": "argocd"},
		"spec": {"template": {"spec": {"sources": [
			{"repoURL": "https://github.com/org/a.git"},
			{"repoURL": "https://github.com/org/b.git"},
		]}}},
	}
	count(result) == 2
}

# A static destination namespace emits one DEPLOYS_TO edge.
test_template_static_namespace_emits_deploys_to if {
	result := applicationset.derive with input as {
		"kind": "ApplicationSet",
		"metadata": {"name": "appset", "namespace": "argocd"},
		"spec": {"template": {"spec": {"destination": {"namespace": "shared"}}}},
	}
	count(result) == 1
	some edge in result
	edge.type == "DEPLOYS_TO"
	edge.to.name == "shared"
}

# A generator-templated namespace carries "{{" and is skipped.
test_templated_namespace_is_skipped if {
	result := applicationset.derive with input as {
		"kind": "ApplicationSet",
		"metadata": {"name": "appset", "namespace": "argocd"},
		"spec": {"template": {"spec": {"destination": {"namespace": "{{.name}}"}}}},
	}
	count(result) == 0
}

# Templated project and repoURL values are both skipped.
test_templated_project_and_repo_are_skipped if {
	result := applicationset.derive with input as {
		"kind": "ApplicationSet",
		"metadata": {"name": "appset", "namespace": "argocd"},
		"spec": {"template": {"spec": {
			"project": "{{.project}}",
			"source": {"repoURL": "https://github.com/{{.org}}/repo.git"},
		}}},
	}
	count(result) == 0
}

# An ApplicationSet with no template derives nothing.
test_no_template_emits_no_edge if {
	result := applicationset.derive with input as {
		"kind": "ApplicationSet",
		"metadata": {"name": "appset", "namespace": "argocd"},
		"spec": {"generators": [{"list": {"elements": []}}]},
	}
	count(result) == 0
}
