package kubeatlas.rules.eks.aws_load_balancer_controller_test

import rego.v1

import data.kubeatlas.rules.eks.aws_load_balancer_controller as lbc

# Happy path: spec.serviceRef.name produces exactly one ROUTES_TO
# edge from the TargetGroupBinding to the named Service in the
# same namespace.
test_service_ref_emits_edge if {
	result := lbc.derive with input as {
		"kind": "TargetGroupBinding",
		"apiVersion": "elbv2.k8s.aws/v1beta1",
		"metadata": {"namespace": "petclinic", "name": "petclinic"},
		"spec": {
			"serviceRef": {"name": "petclinic", "port": 80},
			"targetGroupARN": "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/petclinic/abc",
			"targetType": "ip",
		},
	}
	count(result) == 1
	some edge in result
	edge.type == "ROUTES_TO"
	edge.from.kind == "TargetGroupBinding"
	edge.from.namespace == "petclinic"
	edge.from.name == "petclinic"
	edge.to.kind == "Service"
	edge.to.namespace == "petclinic"
	edge.to.name == "petclinic"
}

# Empty spec.serviceRef.name: skip rather than emit a malformed edge
# to a Service with empty name (which would crash downstream stores
# that key Resource by ID = ns/kind/name).
test_empty_service_name_emits_no_edge if {
	result := lbc.derive with input as {
		"kind": "TargetGroupBinding",
		"apiVersion": "elbv2.k8s.aws/v1beta1",
		"metadata": {"namespace": "demo", "name": "broken"},
		"spec": {"serviceRef": {"name": ""}},
	}
	count(result) == 0
}

# Missing serviceRef block: the CRD spec requires it but a
# malformed object could omit it; the rule must not panic.
test_missing_service_ref_emits_no_edge if {
	result := lbc.derive with input as {
		"kind": "TargetGroupBinding",
		"apiVersion": "elbv2.k8s.aws/v1beta1",
		"metadata": {"namespace": "demo", "name": "minimal"},
		"spec": {
			"targetGroupARN": "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/x/y",
		},
	}
	count(result) == 0
}

# Kind mismatch: rule must not fire for non-TargetGroupBinding
# inputs even when they have a spec.serviceRef field (other CRDs
# in the same group could; the match is on Kind, not group alone).
test_skipped_when_input_kind_not_targetgroupbinding if {
	result := lbc.derive with input as {
		"kind": "IngressClassParams",
		"apiVersion": "elbv2.k8s.aws/v1beta1",
		"metadata": {"namespace": "demo", "name": "params"},
		"spec": {"serviceRef": {"name": "irrelevant"}},
	}
	count(result) == 0
}

# Raw ARN reminder: the rule does NOT emit any node or edge for
# spec.targetGroupARN. The ARN identifies a cloud-side AWS Target
# Group that is not in the K8s graph. This test fixes the
# behaviour so a future "helpful" change that adds an
# ExternalIdentity-style node for the ARN gets caught.
test_target_group_arn_does_not_produce_extra_edge if {
	result := lbc.derive with input as {
		"kind": "TargetGroupBinding",
		"apiVersion": "elbv2.k8s.aws/v1beta1",
		"metadata": {"namespace": "petclinic", "name": "petclinic"},
		"spec": {
			"serviceRef": {"name": "petclinic"},
			"targetGroupARN": "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/petclinic/xyz",
		},
	}
	# Exactly one edge: the Service edge. ARN must not generate
	# a second edge or any virtual cloud-resource node.
	count(result) == 1
	some edge in result
	edge.to.kind == "Service"
}
