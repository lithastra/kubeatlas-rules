package kubeatlas.rules.openshift.route_test

import rego.v1

import data.kubeatlas.rules.openshift.route

# Happy path: spec.to.kind=Service produces exactly one ROUTES_TO
# edge from the Route to that Service in the same namespace.
test_primary_backend if {
	result := route.derive with input as {
		"kind": "Route",
		"apiVersion": "route.openshift.io/v1",
		"metadata": {"namespace": "petclinic", "name": "petclinic"},
		"spec": {
			"host": "petclinic.apps.example.com",
			"to": {"kind": "Service", "name": "petclinic"},
		},
	}
	count(result) == 1
	some edge in result
	edge.type == "ROUTES_TO"
	edge.from.namespace == "petclinic"
	edge.from.name == "petclinic"
	edge.to.kind == "Service"
	edge.to.namespace == "petclinic"
	edge.to.name == "petclinic"
}

# Alternate backends: each Service-kind alternate produces its own
# ROUTES_TO edge alongside the primary edge.
test_alternate_backends if {
	result := route.derive with input as {
		"kind": "Route",
		"apiVersion": "route.openshift.io/v1",
		"metadata": {"namespace": "demo", "name": "blue-green"},
		"spec": {
			"to": {"kind": "Service", "name": "blue", "weight": 50},
			"alternateBackends": [
				{"kind": "Service", "name": "green", "weight": 50},
				{"kind": "Service", "name": "canary", "weight": 0},
			],
		},
	}
	count(result) == 3
	# All edges share the same source Route + namespace.
	every edge in result {
		edge.type == "ROUTES_TO"
		edge.from.name == "blue-green"
		edge.to.kind == "Service"
	}
	# Each backend Service appears exactly once on the to-side.
	to_names := {edge.to.name | some edge in result}
	to_names == {"blue", "green", "canary"}
}

# spec.to.kind != Service (rare but accepted by the API): skip the
# primary edge so we never emit ROUTES_TO pointing at a non-Service.
test_skipped_when_to_kind_not_service if {
	result := route.derive with input as {
		"kind": "Route",
		"apiVersion": "route.openshift.io/v1",
		"metadata": {"namespace": "demo", "name": "weird"},
		"spec": {"to": {"kind": "Pod", "name": "weird-pod"}},
	}
	count(result) == 0
}

# spec.to.name empty — also skip rather than emit a malformed edge.
test_skipped_when_to_name_empty if {
	result := route.derive with input as {
		"kind": "Route",
		"apiVersion": "route.openshift.io/v1",
		"metadata": {"namespace": "demo", "name": "broken"},
		"spec": {"to": {"kind": "Service", "name": ""}},
	}
	count(result) == 0
}

# Kind mismatch: rule must not fire for non-Route inputs even when
# they happen to have a spec.to field.
test_skipped_when_input_kind_not_route if {
	result := route.derive with input as {
		"kind": "Service",
		"apiVersion": "v1",
		"metadata": {"namespace": "demo", "name": "x"},
		"spec": {"to": {"kind": "Service", "name": "y"}},
	}
	count(result) == 0
}

# Alternate backend with kind != Service (e.g. a future Knative
# routable kind) is silently skipped; the primary edge still fires.
test_alternate_non_service_skipped if {
	result := route.derive with input as {
		"kind": "Route",
		"apiVersion": "route.openshift.io/v1",
		"metadata": {"namespace": "demo", "name": "mixed"},
		"spec": {
			"to": {"kind": "Service", "name": "primary"},
			"alternateBackends": [
				{"kind": "Service", "name": "secondary"},
				{"kind": "KnativeService", "name": "future"},
			],
		},
	}
	count(result) == 2
	to_names := {edge.to.name | some edge in result}
	to_names == {"primary", "secondary"}
}
