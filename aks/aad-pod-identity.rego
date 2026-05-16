# Copyright 2026 The KubeAtlas Authors
# SPDX-License-Identifier: Apache-2.0
#
# AAD Pod Identity AzureIdentityBinding -> AzureIdentity edge.
#
# AAD Pod Identity (aadpodidentity.k8s.io/v1) is AKS's older
# pod-to-Azure-identity add-on. It has two CRDs:
#
#   AzureIdentity         — names an Azure Managed Identity via
#                           spec.resourceID + spec.clientID.
#   AzureIdentityBinding  — binds an AzureIdentity (spec.azureIdentity,
#                           by name) to pods carrying the label
#                           `aadpodidbinding: <spec.selector>`.
#
# This module fires on AzureIdentityBinding and emits one
# BINDS_PLATFORM_IDENTITY edge to the AzureIdentity it names. The
# edge type is reused from F-209 (invariant 2.6) — the same type the
# EKS pod-identity module emits — so the cluster-view legend stays
# small across cloud platforms.
#
# Why the binding -> identity edge, and not identity -> SA
# --------------------------------------------------------
# Classic AAD Pod Identity does NOT bind to ServiceAccounts. It
# binds to *pods* by a label selector (`aadpodidbinding`). A label
# match is a cross-resource relationship the rego engine cannot
# derive — it routes one resource at a time. Resolving the binding
# to the pods it selects would be a built-in extractor concern
# (the same shape as F-109's SELECTS_NP), and is intentionally not
# attempted here. AzureIdentity itself has no K8s outbound ref:
# spec.resourceID points at an Azure cloud resource (out of scope,
# invariant 2.7 + 51b). So the one edge a rego module can soundly
# derive is AzureIdentityBinding -> AzureIdentity, which is what
# this module emits.
#
# Both CRDs are namespaced, and a binding references an
# AzureIdentity in its own namespace — from/to namespace is
# input.metadata.namespace for both ends.
#
# Anti-patterns guarded:
#   * No reading of AzureIdentity.spec.resourceID — that ID names an
#     Azure Managed Identity (cloud resource), never a graph node.
#   * No emission with an empty spec.azureIdentity — a binding that
#     names no identity is malformed; skip rather than emit a broken
#     edge to a node with an empty name.
#   * No firing for AzureIdentity inputs — the module matches
#     AzureIdentityBinding only.
package kubeatlas.rules.aks.aad_pod_identity

import rego.v1

derive contains edge if {
	input.kind == "AzureIdentityBinding"
	identity_name := input.spec.azureIdentity
	identity_name != ""
	edge := {
		"type": "BINDS_PLATFORM_IDENTITY",
		"from": {
			"kind": "AzureIdentityBinding",
			"namespace": input.metadata.namespace,
			"name": input.metadata.name,
		},
		"to": {
			"kind": "AzureIdentity",
			"namespace": input.metadata.namespace,
			"name": identity_name,
		},
	}
}
