# Copyright 2026 The KubeAtlas Authors
# SPDX-License-Identifier: Apache-2.0
#
# Argo CD Application: GitOps delivery edges.
#
# An Application (argoproj.io) is one unit of continuous delivery:
# it syncs manifests from a git source into a destination namespace
# under the policy of an AppProject. Three edges are soundly
# derivable from the Application alone:
#
#   * spec.project -> AppProject (BELONGS_TO_PROJECT). The
#     AppProject is resolved in the Application's own namespace —
#     the standard install keeps both in the argocd namespace.
#
#   * spec.destination.namespace -> Namespace (DEPLOYS_TO). The
#     namespace the synced resources land in.
#
#   * spec.source.repoURL (and each spec.sources[].repoURL for a
#     multi-source Application) -> GitRepo (SOURCED_FROM). GitRepo
#     is a synthetic node — a git URL is not a Kubernetes resource —
#     whose name is the URL, so the graph can show repository fan-in.
#
# Anti-patterns guarded:
#   * No edge for an empty project / namespace / repoURL.
#   * The destination namespace is emitted regardless of
#     spec.destination.server; a remote-cluster destination yields a
#     dangling edge, which the store tolerates.
package kubeatlas.rules.argocd.application

import rego.v1

derive contains edge if {
	project := input.spec.project
	project != ""
	edge := {
		"type": "BELONGS_TO_PROJECT",
		"from": {
			"kind": "Application",
			"namespace": input.metadata.namespace,
			"name": input.metadata.name,
		},
		"to": {
			"kind": "AppProject",
			"namespace": input.metadata.namespace,
			"name": project,
		},
	}
}

derive contains edge if {
	ns := input.spec.destination.namespace
	ns != ""
	edge := {
		"type": "DEPLOYS_TO",
		"from": {
			"kind": "Application",
			"namespace": input.metadata.namespace,
			"name": input.metadata.name,
		},
		"to": {"kind": "Namespace", "namespace": "", "name": ns},
	}
}

# repo_urls collects the single-source and multi-source repoURLs.
repo_urls contains url if {
	url := input.spec.source.repoURL
	url != ""
}

repo_urls contains url if {
	some src in object.get(input.spec, "sources", [])
	url := src.repoURL
	url != ""
}

derive contains edge if {
	some url in repo_urls
	edge := {
		"type": "SOURCED_FROM",
		"from": {
			"kind": "Application",
			"namespace": input.metadata.namespace,
			"name": input.metadata.name,
		},
		"to": {"kind": "GitRepo", "namespace": "", "name": url},
	}
}
