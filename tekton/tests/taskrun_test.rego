package kubeatlas.rules.tekton.taskrun_test

import rego.v1

import data.kubeatlas.rules.tekton.taskrun

# spec.taskRef.name resolves to the executed Task.
test_task_ref_emits_runs_task if {
	result := taskrun.derive with input as {
		"kind": "TaskRun",
		"apiVersion": "tekton.dev/v1",
		"metadata": {"name": "buildpacks-run-abc", "namespace": "ci"},
		"spec": {"taskRef": {"name": "buildpacks"}},
	}
	count(result) == 1
	some edge in result
	edge.type == "RUNS_TASK"
	edge.from.kind == "TaskRun"
	edge.from.namespace == "ci"
	edge.from.name == "buildpacks-run-abc"
	edge.to.kind == "Task"
	edge.to.namespace == "ci"
	edge.to.name == "buildpacks"
}

# A ClusterTask taskRef resolves to a cluster-scoped node.
test_cluster_task_ref_is_cluster_scoped if {
	result := taskrun.derive with input as {
		"kind": "TaskRun",
		"metadata": {"name": "run-1", "namespace": "ci"},
		"spec": {"taskRef": {"name": "shared-build", "kind": "ClusterTask"}},
	}
	count(result) == 1
	some edge in result
	edge.to.kind == "ClusterTask"
	edge.to.namespace == ""
	edge.to.name == "shared-build"
}

# An inline taskSpec carries no taskRef and derives no edge.
test_inline_task_spec_emits_no_edge if {
	result := taskrun.derive with input as {
		"kind": "TaskRun",
		"metadata": {"name": "run-2", "namespace": "ci"},
		"spec": {"taskSpec": {"steps": [{"name": "s", "image": "busybox"}]}},
	}
	count(result) == 0
}
