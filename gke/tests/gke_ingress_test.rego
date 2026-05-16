package kubeatlas.rules.gke.gke_ingress_test

import rego.v1

import data.kubeatlas.rules.gke.gke_ingress

# --- BackendConfig (Service annotation) ----------------------------

# "default" form: one BackendConfig for every port.
test_service_default_backend_config_emits_edge if {
	result := gke_ingress.derive with input as {
		"kind": "Service",
		"apiVersion": "v1",
		"metadata": {
			"name": "petclinic",
			"namespace": "petclinic",
			"annotations": {"cloud.google.com/backend-config": "{\"default\":\"petclinic-bc\"}"},
		},
	}
	count(result) == 1
	some edge in result
	edge.type == "USES_BACKEND_CONFIG"
	edge.from.kind == "Service"
	edge.from.namespace == "petclinic"
	edge.from.name == "petclinic"
	edge.to.kind == "BackendConfig"
	edge.to.namespace == "petclinic"
	edge.to.name == "petclinic-bc"
}

# "ports" form: a BackendConfig per port — two distinct configs
# produce two edges.
test_service_per_port_backend_config_emits_edge_per_config if {
	result := gke_ingress.derive with input as {
		"kind": "Service",
		"apiVersion": "v1",
		"metadata": {
			"name": "petclinic",
			"namespace": "petclinic",
			"annotations": {"cloud.google.com/backend-config": "{\"ports\":{\"80\":\"bc-http\",\"443\":\"bc-https\"}}"},
		},
	}
	count(result) == 2
	names := {e.to.name | some e in result}
	names == {"bc-http", "bc-https"}
}

# The older beta annotation key is honoured too.
test_service_beta_annotation_key_is_honoured if {
	result := gke_ingress.derive with input as {
		"kind": "Service",
		"apiVersion": "v1",
		"metadata": {
			"name": "legacy",
			"namespace": "petclinic",
			"annotations": {"beta.cloud.google.com/backend-config": "{\"default\":\"legacy-bc\"}"},
		},
	}
	count(result) == 1
	some edge in result
	edge.to.name == "legacy-bc"
}

# No backend-config annotation: no edge.
test_service_without_annotation_emits_no_edge if {
	result := gke_ingress.derive with input as {
		"kind": "Service",
		"apiVersion": "v1",
		"metadata": {"name": "plain", "namespace": "petclinic"},
	}
	count(result) == 0
}

# Malformed annotation JSON: json.unmarshal is undefined, so the
# rule derives nothing rather than erroring.
test_service_malformed_annotation_json_emits_no_edge if {
	result := gke_ingress.derive with input as {
		"kind": "Service",
		"apiVersion": "v1",
		"metadata": {
			"name": "broken",
			"namespace": "petclinic",
			"annotations": {"cloud.google.com/backend-config": "{not-json"},
		},
	}
	count(result) == 0
}

# An empty config name in the annotation is skipped.
test_service_empty_backend_config_name_emits_no_edge if {
	result := gke_ingress.derive with input as {
		"kind": "Service",
		"apiVersion": "v1",
		"metadata": {
			"name": "petclinic",
			"namespace": "petclinic",
			"annotations": {"cloud.google.com/backend-config": "{\"default\":\"\"}"},
		},
	}
	count(result) == 0
}

# --- FrontendConfig (Ingress annotation) ---------------------------

test_ingress_frontend_config_emits_edge if {
	result := gke_ingress.derive with input as {
		"kind": "Ingress",
		"apiVersion": "networking.k8s.io/v1",
		"metadata": {
			"name": "petclinic",
			"namespace": "petclinic",
			"annotations": {"networking.gke.io/v1beta1.FrontendConfig": "petclinic-fc"},
		},
	}
	count(result) == 1
	some edge in result
	edge.type == "USES_FRONTEND_CONFIG"
	edge.from.kind == "Ingress"
	edge.from.name == "petclinic"
	edge.to.kind == "FrontendConfig"
	edge.to.namespace == "petclinic"
	edge.to.name == "petclinic-fc"
}

test_ingress_without_frontend_config_emits_no_edge if {
	result := gke_ingress.derive with input as {
		"kind": "Ingress",
		"apiVersion": "networking.k8s.io/v1",
		"metadata": {"name": "plain", "namespace": "petclinic"},
	}
	count(result) == 0
}

# Kind mismatch: a backend-config annotation on some other kind must
# not fire the Service branch.
test_unrelated_kind_emits_no_edge if {
	result := gke_ingress.derive with input as {
		"kind": "ConfigMap",
		"apiVersion": "v1",
		"metadata": {
			"name": "cm",
			"namespace": "petclinic",
			"annotations": {"cloud.google.com/backend-config": "{\"default\":\"bc\"}"},
		},
	}
	count(result) == 0
}
