# Upgrade Guide: Migrating to the Subchart Architecture

This guide covers migrating from the inline-template ClickStack chart (v1.x) to the subchart-based architecture. This is a **breaking change** that replaces hand-rolled Kubernetes resources with operator-managed custom resources for MongoDB and ClickHouse, and uses the official OpenTelemetry Collector Helm chart.

## Prerequisites

- Back up your data before upgrading (MongoDB, ClickHouse PVCs)
- Review your current `values.yaml` overrides -- most keys have moved or been renamed

## What Changed

| Component | Before (v1.x) | After |
|-----------|---------------|-------|
| MongoDB | Inline Deployment + Service + PVC | [MongoDB Kubernetes Operator (MCK)](https://github.com/mongodb/mongodb-kubernetes) managing a `MongoDBCommunity` CR |
| ClickHouse | Inline Deployment + Service + ConfigMaps + PVCs | [ClickHouse Operator](https://clickhouse.com/docs/clickhouse-operator/overview) managing `ClickHouseCluster` + `KeeperCluster` CRs |
| OTEL Collector | Inline Deployment + Service (`otel.*` block) | [Official OpenTelemetry Collector Helm chart](https://github.com/open-telemetry/opentelemetry-helm-charts) (`otel-collector:` subchart). No separate `otel:` block -- env vars live in `hyperdx.config`/`hyperdx.secrets` |
| HyperDX values | Flat keys under `hyperdx.*` plus top-level `tasks:` and `appUrl` | Reorganised by K8s resource type under `hyperdx.*` (see below) |
| hdx-oss-v2 | Deprecated legacy chart | Removed entirely |

## HyperDX Values Reorganisation

The `hyperdx:` block is now organised by Kubernetes resource type:

```yaml
hyperdx:
  ports:          # Shared port numbers (Deployment, Service, ConfigMap, Ingress)
    api: 8000
    app: 3000
    opamp: 4320

  frontendUrl: "http://localhost:3000"   # Replaces the removed appUrl

  config:         # → clickstack-config ConfigMap (non-sensitive env vars)
    APP_PORT: "3000"
    HYPERDX_LOG_LEVEL: "info"
    # ... full list in values.yaml

  secrets:        # → clickstack-secret Secret (sensitive env vars)
    HYPERDX_API_KEY: "..."
    CLICKHOUSE_PASSWORD: "otelcollectorpass"
    CLICKHOUSE_APP_PASSWORD: "hyperdx"
    MONGODB_PASSWORD: "hyperdx"

  deployment:     # K8s Deployment spec (image, replicas, probes, etc.)
  service:        # K8s Service spec (type, annotations)
  ingress:        # K8s Ingress spec (host, tls, annotations)
  podDisruptionBudget:  # K8s PDB spec
  tasks:          # K8s CronJob specs (previously top-level tasks:)
```

### Key moves

| Before | After |
|--------|-------|
| `appUrl` | Removed. Use `hyperdx.frontendUrl` (defaults to `http://localhost:3000`) |
| `tasks.*` (top-level) | `hyperdx.tasks.*` |
| `mongodb.password` | `hyperdx.secrets.MONGODB_PASSWORD` |
| `clickhouse.config.users.appUserPassword` | `hyperdx.secrets.CLICKHOUSE_APP_PASSWORD` |
| `clickhouse.config.users.otelUserPassword` | `hyperdx.secrets.CLICKHOUSE_PASSWORD` |
| `otel.*` env overrides | `hyperdx.config.*` (non-sensitive) and `hyperdx.secrets.*` (sensitive) |

### Unified ConfigMap and Secret

All environment variables now flow through two static-named resources that are shared by the HyperDX Deployment **and** the OTEL Collector via `envFrom`:

- **`clickstack-config`** ConfigMap -- populated from `hyperdx.config`
- **`clickstack-secret`** Secret -- populated from `hyperdx.secrets`

There is no longer a separate OTEL-specific ConfigMap. Both workloads read from the same sources.

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

The MongoDB password is set in `hyperdx.secrets.MONGODB_PASSWORD` (not `mongodb.password`). It is referenced automatically by the password Secret and the `mongoUri` template.

To add persistence, add a `statefulSet` block inside `mongodb.spec`:

```yaml
mongodb:
  spec:
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

The MCK operator subchart is configured under `mongodb-operator:` (not `mongodb-kubernetes:`). See the [MCK documentation](https://github.com/mongodb/mongodb-kubernetes/tree/master/docs/mongodbcommunity) for all available CRD fields.

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
    users:
      appUserPassword: "..."
      otelUserPassword: "..."
      otelUserName: "..."
```

### New values

ClickHouse is now managed by the ClickHouse Operator via `ClickHouseCluster` and `KeeperCluster` custom resources. Both CR specs are rendered verbatim from values:

```yaml
clickhouse:
  enabled: true
  port: 8123
  nativePort: 9000
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
              password: '{{ .Values.hyperdx.secrets.CLICKHOUSE_APP_PASSWORD }}'
            otelcollector:
              password: '{{ .Values.hyperdx.secrets.CLICKHOUSE_PASSWORD }}'
        extraConfig:
          max_connections: 4096
          keep_alive_timeout: 64
          max_concurrent_queries: 100
```

ClickHouse user credentials are now sourced from `hyperdx.secrets` (not `clickhouse.config.users`). The cluster spec references them with template expressions.

The ClickHouse Operator subchart is configured under `clickhouse-operator:`. Webhooks and cert-manager are disabled by default. See the [operator configuration guide](https://clickhouse.com/docs/clickhouse-operator/guides/configuration) for all available CRD fields.

## OTEL Collector Migration

### Removed values

The entire `otel:` block no longer exists:

```yaml
# REMOVED -- do not use
otel:
  enabled: true
  image: ...
  replicas: 1
  resources: {}
  clickhouseEndpoint: ...
  clickhouseUser: ...
  clickhousePassword: ...
  clickhouseDatabase: "default"
  opampServerUrl: ...
  port: 13133
  nativePort: 24225
  grpcPort: 4317
  httpPort: 4318
  healthPort: 8888
  env: []
  customConfig: ...
```

### New values

The OTEL Collector is now deployed via the official OpenTelemetry Collector Helm chart as the `otel-collector:` subchart. There is no parent-chart `otel:` wrapper -- configure the subchart directly.

Environment variables (ClickHouse endpoint, OpAMP URL, etc.) are shared via the unified `clickstack-config` ConfigMap and `clickstack-secret` Secret. The subchart's `extraEnvsFrom` is pre-wired:

```yaml
otel-collector:
  enabled: true
  mode: deployment
  image:
    repository: docker.clickhouse.com/clickhouse/clickstack-otel-collector
    tag: ""
  extraEnvsFrom:
    - configMapRef:
        name: clickstack-config
    - secretRef:
        name: clickstack-secret
  ports:
    otlp:
      enabled: true
      containerPort: 4317
      servicePort: 4317
    otlp-http:
      enabled: true
      containerPort: 4318
      servicePort: 4318
    # ... see values.yaml for full port list
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

## Fresh Install vs. In-Place Upgrade

For a **fresh install**, no special steps are needed. The default values work out of the box.

For an **in-place upgrade** of an existing release, be aware that:

1. The operators (MCK, ClickHouse Operator) will be installed as new deployments in your namespace
2. The existing MongoDB Deployment and ClickHouse Deployment will be deleted by Helm (they are no longer in the chart's templates)
3. The operators will create new StatefulSets to manage MongoDB and ClickHouse
4. **PVCs from the old chart are not automatically reused** by the operator-managed StatefulSets

We recommend performing a fresh install alongside the existing deployment and migrating data, rather than an in-place upgrade.
