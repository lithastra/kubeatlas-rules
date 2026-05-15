# Copyright 2026 The KubeAtlas Authors
# SPDX-License-Identifier: Apache-2.0
#
# EKS Pod Identity PodIdentityAssociation -> ServiceAccount edge.
#
# EKS Pod Identity (the IRSA successor) binds a ServiceAccount to an
# AWS IAM Role at cluster scope. The K8s-side declaration is a
# PodIdentityAssociation CR (eks.amazonaws.com/v1alpha1) carrying:
#
#   spec.clusterName     — AWS EKS cluster name (metadata only)
#   spec.namespace       — target ServiceAccount's namespace
#   spec.serviceAccount  — target ServiceAccount's name
#   spec.roleARN         — IAM Role ARN (cloud resource, NOT modeled
#                          as a graph node per invariant 51b + 2.7)
#
# We emit one BINDS_PLATFORM_IDENTITY edge per PodIdentityAssociation
# pointing at the named ServiceAccount. The edge type matches F-209's
# convention for identity binding edges (invariant 2.6); the SHAPE
# differs from F-209's canonical SA -> ExternalIdentity (this edge is
# PodIdentityAssociation -> ServiceAccount) because the rego rule
# matches against the CR, not the SA. The F-209 built-in extractor
# (pkg/extractor/eks_identity.go, P3-T23) will add the complementary
# SA -> ExternalIdentity edge from spec.roleARN when it lands; until
# then this single edge gives users the navigation path "find this
# PA -> see which SA it binds".
#
# Scope NOTE: PodIdentityAssociation is cluster-scoped (the binding
# applies at the cluster level even though it names a namespaced
# SA), so input.metadata.namespace is empty. The TARGET SA lives in
# spec.namespace which is decoupled from the PA's own scope.
#
# Anti-patterns guarded:
#   * No reading of spec.roleARN as a graph node. The ARN is a cloud
#     resource; it may appear in a future ExternalIdentity virtual
#     node via the F-209 main-repo extractor, but never as a CR.
#   * No emission with empty serviceAccount or namespace — both must
#     be present and non-empty for the edge to be valid.
#   * No assumption that PodIdentityAssociation and the target SA
#     share a namespace; cluster-scoped CR names a namespaced SA.
package kubeatlas.rules.eks.pod_identity

import rego.v1

derive contains edge if {
	input.kind == "PodIdentityAssociation"
	sa_ns := input.spec.namespace
	sa_name := input.spec.serviceAccount
	sa_ns != ""
	sa_name != ""
	edge := {
		"type": "BINDS_PLATFORM_IDENTITY",
		"from": {
			"kind": "PodIdentityAssociation",
			"namespace": "",
			"name": input.metadata.name,
		},
		"to": {
			"kind": "ServiceAccount",
			"namespace": sa_ns,
			"name": sa_name,
		},
	}
}
