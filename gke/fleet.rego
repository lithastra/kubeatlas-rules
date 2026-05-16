# Copyright 2026 The KubeAtlas Authors
# SPDX-License-Identifier: Apache-2.0
#
# GKE Fleet (hub.gke.io): Membership — PLACEHOLDER module.
#
# A Membership is the in-cluster record that this cluster belongs to
# a GKE fleet. It is a cluster-scoped singleton and has no outbound
# reference to another K8s resource — spec fields name the fleet /
# project (GCP-side identifiers, out of scope per invariant 2.7).
#
# So the Membership has zero edges to derive. The node itself still
# belongs in the graph as a fleet-identity marker, and CRD discovery
# (F-103) creates it. This module exists only for discoverability:
# `derive` is the empty set, so `kubeatlas rules-test --pack=gke`
# lists Membership with a pointer here, rather than leaving a reader
# to wonder whether fleet membership is modelled at all.
#
# Do NOT derive edges to GCP project / fleet identifiers — those are
# cloud resources, not graph nodes.
package kubeatlas.rules.gke.fleet

import rego.v1

# Intentionally the empty set: a Membership has no K8s outbound
# reference. See the module comment above.
derive := set()
