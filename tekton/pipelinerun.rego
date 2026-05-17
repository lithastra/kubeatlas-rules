# Copyright 2026 The KubeAtlas Authors
# SPDX-License-Identifier: Apache-2.0
#
# Tekton PipelineRun: execution edge.
#
# A PipelineRun (tekton.dev) is one execution of a Pipeline. When it
# references the Pipeline by name through spec.pipelineRef this
# module emits an edge: PipelineRun -> Pipeline (RUNS_PIPELINE).
#
# A PipelineRun that embeds its definition inline through
# spec.pipelineSpec, or references one through a resolver, carries
# no spec.pipelineRef.name and derives no edge.
package kubeatlas.rules.tekton.pipelinerun

import rego.v1

derive contains edge if {
	name := input.spec.pipelineRef.name
	name != ""
	edge := {
		"type": "RUNS_PIPELINE",
		"from": {
			"kind": "PipelineRun",
			"namespace": input.metadata.namespace,
			"name": input.metadata.name,
		},
		"to": {
			"kind": "Pipeline",
			"namespace": input.metadata.namespace,
			"name": name,
		},
	}
}
