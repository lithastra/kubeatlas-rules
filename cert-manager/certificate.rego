# Copyright 2026 The KubeAtlas Authors
# SPDX-License-Identifier: Apache-2.0
#
# cert-manager Certificate -> Secret "STORES_IN" edge.
#
# Every Certificate.spec.secretName is the Secret cert-manager
# writes the issued certificate (and private key) into. The Secret
# is always in the same namespace as the Certificate — cert-manager
# does not write across namespaces.
package kubeatlas.rules.cert_manager.certificate

import rego.v1

derive contains edge if {
	input.kind == "Certificate"
	input.spec.secretName != ""
	edge := {
		"type": "STORES_IN",
		"from": {
			"kind": "Certificate",
			"namespace": input.metadata.namespace,
			"name": input.metadata.name,
		},
		"to": {
			"kind": "Secret",
			"namespace": input.metadata.namespace,
			"name": input.spec.secretName,
		},
	}
}
