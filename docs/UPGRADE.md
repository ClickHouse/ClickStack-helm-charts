# Upgrade Guide: Migrating to the Subchart Architecture

This guide covers migrating from the inline-template ClickStack chart (v1.x) to the subchart-based architecture. This is a **breaking change** that replaces hand-rolled Kubernetes resources with operator-managed custom resources for MongoDB and ClickHouse, and uses the official OpenTelemetry Collector Helm chart.

## Prerequisites

- Back up your data before upgrading (MongoDB, ClickHouse PVCs)
- Review your current `values.yaml` overrides -- most keys under `mongodb`, `clickhouse`, and `otel` have changed

## What Changed

| Component | Before (v1.x) | After |
|-----------|---------------|-------|
| MongoDB | Inline Deployment + Service + PVC | [MongoDB Kubernetes Operator (MCK)](https://github.com/mongodb/mongodb-kubernetes) managing a `MongoDBCommunity` CR |
| ClickHouse | Inline Deployment + Service + ConfigMaps + PVCs | [ClickHouse Operator](https://clickhouse.com/docs/clickhouse-operator/overview) managing `ClickHouseCluster` + `KeeperCluster` CRs |
| OTEL Collector | Inline Deployment + Service | [Official OpenTelemetry Collector Helm chart](https://github.com/open-telemetry/opentelemetry-helm-charts) with a chart-managed env ConfigMap |
| hdx-oss-v2 | Deprecated legacy chart | Removed entirely |

## MongoDB Migration

### Removed values

The following `mongodb.*` values no longer exist:

```yaml
# REMOVED -- do not use
mongodb:
  image: "..."
  port: 27017
  strategy: ...
  nodeSelector: {}
  tolerations: []
  livenessProbe: ...
  readinessProbe: ...
  persistence:
    enabled: true
    dataSize: 10Gi
```

### New values

MongoDB is now managed by the MCK operator via a `MongoDBCommunity` custom resource. The CR spec is rendered verbatim from `mongodb.spec`:

```yaml
mongodb:
  enabled: true
  password: "hyperdx"          # Used by the password Secret and mongoUri
  spec:                         # Full MongoDBCommunity CRD spec
    members: 1
    type: ReplicaSet
    version: "5.0.32"
    security:
      authentication:
        modes: ["SCRAM"]
    users:
      - name: hyperdx
        db: hyperdx
        passwordSecretRef:
          name: '{{ include "clickstack.mongodb.fullname" . }}-password'
        roles:
          - name: dbOwner
            db: hyperdx
          - name: clusterMonitor
            db: admin
        scramCredentialsSecretName: '{{ include "clickstack.mongodb.fullname" . }}-scram'
    additionalMongodConfig:
      storage.wiredTiger.engineConfig.journalCompressor: zlib
```

MongoDB now uses **SCRAM authentication** (the previous chart ran without auth). The connection string includes credentials automatically.

To add persistence (previously `mongodb.persistence`), add a `statefulSet` block inside `mongodb.spec`:

```yaml
mongodb:
  spec:
    # ... other fields ...
    statefulSet:
      spec:
        volumeClaimTemplates:
          - metadata:
              name: data-volume
            spec:
              accessModes: ["ReadWriteOnce"]
              storageClassName: "your-storage-class"
              resources:
                requests:
                  storage: 10Gi
```

The MCK operator subchart is configured under `mongodb-kubernetes:`. See the [MCK documentation](https://github.com/mongodb/mongodb-kubernetes/tree/master/docs/mongodbcommunity) for all available CRD fields.

## ClickHouse Migration

### Removed values

The following `clickhouse.*` values no longer exist:

```yaml
# REMOVED -- do not use
clickhouse:
  image: "..."
  terminationGracePeriodSeconds: 90
  resources: {}
  livenessProbe: ...
  readinessProbe: ...
  startupProbe: ...
  nodeSelector: {}
  tolerations: []
  service:
    type: ClusterIP
    annotations: {}
  persistence:
    enabled: true
    dataSize: 10Gi
    logSize: 5Gi
  config:
    clusterCidrs: [...]
```

### New values

ClickHouse is now managed by the ClickHouse Operator via `ClickHouseCluster` and `KeeperCluster` custom resources. Both CR specs are rendered verbatim from values:

```yaml
clickhouse:
  enabled: true
  port: 8123                    # Used for cross-service wiring
  nativePort: 9000
  config:
    users:                      # Still used by OTEL collector and defaultConnections
      appUserPassword: "hyperdx"
      otelUserPassword: "otelcollectorpass"
      otelUserName: "otelcollector"
  prometheus:
    enabled: true
    port: 9363
  keeper:
    spec:                       # Full KeeperCluster CRD spec
      replicas: 1
      dataVolumeClaimSpec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 5Gi
  cluster:
    spec:                       # Full ClickHouseCluster CRD spec
      replicas: 1
      shards: 1
      keeperClusterRef:
        name: '{{ include "clickstack.clickhouse.keeper" . }}'
      dataVolumeClaimSpec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 10Gi
      settings:
        extraUsersConfig:
          users:
            app:
              password: '{{ .Values.clickhouse.config.users.appUserPassword }}'
              # ...
            otelcollector:
              password: '{{ .Values.clickhouse.config.users.otelUserPassword }}'
              # ...
        extraConfig:
          max_connections: 4096
          keep_alive_timeout: 64
          max_concurrent_queries: 100
```

The ClickHouse Operator subchart is configured under `clickhouse-operator:`. Webhooks and cert-manager are disabled by default. See the [operator configuration guide](https://clickhouse.com/docs/clickhouse-operator/guides/configuration) for all available CRD fields.

## OTEL Collector Migration

### Removed values

The following `otel.*` values no longer exist:

```yaml
# REMOVED -- do not use
otel:
  image: ...
  replicas: 1
  resources: {}
  annotations: {}
  nodeSelector: {}
  tolerations: []
  port: 13133
  nativePort: 24225
  grpcPort: 4317
  httpPort: 4318
  healthPort: 8888
  env: []
  customConfig: ...
  livenessProbe: ...
  readinessProbe: ...
```

### New values

The OTEL Collector is now deployed via the official OpenTelemetry Collector Helm chart. Service discovery env vars (ClickHouse endpoint, OpAMP URL, etc.) are managed by the parent chart via a ConfigMap.

```yaml
otel:
  enabled: true
  # Override to point at external services:
  clickhouseEndpoint:          # defaults to chart's ClickHouse service
  clickhouseUser:              # defaults to clickhouse.config.users.otelUserName
  clickhousePassword:          # defaults to clickhouse.config.users.otelUserPassword
  clickhousePrometheusEndpoint:
  clickhouseDatabase: "default"
  opampServerUrl:              # defaults to chart's HyperDX app service

otel-collector:                # Official subchart values
  mode: deployment
  image:
    repository: docker.clickhouse.com/clickhouse/clickstack-otel-collector
    tag: ""
  # ... ports, volumes, command configured by default
```

To set resources (previously `otel.resources`):

```yaml
otel-collector:
  resources:
    requests:
      memory: "128Mi"
      cpu: "100m"
    limits:
      memory: "256Mi"
      cpu: "200m"
```

To set replicas (previously `otel.replicas`):

```yaml
otel-collector:
  replicaCount: 3
```

To set nodeSelector/tolerations (previously `otel.nodeSelector`/`otel.tolerations`):

```yaml
otel-collector:
  nodeSelector:
    node-role: monitoring
  tolerations:
    - key: monitoring
      operator: Equal
      value: otel
      effect: NoSchedule
```

See the [OpenTelemetry Collector Helm chart](https://github.com/open-telemetry/opentelemetry-helm-charts/tree/main/charts/opentelemetry-collector) for all available subchart values.

## Unchanged Values

The following sections are **not affected** by this migration:

- `global.*` (imageRegistry, imagePullSecrets, storageClassName, keepPVC)
- `hyperdx.*` (image, ports, probes, ingress, replicas, PDB, service, env, defaultConnections, defaultSources)
- `tasks.*` (checkAlerts schedule and resources)

## Fresh Install vs. In-Place Upgrade

For a **fresh install**, no special steps are needed. The default values work out of the box.

For an **in-place upgrade** of an existing release, be aware that:

1. The operators (MCK, ClickHouse Operator) will be installed as new deployments in your namespace
2. The existing MongoDB Deployment and ClickHouse Deployment will be deleted by Helm (they are no longer in the chart's templates)
3. The operators will create new StatefulSets to manage MongoDB and ClickHouse
4. **PVCs from the old chart are not automatically reused** by the operator-managed StatefulSets

We recommend performing a fresh install alongside the existing deployment and migrating data, rather than an in-place upgrade.
