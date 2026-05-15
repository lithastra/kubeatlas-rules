package kubeatlas.rules.eks.karpenter_test

import rego.v1

import data.kubeatlas.rules.eks.karpenter

# Happy path: NodePool with EC2NodeClass ref emits one
# USES_NODE_CLASS edge to that NodeClass, cluster-scoped on both
# ends.
test_nodepool_emits_edge_to_ec2_node_class if {
	result := karpenter.derive with input as {
		"kind": "NodePool",
		"apiVersion": "karpenter.sh/v1",
		"metadata": {"name": "default-amd64"},
		"spec": {
			"template": {
				"spec": {
					"nodeClassRef": {
						"group": "karpenter.k8s.aws",
						"kind": "EC2NodeClass",
						"name": "default",
					},
				},
			},
		},
	}
	count(result) == 1
	some edge in result
	edge.type == "USES_NODE_CLASS"
	edge.from.kind == "NodePool"
	edge.from.namespace == ""
	edge.from.name == "default-amd64"
	edge.to.kind == "EC2NodeClass"
	edge.to.namespace == ""
	edge.to.name == "default"
}

# Default kind: when spec.template.spec.nodeClassRef.kind is
# omitted, fall back to EC2NodeClass (Karpenter's AWS provider
# default). The from.name still drives the edge identity.
test_nodepool_defaults_kind_to_ec2_node_class if {
	result := karpenter.derive with input as {
		"kind": "NodePool",
		"apiVersion": "karpenter.sh/v1",
		"metadata": {"name": "spot-pool"},
		"spec": {
			"template": {
				"spec": {
					"nodeClassRef": {"name": "spot"},
				},
			},
		},
	}
	count(result) == 1
	some edge in result
	edge.to.kind == "EC2NodeClass"
	edge.to.name == "spot"
}

# Non-AWS provider: Karpenter Azure / GCP supply different
# NodeClass kinds (AKSNodeClass / GCENodeClass). The rule must
# honor the explicit value rather than rewriting it to
# EC2NodeClass.
test_nodepool_respects_explicit_nodeclass_kind if {
	result := karpenter.derive with input as {
		"kind": "NodePool",
		"apiVersion": "karpenter.sh/v1",
		"metadata": {"name": "aks-pool"},
		"spec": {
			"template": {
				"spec": {
					"nodeClassRef": {
						"group": "karpenter.azure.com",
						"kind": "AKSNodeClass",
						"name": "system",
					},
				},
			},
		},
	}
	count(result) == 1
	some edge in result
	edge.to.kind == "AKSNodeClass"
	edge.to.name == "system"
}

# Empty nodeClassRef.name: skip rather than emit a malformed edge
# to an EC2NodeClass with empty name.
test_empty_nodeclass_name_emits_no_edge if {
	result := karpenter.derive with input as {
		"kind": "NodePool",
		"apiVersion": "karpenter.sh/v1",
		"metadata": {"name": "broken"},
		"spec": {
			"template": {
				"spec": {"nodeClassRef": {"name": ""}},
			},
		},
	}
	count(result) == 0
}

# Missing nodeClassRef entirely: the CRD spec requires it but a
# malformed object could omit it; the rule must not panic.
test_missing_nodeclass_ref_emits_no_edge if {
	result := karpenter.derive with input as {
		"kind": "NodePool",
		"apiVersion": "karpenter.sh/v1",
		"metadata": {"name": "minimal"},
		"spec": {
			"template": {"spec": {}},
		},
	}
	count(result) == 0
}

# Kind mismatch: rule must not fire for non-NodePool inputs even
# if they happen to have a similarly-shaped spec.
test_skipped_when_input_kind_not_nodepool if {
	result := karpenter.derive with input as {
		"kind": "EC2NodeClass",
		"apiVersion": "karpenter.k8s.aws/v1",
		"metadata": {"name": "default"},
		"spec": {
			"template": {
				"spec": {"nodeClassRef": {"name": "irrelevant"}},
			},
		},
	}
	count(result) == 0
}
