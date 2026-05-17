# Copyright 2026 The KubeAtlas Authors
# SPDX-License-Identifier: Apache-2.0
#
# Argo CD AppProject: deployment-scope edges.
#
# An AppProject (argoproj.io) constrains the Applications assigned
# to it. spec.destinations[] is the allow-list of {server,
# namespace} an Application in the project may deploy to.
#
# Edge: AppProject -> Namespace (ALLOWS_DESTINATION), one per
# distinct literal namespace in spec.destinations[].
#
# Anti-patterns guarded:
#   * Glob and negation entries ("*", "prod-*", "!kube-system") are
#     not concrete namespace names and derive no edge.
#   * No edge for an empty namespace.
#   * spec.sourceRepos is not modelled: it is a git-URL allow-list,
#     and the application module already captures the repos an
#     Application actually uses.
package kubeatlas.rules.argocd.appproject

import rego.v1

# literal reports whether a namespace entry is a concrete name —
# no glob ("*"), no negation ("!").
literal(ns) if {
	ns != ""
	not contains(ns, "*")
	not startswith(ns, "!")
}

derive contains edge if {
	some dest in object.get(input.spec, "destinations", [])
	ns := dest.namespace
	literal(ns)
	edge := {
		"type": "ALLOWS_DESTINATION",
		"from": {
			"kind": "AppProject",
			"namespace": input.metadata.namespace,
			"name": input.metadata.name,
		},
		"to": {"kind": "Namespace", "namespace": "", "name": ns},
	}
}
