package kubeatlas.rules.tekton.pipelinerun_test

import rego.v1

import data.kubeatlas.rules.tekton.pipelinerun

# spec.pipelineRef.name resolves to the executed Pipeline.
test_pipeline_ref_emits_runs_pipeline if {
	result := pipelinerun.derive with input as {
		"kind": "PipelineRun",
		"apiVersion": "tekton.dev/v1",
		"metadata": {"name": "build-and-deploy-run-abc", "namespace": "ci"},
		"spec": {"pipelineRef": {"name": "build-and-deploy"}},
	}
	count(result) == 1
	some edge in result
	edge.type == "RUNS_PIPELINE"
	edge.from.kind == "PipelineRun"
	edge.from.namespace == "ci"
	edge.from.name == "build-and-deploy-run-abc"
	edge.to.kind == "Pipeline"
	edge.to.namespace == "ci"
	edge.to.name == "build-and-deploy"
}

# An inline pipelineSpec carries no pipelineRef and derives no edge.
test_inline_pipeline_spec_emits_no_edge if {
	result := pipelinerun.derive with input as {
		"kind": "PipelineRun",
		"metadata": {"name": "run-xyz", "namespace": "ci"},
		"spec": {"pipelineSpec": {"tasks": [{"name": "t", "taskRef": {"name": "x"}}]}},
	}
	count(result) == 0
}
