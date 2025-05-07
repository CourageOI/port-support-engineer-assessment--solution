{
  "replica_count": .spec.replicas,
  "deployment_strategy": .spec.strategy.type,
  "service_environment": (.metadata.labels.service + "-" + .metadata.labels.environment)
}