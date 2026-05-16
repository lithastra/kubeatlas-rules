# Copyright 2026 The KubeAtlas Authors
# SPDX-License-Identifier: Apache-2.0
#
# GKE Ingress: BackendConfig + FrontendConfig edges.
#
# GKE's Ingress add-on lets a workload attach extra L7 load-balancer
# config through two CRDs, each wired up by an annotation:
#
#   BackendConfig (cloud.google.com)  — referenced by a Service via
#     the annotation cloud.google.com/backend-config (or the older
#     beta.cloud.google.com/backend-config). The value is JSON:
#       {"default": "<name>"}              one config for all ports
#       {"ports": {"<port>": "<name>"}}    per-port configs
#     Edge: Service -> BackendConfig (USES_BACKEND_CONFIG).
#
#   FrontendConfig (networking.gke.io) — referenced by an Ingress via
#     the annotation networking.gke.io/v1beta1.FrontendConfig. The
#     value is the plain FrontendConfig name.
#     Edge: Ingress -> FrontendConfig (USES_FRONTEND_CONFIG).
#
# Both edges have the ANNOTATED resource (Service / Ingress) as the
# `from` side, so each is soundly derivable from that single
# resource — the annotation is self-contained. The module is
# registered under two (group, kind) matches (Service and Ingress);
# `derive` branches on input.kind. See metadata.yaml's ADR note.
#
# Anti-patterns guarded:
#   * Malformed annotation JSON makes json.unmarshal undefined, so
#     the rule simply derives no edge rather than erroring.
#   * No edge with an empty BackendConfig / FrontendConfig name.
#   * BackendConfig / FrontendConfig are namespaced; the referenced
#     CR lives in the annotated resource's own namespace.
package kubeatlas.rules.gke.gke_ingress

import rego.v1

# --- BackendConfig (Service annotation) ----------------------------

backend_config_annotation_keys := [
	"cloud.google.com/backend-config",
	"beta.cloud.google.com/backend-config",
]

# A BackendConfig named under "default": one config for every port.
backend_config_names contains name if {
	some key in backend_config_annotation_keys
	cfg := json.unmarshal(input.metadata.annotations[key])
	name := cfg["default"]
	name != ""
}

# BackendConfigs named per port under "ports" — iterate the
# port->name object's values.
backend_config_names contains name if {
	some key in backend_config_annotation_keys
	cfg := json.unmarshal(input.metadata.annotations[key])
	ports := object.get(cfg, "ports", {})
	some port_key
	name := ports[port_key]
	name != ""
}

derive contains edge if {
	input.kind == "Service"
	some name in backend_config_names
	edge := {
		"type": "USES_BACKEND_CONFIG",
		"from": {
			"kind": "Service",
			"namespace": input.metadata.namespace,
			"name": input.metadata.name,
		},
		"to": {
			"kind": "BackendConfig",
			"namespace": input.metadata.namespace,
			"name": name,
		},
	}
}

# --- FrontendConfig (Ingress annotation) ---------------------------

frontend_config_annotation_key := "networking.gke.io/v1beta1.FrontendConfig"

derive contains edge if {
	input.kind == "Ingress"
	name := input.metadata.annotations[frontend_config_annotation_key]
	name != ""
	edge := {
		"type": "USES_FRONTEND_CONFIG",
		"from": {
			"kind": "Ingress",
			"namespace": input.metadata.namespace,
			"name": input.metadata.name,
		},
		"to": {
			"kind": "FrontendConfig",
			"namespace": input.metadata.namespace,
			"name": name,
		},
	}
}
