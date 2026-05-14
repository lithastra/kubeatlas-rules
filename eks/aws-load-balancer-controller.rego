# Copyright 2026 The KubeAtlas Authors
# SPDX-License-Identifier: Apache-2.0
#
# AWS Load Balancer Controller TargetGroupBinding -> Service edge.
#
# When users install AWS Load Balancer Controller on an EKS (or any
# K8s) cluster, the controller emits TargetGroupBinding CRs whose
# spec.serviceRef.{name,port} points at a Service the AWS-side
# TargetGroup forwards traffic to. We emit one ROUTES_TO edge per
# TargetGroupBinding pointing at that Service.
#
# Edge type rationale: reuses ROUTES_TO (the same edge type the
# openshift/route.rego module emits for Route -> Service). The
# semantics are isomorphic — "external traffic ingress points at
# this Service via this controller's CRD" — and reusing the type
# keeps the cluster-view legend small.
#
# The spec.targetGroupARN field carries the raw AWS Target Group ARN
# (e.g. "arn:aws:elasticloadbalancing:..."). We do NOT emit any edge
# or node for the ARN — it identifies a cloud-side resource that is
# not in the K8s graph (invariant 2.7 + anti-pattern 51b). Callers
# that want to surface the ARN to users can read it as a metadata
# annotation on the TargetGroupBinding node.
#
# Same-namespace constraint: TargetGroupBinding is namespaced and the
# referenced Service must live in the same namespace (this is enforced
# by the AWS LBC webhook). We do not need to consult spec.serviceRef
# for a namespace field; it does not exist on the type.
package kubeatlas.rules.eks.aws_load_balancer_controller

import rego.v1

# spec.serviceRef.name -> Service in the same namespace.
# spec.serviceRef.port is metadata only; we do not differentiate edges
# by target port (an aggregator can fold by (from, to) pair).
derive contains edge if {
	input.kind == "TargetGroupBinding"
	svc_name := input.spec.serviceRef.name
	svc_name != ""
	edge := {
		"type": "ROUTES_TO",
		"from": {
			"kind": "TargetGroupBinding",
			"namespace": input.metadata.namespace,
			"name": input.metadata.name,
		},
		"to": {
			"kind": "Service",
			"namespace": input.metadata.namespace,
			"name": svc_name,
		},
	}
}
