package kubeatlas.rules.tekton.pipeline_test

import rego.v1

import data.kubeatlas.rules.tekton.pipeline

# Each spec.tasks[] taskRef yields one USES_TASK edge to a Task.
test_pipeline_tasks_emit_uses_task if {
	result := pipeline.derive with input as {
		"kind": "Pipeline",
		"apiVersion": "tekton.dev/v1",
		"metadata": {"name": "build-and-deploy", "namespace": "ci"},
		"spec": {"tasks": [
			{"name": "build", "taskRef": {"name": "buildpacks"}},
			{"name": "deploy", "taskRef": {"name": "kubectl-apply"}},
		]},
	}
	count(result) == 2
	some edge in result
	edge.type == "USES_TASK"
	edge.from.kind == "Pipeline"
	edge.from.namespace == "ci"
	edge.from.name == "build-and-deploy"
	names := {e.to.name | some e in result}
	names == {"buildpacks", "kubectl-apply"}
	kinds := {e.to.kind | some e in result}
	kinds == {"Task"}
}

# A spec.finally[] taskRef is covered alongside spec.tasks[].
test_pipeline_finally_task_emits_uses_task if {
	result := pipeline.derive with input as {
		"kind": "Pipeline",
		"metadata": {"name": "p", "namespace": "ci"},
		"spec": {"finally": [{"name": "notify", "taskRef": {"name": "slack-notify"}}]},
	}
	count(result) == 1
	some edge in result
	edge.type == "USES_TASK"
	edge.to.kind == "Task"
	edge.to.name == "slack-notify"
}

# A taskRef of kind ClusterTask resolves to a cluster-scoped node.
test_pipeline_cluster_task_ref_is_cluster_scoped if {
	result := pipeline.derive with input as {
		"kind": "Pipeline",
		"metadata": {"name": "p", "namespace": "ci"},
		"spec": {"tasks": [{"name": "build", "taskRef": {"name": "shared-build", "kind": "ClusterTask"}}]},
	}
	count(result) == 1
	some edge in result
	edge.to.kind == "ClusterTask"
	edge.to.namespace == ""
	edge.to.name == "shared-build"
}

# An inline taskSpec entry carries no taskRef and derives no edge.
test_pipeline_inline_task_spec_emits_no_edge if {
	result := pipeline.derive with input as {
		"kind": "Pipeline",
		"metadata": {"name": "p", "namespace": "ci"},
		"spec": {"tasks": [{"name": "build", "taskSpec": {"steps": [{"name": "s", "image": "busybox"}]}}]},
	}
	count(result) == 0
}

# A resolver-based taskRef carries no name and derives no edge.
test_pipeline_resolver_ref_emits_no_edge if {
	result := pipeline.derive with input as {
		"kind": "Pipeline",
		"metadata": {"name": "p", "namespace": "ci"},
		"spec": {"tasks": [{"name": "build", "taskRef": {"resolver": "git", "params": [{"name": "url", "value": "https://example.com/r.git"}]}}]},
	}
	count(result) == 0
}

# A Pipeline with no spec derives nothing.
test_pipeline_no_spec_emits_no_edge if {
	result := pipeline.derive with input as {
		"kind": "Pipeline",
		"metadata": {"name": "p", "namespace": "ci"},
	}
	count(result) == 0
}
