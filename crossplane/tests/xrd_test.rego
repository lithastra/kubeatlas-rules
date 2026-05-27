package kubeatlas.rules.crossplane.xrd_test

import rego.v1

import data.kubeatlas.rules.crossplane.xrd

test_default_composition_ref if {
	result := xrd.derive with input as {
		"kind": "CompositeResourceDefinition",
		"apiVersion": "apiextensions.crossplane.io/v1",
		"metadata": {"name": "xpostgresqlinstances.database.example.org"},
		"spec": {
			"group": "database.example.org",
			"names": {"kind": "XPostgreSQLInstance", "plural": "xpostgresqlinstances"},
			"defaultCompositionRef": {"name": "composition-aws-postgresql"},
		},
	}
	count(result) == 1
	some edge in result
	edge.type == "USES_COMPOSITION"
	edge.from.kind == "CompositeResourceDefinition"
	edge.from.namespace == ""
	edge.from.name == "xpostgresqlinstances.database.example.org"
	edge.to.kind == "Composition"
	edge.to.namespace == ""
	edge.to.name == "composition-aws-postgresql"
}

test_no_default_composition_ref if {
	result := xrd.derive with input as {
		"kind": "CompositeResourceDefinition",
		"apiVersion": "apiextensions.crossplane.io/v1",
		"metadata": {"name": "xnetworks.network.example.org"},
		"spec": {
			"group": "network.example.org",
			"names": {"kind": "XNetwork", "plural": "xnetworks"},
		},
	}
	count(result) == 0
}

test_empty_composition_ref_name if {
	result := xrd.derive with input as {
		"kind": "CompositeResourceDefinition",
		"apiVersion": "apiextensions.crossplane.io/v1",
		"metadata": {"name": "xbuckets.storage.example.org"},
		"spec": {
			"group": "storage.example.org",
			"names": {"kind": "XBucket", "plural": "xbuckets"},
			"defaultCompositionRef": {"name": ""},
		},
	}
	count(result) == 0
}

test_kind_mismatch if {
	result := xrd.derive with input as {
		"kind": "Composition",
		"apiVersion": "apiextensions.crossplane.io/v1",
		"metadata": {"name": "some-composition"},
		"spec": {"defaultCompositionRef": {"name": "other"}},
	}
	count(result) == 0
}
