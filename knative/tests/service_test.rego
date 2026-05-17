package kubeatlas.rules.knative.service_test

import rego.v1

import data.kubeatlas.rules.knative.service

# A Knative Service points at its same-named Configuration.
test_service_emits_creates_configuration if {
	result := service.derive with input as {
		"kind": "Service",
		"apiVersion": "serving.knative.io/v1",
		"metadata": {"name": "helloworld", "namespace": "default"},
		"spec": {"template": {"spec": {"containers": [{"image": "gcr.io/knative-samples/helloworld-go"}]}}},
	}
	count(result) == 1
	some edge in result
	edge.type == "CREATES_CONFIGURATION"
	edge.from.kind == "Service"
	edge.from.namespace == "default"
	edge.from.name == "helloworld"
	edge.to.kind == "Configuration"
	edge.to.namespace == "default"
	edge.to.name == "helloworld"
}

# A Configuration points at its latest created Revision.
test_configuration_latest_created_emits_creates_revision if {
	result := service.derive with input as {
		"kind": "Configuration",
		"apiVersion": "serving.knative.io/v1",
		"metadata": {"name": "helloworld", "namespace": "default"},
		"status": {"latestCreatedRevisionName": "helloworld-00002"},
	}
	count(result) == 1
	some edge in result
	edge.type == "CREATES_REVISION"
	edge.from.kind == "Configuration"
	edge.from.name == "helloworld"
	edge.to.kind == "Revision"
	edge.to.namespace == "default"
	edge.to.name == "helloworld-00002"
}

# Distinct created and ready Revisions yield two edges.
test_configuration_distinct_created_and_ready_emit_two_edges if {
	result := service.derive with input as {
		"kind": "Configuration",
		"metadata": {"name": "helloworld", "namespace": "default"},
		"status": {
			"latestCreatedRevisionName": "helloworld-00003",
			"latestReadyRevisionName": "helloworld-00002",
		},
	}
	count(result) == 2
	names := {e.to.name | some e in result}
	names == {"helloworld-00002", "helloworld-00003"}
}

# When created and ready name the same Revision the edge dedupes.
test_configuration_same_created_and_ready_deduplicated if {
	result := service.derive with input as {
		"kind": "Configuration",
		"metadata": {"name": "helloworld", "namespace": "default"},
		"status": {
			"latestCreatedRevisionName": "helloworld-00001",
			"latestReadyRevisionName": "helloworld-00001",
		},
	}
	count(result) == 1
}

# A Configuration with no status (not yet reconciled) derives nothing.
test_configuration_without_status_emits_no_edge if {
	result := service.derive with input as {
		"kind": "Configuration",
		"metadata": {"name": "helloworld", "namespace": "default"},
		"spec": {"template": {"spec": {"containers": [{"image": "x"}]}}},
	}
	count(result) == 0
}

# A Service carries status revision fields too, but the
# Configuration-side rule must not fire for a Service.
test_service_does_not_emit_creates_revision if {
	result := service.derive with input as {
		"kind": "Service",
		"metadata": {"name": "helloworld", "namespace": "default"},
		"status": {
			"latestCreatedRevisionName": "helloworld-00001",
			"latestReadyRevisionName": "helloworld-00001",
		},
	}
	count(result) == 1
	some edge in result
	edge.type == "CREATES_CONFIGURATION"
}
