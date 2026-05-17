package kubeatlas.rules.strimzi.kafka_topic_test

import rego.v1

import data.kubeatlas.rules.strimzi.kafka_topic

# The strimzi.io/cluster label resolves to the Kafka cluster CR.
test_cluster_label_emits_belongs_to_cluster if {
	result := kafka_topic.derive with input as {
		"kind": "KafkaTopic",
		"apiVersion": "kafka.strimzi.io/v1beta2",
		"metadata": {
			"name": "orders",
			"namespace": "kafka",
			"labels": {"strimzi.io/cluster": "my-cluster"},
		},
		"spec": {"partitions": 3, "replicas": 3},
	}
	count(result) == 1
	some edge in result
	edge.type == "BELONGS_TO_CLUSTER"
	edge.from.kind == "KafkaTopic"
	edge.from.namespace == "kafka"
	edge.from.name == "orders"
	edge.to.kind == "Kafka"
	edge.to.namespace == "kafka"
	edge.to.name == "my-cluster"
}

# A KafkaTopic with no strimzi.io/cluster label derives nothing.
test_missing_cluster_label_emits_no_edge if {
	result := kafka_topic.derive with input as {
		"kind": "KafkaTopic",
		"metadata": {"name": "orders", "namespace": "kafka", "labels": {"app": "x"}},
		"spec": {"partitions": 3},
	}
	count(result) == 0
}

# An empty cluster label derives nothing.
test_empty_cluster_label_emits_no_edge if {
	result := kafka_topic.derive with input as {
		"kind": "KafkaTopic",
		"metadata": {"name": "orders", "namespace": "kafka", "labels": {"strimzi.io/cluster": ""}},
		"spec": {"partitions": 3},
	}
	count(result) == 0
}
