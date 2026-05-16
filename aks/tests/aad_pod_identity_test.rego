package kubeatlas.rules.aks.aad_pod_identity_test

import rego.v1

import data.kubeatlas.rules.aks.aad_pod_identity

# Happy path: an AzureIdentityBinding naming an AzureIdentity emits
# one BINDS_PLATFORM_IDENTITY edge, namespaced on both ends to the
# binding's own namespace.
test_binding_emits_edge_to_azure_identity if {
	result := aad_pod_identity.derive with input as {
		"kind": "AzureIdentityBinding",
		"apiVersion": "aadpodidentity.k8s.io/v1",
		"metadata": {"name": "petclinic-binding", "namespace": "petclinic"},
		"spec": {"azureIdentity": "petclinic-identity", "selector": "petclinic"},
	}
	count(result) == 1
	some edge in result
	edge.type == "BINDS_PLATFORM_IDENTITY"
	edge.from.kind == "AzureIdentityBinding"
	edge.from.namespace == "petclinic"
	edge.from.name == "petclinic-binding"
	edge.to.kind == "AzureIdentity"
	edge.to.namespace == "petclinic"
	edge.to.name == "petclinic-identity"
}

# Empty spec.azureIdentity: a binding that names no identity is
# malformed; skip rather than emit an edge to an empty-named node.
test_empty_azure_identity_emits_no_edge if {
	result := aad_pod_identity.derive with input as {
		"kind": "AzureIdentityBinding",
		"apiVersion": "aadpodidentity.k8s.io/v1",
		"metadata": {"name": "broken", "namespace": "petclinic"},
		"spec": {"azureIdentity": "", "selector": "petclinic"},
	}
	count(result) == 0
}

# Missing spec block: malformed object, the rule must not panic.
test_missing_spec_emits_no_edge if {
	result := aad_pod_identity.derive with input as {
		"kind": "AzureIdentityBinding",
		"apiVersion": "aadpodidentity.k8s.io/v1",
		"metadata": {"name": "minimal", "namespace": "petclinic"},
	}
	count(result) == 0
}

# Kind mismatch: the module matches AzureIdentityBinding only. An
# AzureIdentity input (the to-side kind) must NOT fire the rule,
# even though it carries a spec.
test_skipped_for_azure_identity_input if {
	result := aad_pod_identity.derive with input as {
		"kind": "AzureIdentity",
		"apiVersion": "aadpodidentity.k8s.io/v1",
		"metadata": {"name": "petclinic-identity", "namespace": "petclinic"},
		"spec": {
			"type": 0,
			"resourceID": "/subscriptions/x/resourcegroups/rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/petclinic-mi",
			"clientID": "00000000-0000-0000-0000-000000000000",
		},
	}
	count(result) == 0
}

# resourceID is metadata only: an AzureIdentity referenced by a
# binding is a real K8s node, but its spec.resourceID (an Azure
# Managed Identity ID) must never produce an extra edge or node.
# A binding input carries no resourceID, so this pins behaviour by
# asserting the binding emits exactly one edge — to AzureIdentity,
# never to a cloud resource.
test_binding_emits_exactly_one_k8s_edge if {
	result := aad_pod_identity.derive with input as {
		"kind": "AzureIdentityBinding",
		"apiVersion": "aadpodidentity.k8s.io/v1",
		"metadata": {"name": "payments-binding", "namespace": "payments"},
		"spec": {"azureIdentity": "payments-identity", "selector": "payments"},
	}
	count(result) == 1
	some edge in result
	edge.to.kind == "AzureIdentity"
}
