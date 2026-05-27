package kubeatlas.rules.crossplane.provider_test

import rego.v1

import data.kubeatlas.rules.crossplane.provider

test_runtime_config_ref if {
	result := provider.derive with input as {
		"kind": "Provider",
		"apiVersion": "pkg.crossplane.io/v1",
		"metadata": {"name": "provider-aws-s3"},
		"spec": {
			"package": "xpkg.upbound.io/upbound/provider-aws-s3:v1.14.0",
			"runtimeConfigRef": {"name": "provider-aws-runtime"},
		},
	}
	count(result) == 1
	some edge in result
	edge.type == "USES_RUNTIME_CONFIG"
	edge.from.kind == "Provider"
	edge.from.name == "provider-aws-s3"
	edge.to.kind == "DeploymentRuntimeConfig"
	edge.to.name == "provider-aws-runtime"
}

test_legacy_controller_config_ref if {
	result := provider.derive with input as {
		"kind": "Provider",
		"apiVersion": "pkg.crossplane.io/v1",
		"metadata": {"name": "provider-aws-ec2"},
		"spec": {
			"package": "xpkg.upbound.io/upbound/provider-aws-ec2:v0.47.0",
			"controllerConfigRef": {"name": "legacy-controller-config"},
		},
	}
	count(result) == 1
	some edge in result
	edge.type == "USES_RUNTIME_CONFIG"
	edge.from.name == "provider-aws-ec2"
	edge.to.kind == "ControllerConfig"
	edge.to.name == "legacy-controller-config"
}

test_runtime_takes_precedence_over_controller if {
	result := provider.derive with input as {
		"kind": "Provider",
		"apiVersion": "pkg.crossplane.io/v1",
		"metadata": {"name": "provider-aws-rds"},
		"spec": {
			"package": "xpkg.upbound.io/upbound/provider-aws-rds:v1.14.0",
			"runtimeConfigRef": {"name": "new-runtime"},
			"controllerConfigRef": {"name": "old-controller"},
		},
	}
	# Only runtimeConfigRef fires; controllerConfigRef is suppressed
	count(result) == 1
	some edge in result
	edge.to.kind == "DeploymentRuntimeConfig"
	edge.to.name == "new-runtime"
}

test_no_config_refs if {
	result := provider.derive with input as {
		"kind": "Provider",
		"apiVersion": "pkg.crossplane.io/v1",
		"metadata": {"name": "provider-helm"},
		"spec": {"package": "xpkg.upbound.io/crossplane-contrib/provider-helm:v0.19.0"},
	}
	count(result) == 0
}

test_kind_mismatch if {
	result := provider.derive with input as {
		"kind": "Function",
		"apiVersion": "pkg.crossplane.io/v1",
		"metadata": {"name": "function-patch-and-transform"},
		"spec": {"runtimeConfigRef": {"name": "some-config"}},
	}
	count(result) == 0
}
