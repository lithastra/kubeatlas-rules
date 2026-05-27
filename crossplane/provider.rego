# Copyright 2026 The KubeAtlas Authors
# SPDX-License-Identifier: Apache-2.0
#
# Provider -> DeploymentRuntimeConfig "USES_RUNTIME_CONFIG".
#
# A Provider's spec.runtimeConfigRef.name points at the
# DeploymentRuntimeConfig that controls how the provider's
# controller pod is deployed (resource limits, env vars, etc.).
# Both are cluster-scoped.
#
# The older spec.controllerConfigRef (deprecated since Crossplane
# 1.15) is also handled — it pointed at a ControllerConfig.
package kubeatlas.rules.crossplane.provider

import rego.v1

derive contains edge if {
	input.kind == "Provider"
	input.spec.runtimeConfigRef.name != ""
	edge := {
		"type": "USES_RUNTIME_CONFIG",
		"from": {
			"kind": "Provider",
			"namespace": "",
			"name": input.metadata.name,
		},
		"to": {
			"kind": "DeploymentRuntimeConfig",
			"namespace": "",
			"name": input.spec.runtimeConfigRef.name,
		},
	}
}

derive contains edge if {
	input.kind == "Provider"
	input.spec.controllerConfigRef.name != ""
	not input.spec.runtimeConfigRef.name
	edge := {
		"type": "USES_RUNTIME_CONFIG",
		"from": {
			"kind": "Provider",
			"namespace": "",
			"name": input.metadata.name,
		},
		"to": {
			"kind": "ControllerConfig",
			"namespace": "",
			"name": input.spec.controllerConfigRef.name,
		},
	}
}
