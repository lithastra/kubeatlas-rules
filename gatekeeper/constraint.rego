# Copyright 2026 The KubeAtlas Authors
# SPDX-License-Identifier: Apache-2.0
#
# Gatekeeper Constraint -> ConfigMap "REFERENCES_PARAM" edge.
#
# Some Constraints source their parameters from a ConfigMap instead of
# inlining them under spec.parameters. The built-in extractor only sees
# spec.match (the ENFORCES edges); this rule captures the parameter
# ConfigMap so the graph shows that deleting it changes the policy.
#
# Constraint kinds are generated per ConstraintTemplate, so the module
# uses the engine's catch-all match and gates here on the
# constraints.gatekeeper.sh apiVersion plus the shape of spec.parameters.
package kubeatlas.rules.gatekeeper.constraint

import rego.v1

derive contains edge if {
	startswith(input.apiVersion, "constraints.gatekeeper.sh/")
	cm := input.spec.parameters.configMap
	cm.name != ""
	edge := {
		"type": "REFERENCES_PARAM",
		"from": {
			"kind": input.kind,
			"namespace": object.get(input.metadata, "namespace", ""),
			"name": input.metadata.name,
		},
		"to": {
			"kind": "ConfigMap",
			"namespace": object.get(cm, "namespace", ""),
			"name": cm.name,
		},
	}
}
