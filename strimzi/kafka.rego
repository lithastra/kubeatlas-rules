# Copyright 2026 The KubeAtlas Authors
# SPDX-License-Identifier: Apache-2.0
#
# Strimzi Kafka: cluster workload edges.
#
# A ZooKeeper-based Strimzi Kafka cluster carries a spec.zookeeper
# block. For such a cluster the Strimzi operator runs two
# StatefulSets it names by the convention <cluster>-kafka and
# <cluster>-zookeeper. Edge: Kafka -> StatefulSet (MANAGES).
#
# A KRaft cluster carries no spec.zookeeper — its broker topology is
# governed by KafkaNodePools / StrimziPodSets that vary by Strimzi
# version — and derives no edge, keeping the pack sound.
#
# Anti-patterns guarded:
#   * The StatefulSet names follow Strimzi's fixed convention, so
#     the edges are derivable from the Kafka CR alone.
#   * No edge when spec.zookeeper is absent.
package kubeatlas.rules.strimzi.kafka

import rego.v1

# The operator-managed StatefulSet roles for a ZooKeeper-based
# cluster, each suffixed onto the Kafka cluster name.
managed_statefulset_roles := {"kafka", "zookeeper"}

derive contains edge if {
	input.spec.zookeeper
	some role in managed_statefulset_roles
	edge := {
		"type": "MANAGES",
		"from": {
			"kind": "Kafka",
			"namespace": input.metadata.namespace,
			"name": input.metadata.name,
		},
		"to": {
			"kind": "StatefulSet",
			"namespace": input.metadata.namespace,
			"name": sprintf("%s-%s", [input.metadata.name, role]),
		},
	}
}
