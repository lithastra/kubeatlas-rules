# Copyright 2026 The KubeAtlas Authors
# SPDX-License-Identifier: Apache-2.0
#
# Karpenter NodePool -> EC2NodeClass edge derivation.
#
# A NodePool (karpenter.sh/v1) names its provisioning template via
# spec.template.spec.nodeClassRef. The ref is a cluster-scoped
# pointer at a *NodeClass resource — EC2NodeClass on AWS
# (karpenter.k8s.aws), AKSNodeClass on Azure (karpenter.azure.com),
# GCENodeClass on GCP (karpenter.gcp.com). We emit one
# USES_NODE_CLASS edge per NodePool pointing at whichever
# *NodeClass it references.
#
# Both NodePool and the *NodeClass kinds are cluster-scoped, so
# from/to namespace is empty (the openshift route.rego sets this
# to input.metadata.namespace which is "" for cluster-scoped
# resources — same convention here).
#
# spec.template.spec.nodeClassRef carries an optional .group and
# .kind. Defaults per karpenter docs:
#   * group: "karpenter.k8s.aws" (the AWS provider; other clouds
#     supply their own provider)
#   * kind:  "EC2NodeClass"
# We honor explicit overrides (Azure/GCP karpenter providers
# would supply different values).
#
# Anti-patterns guarded:
#   * No reading of nodeClassRef ARNs / cloud IDs — the *NodeClass
#     resource IS in K8s (cluster-scoped CRD), so the to-side is a
#     real graph node, not an ExternalIdentity virtual.
#   * No emission with empty .name — the spec requires it and a
#     missing value indicates a malformed object the rule must
#     skip rather than emit a broken edge.
#
# USES_NODE_CLASS edge type note: this is a NEW edge type not
# in pkg/graph/model.go AllEdgeTypes as of v1.0.x. Main repo
# follow-up will register the const + append to AllEdgeTypes +
# document in docs/architecture.md (per the AllEdgeTypes doc
# string in model.go). The rules-repo can emit the string today;
# the main repo's CRD discovery + graph store accept any
# EdgeType-typed string without an enum check.
package kubeatlas.rules.eks.karpenter

import rego.v1

derive contains edge if {
	input.kind == "NodePool"
	class_name := input.spec.template.spec.nodeClassRef.name
	class_name != ""
	edge := {
		"type": "USES_NODE_CLASS",
		"from": {
			"kind": "NodePool",
			"namespace": "",
			"name": input.metadata.name,
		},
		"to": {
			"kind": node_class_kind,
			"namespace": "",
			"name": class_name,
		},
	}
}

# Resolve the to-side kind. Default per Karpenter is EC2NodeClass
# (the AWS provider). Other clouds (Azure / GCP) override via
# spec.template.spec.nodeClassRef.kind.
node_class_kind := k if {
	k := input.spec.template.spec.nodeClassRef.kind
	k != ""
} else := "EC2NodeClass"
