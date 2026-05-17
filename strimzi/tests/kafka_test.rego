package kubeatlas.rules.strimzi.kafka_test

import rego.v1

import data.kubeatlas.rules.strimzi.kafka

# A ZooKeeper-based cluster manages the kafka and zookeeper
# StatefulSets named after the cluster.
test_zookeeper_cluster_manages_both_statefulsets if {
	result := kafka.derive with input as {
		"kind": "Kafka",
		"apiVersion": "kafka.strimzi.io/v1beta2",
		"metadata": {"name": "my-cluster", "namespace": "kafka"},
		"spec": {
			"kafka": {"replicas": 3},
			"zookeeper": {"replicas": 3},
		},
	}
	count(result) == 2
	some edge in result
	edge.type == "MANAGES"
	edge.from.kind == "Kafka"
	edge.from.namespace == "kafka"
	edge.from.name == "my-cluster"
	names := {e.to.name | some e in result}
	names == {"my-cluster-kafka", "my-cluster-zookeeper"}
	kinds := {e.to.kind | some e in result}
	kinds == {"StatefulSet"}
}

# A KRaft cluster (no spec.zookeeper) derives no edge.
test_kraft_cluster_emits_no_edge if {
	result := kafka.derive with input as {
		"kind": "Kafka",
		"apiVersion": "kafka.strimzi.io/v1beta2",
		"metadata": {"name": "kraft-cluster", "namespace": "kafka"},
		"spec": {"kafka": {"replicas": 3}},
	}
	count(result) == 0
}
