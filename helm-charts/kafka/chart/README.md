# Kafka (Strimzi) Helm Chart

This chart provisions a production-ready Apache Kafka cluster using Strimzi custom resources.

Prerequisites
- Strimzi CRDs installed and the Strimzi operator running in (and watching) the target namespace.
- A default StorageClass or an explicit storageClass provided in values.

What this chart creates
- Kafka CR (spec.kafka) with persistent storage and TLS-enabled listeners
- Optional: KafkaTopics and KafkaUsers from values
- Optional: KafkaConnect CR

Not included
- Strimzi operator installation (install separately)
- External DNS or ingress for Kafka (configure listeners accordingly)

Quickstart
1) Install/upgrade Strimzi operator (example):
   kubectl create namespace kafka || true
   helm repo add strimzi https://strimzi.io/charts/
   helm upgrade --install strimzi-kafka-operator strimzi/strimzi-kafka-operator -n kafka

2) Deploy this chart (defaults use NodePort for external access):
   helm upgrade --install kafka ./charts/kafka -n kafka

3) Check status:
   kubectl get kafka -n kafka
   kubectl get pods -l strimzi.io/cluster=kafka-cluster -n kafka

4) Connect:
   - Internal bootstrap: kafka-cluster-kafka-bootstrap.kafka.svc:9092
   - External (NodePort): see service kafka-cluster-kafka-external-bootstrap

Customization
- Set clusterName, storage sizes, and resources under values.yaml.
- Define topics under values.topics and users under values.users.
- To enable KafkaConnect, set connect.enabled=true and provide config.

Notes
- Ensure replication factors do not exceed the number of brokers.
- When enabling external exposure in production, prefer type: loadbalancer or ingress (OpenShift route), and secure via TLS.
