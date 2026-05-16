# Copyright 2026 The KubeAtlas Authors
# SPDX-License-Identifier: Apache-2.0
#
# AKS Workload Identity — PLACEHOLDER module. Derives no edges.
#
# Workload Identity is the successor to AAD Pod Identity. Unlike its
# predecessor it ships NO add-on-injected CRD: a workload opts in
# entirely through a ServiceAccount annotation —
#
#   azure.workload.identity/client-id: <client-id>
#
# A ServiceAccount annotation is plain SA metadata, not an
# add-on CRD. The SA -> ExternalIdentity edge therefore belongs to a
# built-in extractor in the main repo —
# pkg/extractor/aks_identity.go (P3-T24 / F-209) — exactly as IRSA
# is handled for EKS. A rego pack cannot derive it: the engine
# routes one resource at a time, and there is no CRD to match.
#
# This module exists purely for discoverability. `derive` is the
# empty set, so the engine loads the module, lists it under
# `kubeatlas rules-test --pack=aks`, and a reader looking for
# "where does KubeAtlas handle AKS Workload Identity?" finds this
# pointer to the built-in extractor instead of finding nothing.
#
# Do NOT add SA-annotation handling here — it would duplicate the
# built-in extractor and put a cross-resource concern in a pack
# that only ever sees one resource at a time.
package kubeatlas.rules.aks.workload_identity

import rego.v1

# Intentionally the empty set: see the module comment above. The
# real SA -> ExternalIdentity edge is emitted by the built-in
# extractor pkg/extractor/aks_identity.go (P3-T24 / F-209).
derive := set()
