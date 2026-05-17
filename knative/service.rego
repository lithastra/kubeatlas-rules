# Copyright 2026 The KubeAtlas Authors
# SPDX-License-Identifier: Apache-2.0
#
# Knative Serving: the Service -> Configuration -> Revision chain.
#
# Knative Serving implements a Service as a same-named Configuration
# plus a Route; the Configuration rolls out a new immutable Revision
# on every spec change. This module derives that generation chain:
#
#   * input.kind == "Service": Service -> the Configuration of the
#     same name and namespace (CREATES_CONFIGURATION). Knative names
#     the Configuration after the Service, so the edge is soundly
#     derivable from the Service alone.
#
#   * input.kind == "Configuration": Configuration -> Revision, from
#     status.latestCreatedRevisionName and
#     status.latestReadyRevisionName (CREATES_REVISION).
#
# One file, registered under two (group, kind) matches — see
# metadata.yaml's ADR note. Kubernetes ownerReferences already give
# the generic OWNS edges down the same chain; these Knative-typed
# edges name it.
#
# Anti-patterns guarded:
#   * A Knative Service also carries status revision fields, but the
#     Configuration-side rule is guarded on input.kind so it never
#     fires for a Service.
#   * No edge for an empty revision name.
package kubeatlas.rules.knative.service

import rego.v1

derive contains edge if {
	input.kind == "Service"
	edge := {
		"type": "CREATES_CONFIGURATION",
		"from": {
			"kind": "Service",
			"namespace": input.metadata.namespace,
			"name": input.metadata.name,
		},
		"to": {
			"kind": "Configuration",
			"namespace": input.metadata.namespace,
			"name": input.metadata.name,
		},
	}
}

# revision_names collects the Revisions a Configuration currently
# points at — the latest created and the latest ready.
revision_names contains name if {
	name := input.status.latestCreatedRevisionName
	name != ""
}

revision_names contains name if {
	name := input.status.latestReadyRevisionName
	name != ""
}

derive contains edge if {
	input.kind == "Configuration"
	some name in revision_names
	edge := {
		"type": "CREATES_REVISION",
		"from": {
			"kind": "Configuration",
			"namespace": input.metadata.namespace,
			"name": input.metadata.name,
		},
		"to": {
			"kind": "Revision",
			"namespace": input.metadata.namespace,
			"name": name,
		},
	}
}
