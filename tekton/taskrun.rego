# Copyright 2026 The KubeAtlas Authors
# SPDX-License-Identifier: Apache-2.0
#
# Tekton TaskRun: execution edge.
#
# A TaskRun (tekton.dev) is one execution of a Task. When it
# references the Task by name through spec.taskRef this module emits
# an edge: TaskRun -> Task (RUNS_TASK).
#
# A taskRef of kind ClusterTask resolves to a cluster-scoped
# ClusterTask; otherwise it is a namespaced Task in the TaskRun's
# namespace. A TaskRun that embeds its definition inline through
# spec.taskSpec, or references one through a resolver, derives no
# edge.
package kubeatlas.rules.tekton.taskrun

import rego.v1

# task_target resolves a Tekton taskRef to a {kind, namespace, name}
# node reference. It is undefined for a ref with no name.
task_target(ref, default_ns) := target if {
	ref.name != ""
	object.get(ref, "kind", "Task") != "ClusterTask"
	target := {"kind": "Task", "namespace": default_ns, "name": ref.name}
}

task_target(ref, _) := target if {
	ref.name != ""
	object.get(ref, "kind", "Task") == "ClusterTask"
	target := {"kind": "ClusterTask", "namespace": "", "name": ref.name}
}

derive contains edge if {
	target := task_target(input.spec.taskRef, input.metadata.namespace)
	edge := {
		"type": "RUNS_TASK",
		"from": {
			"kind": "TaskRun",
			"namespace": input.metadata.namespace,
			"name": input.metadata.name,
		},
		"to": target,
	}
}
