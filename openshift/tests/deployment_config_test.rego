package kubeatlas.rules.openshift.deployment_config_test

import rego.v1

import data.kubeatlas.rules.openshift.deployment_config as dc

# Happy path: ImageChange trigger with an ImageStreamTag ref produces
# one TRIGGERS_FROM edge. Namespace defaults to the DC's namespace
# when the ref has no explicit namespace field.
test_image_trigger_default_namespace if {
	result := dc.derive with input as {
		"kind": "DeploymentConfig",
		"apiVersion": "apps.openshift.io/v1",
		"metadata": {"namespace": "demo", "name": "myapp"},
		"spec": {"triggers": [{
			"type": "ImageChange",
			"imageChangeParams": {
				"automatic": true,
				"containerNames": ["main"],
				"from": {"kind": "ImageStreamTag", "name": "myapp:latest"},
			},
		}]},
	}
	count(result) == 1
	some edge in result
	edge.type == "TRIGGERS_FROM"
	edge.from.namespace == "demo"
	edge.from.name == "myapp"
	edge.to.kind == "ImageStream"
	edge.to.namespace == "demo"
	edge.to.name == "myapp"
}

# Explicit namespace on the ref wins over the DC's own.
test_image_trigger_explicit_namespace if {
	result := dc.derive with input as {
		"kind": "DeploymentConfig",
		"apiVersion": "apps.openshift.io/v1",
		"metadata": {"namespace": "consumer", "name": "downstream"},
		"spec": {"triggers": [{
			"type": "ImageChange",
			"imageChangeParams": {
				"from": {
					"kind": "ImageStreamTag",
					"name": "shared-img:prod",
					"namespace": "registry",
				},
			},
		}]},
	}
	count(result) == 1
	some edge in result
	edge.to.namespace == "registry"
	edge.to.name == "shared-img"
}

# Multiple ImageChange triggers fan out into multiple edges.
test_multiple_triggers if {
	result := dc.derive with input as {
		"kind": "DeploymentConfig",
		"apiVersion": "apps.openshift.io/v1",
		"metadata": {"namespace": "demo", "name": "multi"},
		"spec": {"triggers": [
			{
				"type": "ImageChange",
				"imageChangeParams": {"from": {"kind": "ImageStreamTag", "name": "a:latest"}},
			},
			{
				"type": "ImageChange",
				"imageChangeParams": {"from": {"kind": "ImageStreamTag", "name": "b:v1"}},
			},
		]},
	}
	count(result) == 2
	to_names := {edge.to.name | some edge in result}
	to_names == {"a", "b"}
}

# ConfigChange triggers (the other valid trigger type) are ignored —
# they don't reference any external resource.
test_config_change_trigger_skipped if {
	result := dc.derive with input as {
		"kind": "DeploymentConfig",
		"apiVersion": "apps.openshift.io/v1",
		"metadata": {"namespace": "demo", "name": "cc"},
		"spec": {"triggers": [{"type": "ConfigChange"}]},
	}
	count(result) == 0
}

# from.kind != ImageStreamTag is silently skipped (DockerImage and
# ImageStreamImage are accepted by the API but not what this rule
# models; KubeAtlas handles them via separate rules later).
test_non_imagestreamtag_kind_skipped if {
	result := dc.derive with input as {
		"kind": "DeploymentConfig",
		"apiVersion": "apps.openshift.io/v1",
		"metadata": {"namespace": "demo", "name": "x"},
		"spec": {"triggers": [{
			"type": "ImageChange",
			"imageChangeParams": {"from": {"kind": "DockerImage", "name": "registry/img:latest"}},
		}]},
	}
	count(result) == 0
}

# Kind mismatch on the input itself.
test_skipped_when_input_not_dc if {
	result := dc.derive with input as {
		"kind": "Deployment",
		"apiVersion": "apps/v1",
		"metadata": {"namespace": "demo", "name": "x"},
		"spec": {"triggers": []},
	}
	count(result) == 0
}
