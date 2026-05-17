# Copyright 2026 The KubeAtlas Authors
# SPDX-License-Identifier: Apache-2.0
#
# Argo CD ApplicationSet: templated delivery edges.
#
# An ApplicationSet (argoproj.io) generates Applications from a
# spec.template Application template combined with one or more
# generators. The same three relationships the application module
# derives are read here from spec.template.spec:
#
#   * spec.template.spec.project       -> AppProject (BELONGS_TO_PROJECT)
#   * spec.template.spec.destination.namespace -> Namespace (DEPLOYS_TO)
#   * spec.template.spec.source.repoURL / .sources[].repoURL
#                                      -> GitRepo (SOURCED_FROM)
#
# A template field frequently carries a {{ }} generator placeholder
# (e.g. namespace: "{{.name}}"). Such values are not real resource
# names, so any value containing "{{" is skipped — the edge is
# emitted only for the statically-known part of the template.
#
# No ApplicationSet -> Application edge is emitted: the generated
# Application names come from the generators and are not statically
# knowable.
package kubeatlas.rules.argocd.applicationset

import rego.v1

# tmpl is the embedded Application spec. Undefined for a malformed
# ApplicationSet with no template, which derives no edges.
tmpl := input.spec.template.spec

# templated reports whether a value carries a generator placeholder.
templated(v) if contains(v, "{{")

derive contains edge if {
	project := tmpl.project
	project != ""
	not templated(project)
	edge := {
		"type": "BELONGS_TO_PROJECT",
		"from": {
			"kind": "ApplicationSet",
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
	ns := tmpl.destination.namespace
	ns != ""
	not templated(ns)
	edge := {
		"type": "DEPLOYS_TO",
		"from": {
			"kind": "ApplicationSet",
			"namespace": input.metadata.namespace,
			"name": input.metadata.name,
		},
		"to": {"kind": "Namespace", "namespace": "", "name": ns},
	}
}

# repo_urls collects the single-source and multi-source repoURLs
# from the template, dropping any that carry a placeholder.
repo_urls contains url if {
	url := tmpl.source.repoURL
	url != ""
	not templated(url)
}

repo_urls contains url if {
	some src in object.get(tmpl, "sources", [])
	url := src.repoURL
	url != ""
	not templated(url)
}

derive contains edge if {
	some url in repo_urls
	edge := {
		"type": "SOURCED_FROM",
		"from": {
			"kind": "ApplicationSet",
			"namespace": input.metadata.namespace,
			"name": input.metadata.name,
		},
		"to": {"kind": "GitRepo", "namespace": "", "name": url},
	}
}
