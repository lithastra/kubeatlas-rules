# Copyright 2026 The KubeAtlas Authors
# SPDX-License-Identifier: Apache-2.0
#
# Tekton Pipeline: task-composition edges.
#
# A Pipeline (tekton.dev) is a DAG of pipeline tasks. Every entry in
# spec.tasks[] and spec.finally[] either references a Task through
# taskRef or embeds one through taskSpec. For each taskRef this
# module emits an edge: Pipeline -> Task (USES_TASK).
#
# A taskRef of kind ClusterTask resolves to a cluster-scoped
# ClusterTask; otherwise it is a namespaced Task in the Pipeline's
# namespace. Inline taskSpec entries and resolver-based refs (which
# carry no .name) derive no edge.
#
# Anti-patterns guarded:
#   * No edge for a taskRef with an empty name (resolver refs).
#   * spec.finally[] is covered alongside spec.tasks[].
package kubeatlas.rules.tekton.pipeline

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

# task_refs collects every taskRef across spec.tasks and spec.finally.
task_refs contains ref if {
	some section in ["tasks", "finally"]
	some t in object.get(input.spec, section, [])
	ref := t.taskRef
}

derive contains edge if {
	some ref in task_refs
	target := task_target(ref, input.metadata.namespace)
	edge := {
		"type": "USES_TASK",
		"from": {
			"kind": "Pipeline",
			"namespace": input.metadata.namespace,
			"name": input.metadata.name,
		},
		"to": target,
	}
}
