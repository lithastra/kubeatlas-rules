package kubeatlas.rules.openshift.build_config_test

import rego.v1

import data.kubeatlas.rules.openshift.build_config as bc

# Happy path: spec.output.to with kind=ImageStreamTag emits one
# BUILDS_TO edge, namespace defaulting to the BC's namespace.
test_default_namespace_output if {
	result := bc.derive with input as {
		"kind": "BuildConfig",
		"apiVersion": "build.openshift.io/v1",
		"metadata": {"namespace": "demo", "name": "petclinic"},
		"spec": {"output": {"to": {"kind": "ImageStreamTag", "name": "petclinic:latest"}}},
	}
	count(result) == 1
	some edge in result
	edge.type == "BUILDS_TO"
	edge.from.namespace == "demo"
	edge.from.name == "petclinic"
	edge.to.kind == "ImageStream"
	edge.to.namespace == "demo"
	edge.to.name == "petclinic"
}

# Cross-namespace output: shared image registry pattern.
test_explicit_namespace_output if {
	result := bc.derive with input as {
		"kind": "BuildConfig",
		"apiVersion": "build.openshift.io/v1",
		"metadata": {"namespace": "ci", "name": "shared-build"},
		"spec": {"output": {"to": {
			"kind": "ImageStreamTag",
			"name": "img:prod",
			"namespace": "registry",
		}}},
	}
	count(result) == 1
	some edge in result
	edge.to.namespace == "registry"
	edge.to.name == "img"
}

# DockerImage output (push to external registry) is not modeled in
# the graph — KubeAtlas tracks intra-cluster topology only.
test_docker_image_output_skipped if {
	result := bc.derive with input as {
		"kind": "BuildConfig",
		"apiVersion": "build.openshift.io/v1",
		"metadata": {"namespace": "demo", "name": "external"},
		"spec": {"output": {"to": {
			"kind": "DockerImage",
			"name": "quay.io/team/img:latest",
		}}},
	}
	count(result) == 0
}

# A BC without spec.output (rare; valid only for binary builds with
# no persisted output) is silently skipped.
test_no_output_skipped if {
	result := bc.derive with input as {
		"kind": "BuildConfig",
		"apiVersion": "build.openshift.io/v1",
		"metadata": {"namespace": "demo", "name": "binary-only"},
		"spec": {},
	}
	count(result) == 0
}

# Kind mismatch on the input.
test_skipped_when_input_not_bc if {
	result := bc.derive with input as {
		"kind": "Build",
		"apiVersion": "build.openshift.io/v1",
		"metadata": {"namespace": "demo", "name": "instance"},
		"spec": {"output": {"to": {"kind": "ImageStreamTag", "name": "x:latest"}}},
	}
	count(result) == 0
}
