# Copyright 2026 The KubeAtlas Authors
# SPDX-License-Identifier: Apache-2.0
#
# Strimzi KafkaTopic: cluster-membership edge.
#
# A KafkaTopic (kafka.strimzi.io) is assigned to a Kafka cluster
# through the required strimzi.io/cluster label — the operator uses
# it to route the topic. The Kafka cluster CR lives in the same
# namespace as the topic.
#
# Edge: KafkaTopic -> Kafka (BELONGS_TO_CLUSTER).
#
# Anti-patterns guarded:
#   * No edge when the strimzi.io/cluster label is absent or empty.
package kubeatlas.rules.strimzi.kafka_topic

import rego.v1

cluster_label := "strimzi.io/cluster"

derive contains edge if {
	cluster := input.metadata.labels[cluster_label]
	cluster != ""
	edge := {
		"type": "BELONGS_TO_CLUSTER",
		"from": {
			"kind": "KafkaTopic",
			"namespace": input.metadata.namespace,
			"name": input.metadata.name,
		},
		"to": {
			"kind": "Kafka",
			"namespace": input.metadata.namespace,
			"name": cluster,
		},
	}
}
