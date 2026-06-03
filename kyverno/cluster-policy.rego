# Copyright 2026 The KubeAtlas Authors
# SPDX-License-Identifier: Apache-2.0
#
# Kyverno (Cluster)Policy -> ConfigMap "REFERENCES_CONTEXT" edge.
#
# A rule can load lookup data from a ConfigMap via its context block
# (spec.rules[].context[].configMap). The built-in extractor only sees
# the rule's match (the ENFORCES edges); this rule captures the context
# ConfigMap so the graph shows the policy depends on it.
#
# Matches every kind in the kyverno.io group (empty match.kind), so it
# covers both ClusterPolicy and Policy. A cluster-scoped ClusterPolicy
# carries no namespace, so the ConfigMap namespace must be read from the
# context entry; a namespaced Policy defaults it to the policy's own
# namespace.
package kubeatlas.rules.kyverno.cluster_policy

import rego.v1

derive contains edge if {
	startswith(input.apiVersion, "kyverno.io/")
	some rule in input.spec.rules
	some ctx in rule.context
	cm := ctx.configMap
	cm.name != ""
	edge := {
		"type": "REFERENCES_CONTEXT",
		"from": {
			"kind": input.kind,
			"namespace": object.get(input.metadata, "namespace", ""),
			"name": input.metadata.name,
		},
		"to": {
			"kind": "ConfigMap",
			"namespace": object.get(cm, "namespace", object.get(input.metadata, "namespace", "")),
			"name": cm.name,
		},
	}
}
