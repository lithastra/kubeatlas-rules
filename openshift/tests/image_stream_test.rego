package kubeatlas.rules.openshift.image_stream_test

import rego.v1

import data.kubeatlas.rules.openshift.image_stream as is

# Happy path: a tag with from.kind=ImageStreamTag emits one
# TAGGED_FROM edge across (potentially) namespaces.
test_cross_namespace_tag_reference if {
	result := is.derive with input as {
		"kind": "ImageStream",
		"apiVersion": "image.openshift.io/v1",
		"metadata": {"namespace": "demo", "name": "java"},
		"spec": {"tags": [{
			"name": "openjdk-17-ubi9",
			"from": {
				"kind": "ImageStreamTag",
				"name": "java:openjdk-17-ubi9",
				"namespace": "openshift",
			},
		}]},
	}
	count(result) == 1
	some edge in result
	edge.type == "TAGGED_FROM"
	edge.from.kind == "ImageStream"
	edge.from.namespace == "demo"
	edge.from.name == "java"
	edge.to.kind == "ImageStream"
	edge.to.namespace == "openshift"
	edge.to.name == "java"
}

# Multiple tags fan out into multiple edges.
test_multiple_tags if {
	result := is.derive with input as {
		"kind": "ImageStream",
		"apiVersion": "image.openshift.io/v1",
		"metadata": {"namespace": "demo", "name": "fanout"},
		"spec": {"tags": [
			{
				"name": "v1",
				"from": {"kind": "ImageStreamTag", "name": "src-a:1.0"},
			},
			{
				"name": "v2",
				"from": {"kind": "ImageStreamTag", "name": "src-b:2.0", "namespace": "shared"},
			},
		]},
	}
	count(result) == 2
	to_pairs := {[edge.to.namespace, edge.to.name] | some edge in result}
	to_pairs == {["demo", "src-a"], ["shared", "src-b"]}
}

# DockerImage / external tag references are skipped (KubeAtlas
# doesn't model upstream registries).
test_docker_image_tag_skipped if {
	result := is.derive with input as {
		"kind": "ImageStream",
		"apiVersion": "image.openshift.io/v1",
		"metadata": {"namespace": "demo", "name": "external"},
		"spec": {"tags": [{
			"name": "latest",
			"from": {"kind": "DockerImage", "name": "quay.io/x/y:1"},
		}]},
	}
	count(result) == 0
}

# An ImageStream without spec.tags (status-driven streams that
# import-on-demand) produces no edges.
test_no_tags_skipped if {
	result := is.derive with input as {
		"kind": "ImageStream",
		"apiVersion": "image.openshift.io/v1",
		"metadata": {"namespace": "demo", "name": "stub"},
		"spec": {},
	}
	count(result) == 0
}
