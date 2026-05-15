package kubeatlas.rules.eks.pod_identity_test

import rego.v1

import data.kubeatlas.rules.eks.pod_identity

# Happy path: cluster-scoped PodIdentityAssociation with non-empty
# spec.namespace + spec.serviceAccount produces one
# BINDS_PLATFORM_IDENTITY edge from the PA (cluster-scoped) to the
# target SA (in spec.namespace).
test_pa_emits_binding_to_serviceaccount if {
	result := pod_identity.derive with input as {
		"kind": "PodIdentityAssociation",
		"apiVersion": "eks.amazonaws.com/v1alpha1",
		"metadata": {"name": "petclinic-pod-identity"},
		"spec": {
			"clusterName": "petclinic-prod",
			"namespace": "petclinic",
			"serviceAccount": "petclinic",
			"roleARN": "arn:aws:iam::123456789012:role/petclinic-pod-role",
		},
	}
	count(result) == 1
	some edge in result
	edge.type == "BINDS_PLATFORM_IDENTITY"
	edge.from.kind == "PodIdentityAssociation"
	edge.from.namespace == ""
	edge.from.name == "petclinic-pod-identity"
	edge.to.kind == "ServiceAccount"
	edge.to.namespace == "petclinic"
	edge.to.name == "petclinic"
}

# Empty spec.namespace: skip rather than emit an edge with empty
# namespace on the to-side (would alias to cluster-scope ID).
test_empty_namespace_emits_no_edge if {
	result := pod_identity.derive with input as {
		"kind": "PodIdentityAssociation",
		"apiVersion": "eks.amazonaws.com/v1alpha1",
		"metadata": {"name": "broken"},
		"spec": {
			"namespace": "",
			"serviceAccount": "petclinic",
			"roleARN": "arn:aws:iam::123456789012:role/x",
		},
	}
	count(result) == 0
}

# Empty spec.serviceAccount: skip rather than emit a malformed
# edge to a SA with empty name.
test_empty_serviceaccount_emits_no_edge if {
	result := pod_identity.derive with input as {
		"kind": "PodIdentityAssociation",
		"apiVersion": "eks.amazonaws.com/v1alpha1",
		"metadata": {"name": "broken"},
		"spec": {
			"namespace": "petclinic",
			"serviceAccount": "",
			"roleARN": "arn:aws:iam::123456789012:role/x",
		},
	}
	count(result) == 0
}

# Missing spec block: malformed object, rule must not panic.
test_missing_spec_emits_no_edge if {
	result := pod_identity.derive with input as {
		"kind": "PodIdentityAssociation",
		"apiVersion": "eks.amazonaws.com/v1alpha1",
		"metadata": {"name": "minimal"},
	}
	count(result) == 0
}

# Kind mismatch: rule must not fire for non-PodIdentityAssociation
# inputs even if they happen to carry a spec.namespace +
# spec.serviceAccount shape.
test_skipped_when_input_kind_not_pa if {
	result := pod_identity.derive with input as {
		"kind": "RoleBinding",
		"apiVersion": "rbac.authorization.k8s.io/v1",
		"metadata": {"name": "rb"},
		"spec": {"namespace": "petclinic", "serviceAccount": "petclinic"},
	}
	count(result) == 0
}

# Role ARN is metadata only: the rule must emit exactly one edge
# (to ServiceAccount) and NO edge or virtual node for the IAM
# role itself. Pins the cloud-resource exclusion behavior — a
# future "helpful" change that adds an ExternalIdentity edge here
# would be caught.
test_role_arn_does_not_produce_extra_edge if {
	result := pod_identity.derive with input as {
		"kind": "PodIdentityAssociation",
		"apiVersion": "eks.amazonaws.com/v1alpha1",
		"metadata": {"name": "pa"},
		"spec": {
			"namespace": "petclinic",
			"serviceAccount": "petclinic",
			"roleARN": "arn:aws:iam::123456789012:role/some-role",
		},
	}
	count(result) == 1
	some edge in result
	edge.to.kind == "ServiceAccount"
}

# Cross-namespace targeting: PA in cluster scope, target SA in
# arbitrary namespace. Verifies the rule respects spec.namespace
# rather than inferring from PA metadata.
test_pa_targets_cross_namespace_sa if {
	result := pod_identity.derive with input as {
		"kind": "PodIdentityAssociation",
		"apiVersion": "eks.amazonaws.com/v1alpha1",
		"metadata": {"name": "cross-ns-pa"},
		"spec": {
			"namespace": "payments",
			"serviceAccount": "stripe-api",
			"roleARN": "arn:aws:iam::123456789012:role/stripe-pod-role",
		},
	}
	count(result) == 1
	some edge in result
	edge.to.namespace == "payments"
	edge.to.name == "stripe-api"
}
