# ClickStack Helm Charts

**ClickStack** is an open-source observability stack combining ClickHouse, HyperDX, and OpenTelemetry for logs, metrics, and traces.

## Quick Start
```bash
helm repo add clickstack https://clickhouse.github.io/ClickStack-helm-charts
helm repo update

# Step 1: Install operators and CRDs
helm install clickstack-operators clickstack/clickstack-operators

# Step 2: Install ClickStack (after operators are ready)
helm install my-clickstack clickstack/clickstack
```

For configuration, cloud deployment, ingress setup, and troubleshooting, see the [official documentation](https://clickhouse.com/docs/use-cases/observability/clickstack/deployment/helm).

## Charts

- **`clickstack/clickstack-operators`** - Installs the MongoDB and ClickHouse operator controllers and CRDs. Must be installed first.
- **`clickstack/clickstack`** - Installs HyperDX, OpenTelemetry Collector, and operator custom resources.

## Additional Manifests

The `clickstack` chart supports deploying arbitrary Kubernetes objects (NetworkPolicy, HPA, ServiceAccount, PodMonitor, ALB Ingress, etc.) alongside the chart's own resources via the `additionalManifests` value. See the [Additional Manifests Guide](docs/ADDITIONAL-MANIFESTS.md) for usage and examples.

## Operator Dependencies

The `clickstack-operators` chart bundles:

- **[MongoDB Kubernetes Operator (MCK)](https://github.com/mongodb/mongodb-kubernetes)** - Manages MongoDB Community replica sets via a `MongoDBCommunity` custom resource.
- **[ClickHouse Operator](https://clickhouse.com/docs/clickhouse-operator/overview)** - Manages ClickHouse and Keeper clusters via `ClickHouseCluster` and `KeeperCluster` custom resources.

The `clickstack` chart includes:

- **[OpenTelemetry Collector](https://github.com/open-telemetry/opentelemetry-helm-charts)** - Deploys the ClickStack OTEL collector image via the official OpenTelemetry Collector Helm chart.

## Uninstalling

Uninstall in reverse order:
```bash
helm uninstall my-clickstack            # Remove app + CRs first
helm uninstall clickstack-operators     # Remove operators + CRDs
```

**Note:** PersistentVolumeClaims created by the MongoDB and ClickHouse operators are **not** removed by `helm uninstall`. This is by design to prevent accidental data loss. To clean up PVCs, refer to:

- [MongoDB Kubernetes Operator docs](https://github.com/mongodb/mongodb-kubernetes/tree/master/docs/mongodbcommunity)
- [ClickHouse Operator cleanup docs](https://clickhouse.com/docs/clickhouse-operator/managing-clusters/cleanup)

## Upgrading

If you are upgrading from the inline-template chart (v1.x), see the [Upgrade Guide](docs/UPGRADE.md) for migration instructions.

## Support

- **[Documentation](https://clickhouse.com/docs/use-cases/observability/clickstack)** - Installation, configuration, guides
- **[Issues](https://github.com/ClickHouse/ClickStack-helm-charts/issues)** - Report bugs or request features
