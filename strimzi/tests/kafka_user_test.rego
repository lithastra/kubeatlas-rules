package kubeatlas.rules.strimzi.kafka_user_test

import rego.v1

import data.kubeatlas.rules.strimzi.kafka_user

# The strimzi.io/cluster label resolves to the Kafka cluster CR.
test_cluster_label_emits_belongs_to_cluster if {
	result := kafka_user.derive with input as {
		"kind": "KafkaUser",
		"apiVersion": "kafka.strimzi.io/v1beta2",
		"metadata": {
			"name": "orders-consumer",
			"namespace": "kafka",
			"labels": {"strimzi.io/cluster": "my-cluster"},
		},
		"spec": {"authentication": {"type": "tls"}},
	}
	count(result) == 1
	some edge in result
	edge.type == "BELONGS_TO_CLUSTER"
	edge.from.kind == "KafkaUser"
	edge.from.namespace == "kafka"
	edge.from.name == "orders-consumer"
	edge.to.kind == "Kafka"
	edge.to.namespace == "kafka"
	edge.to.name == "my-cluster"
}

# A KafkaUser with no strimzi.io/cluster label derives nothing.
test_missing_cluster_label_emits_no_edge if {
	result := kafka_user.derive with input as {
		"kind": "KafkaUser",
		"metadata": {"name": "orders-consumer", "namespace": "kafka", "labels": {"app": "x"}},
		"spec": {"authentication": {"type": "tls"}},
	}
	count(result) == 0
}

# An empty cluster label derives nothing.
test_empty_cluster_label_emits_no_edge if {
	result := kafka_user.derive with input as {
		"kind": "KafkaUser",
		"metadata": {"name": "orders-consumer", "namespace": "kafka", "labels": {"strimzi.io/cluster": ""}},
		"spec": {"authentication": {"type": "tls"}},
	}
	count(result) == 0
}
