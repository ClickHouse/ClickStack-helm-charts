# ClickStack Helm Charts

**ClickStack** is an open-source observability stack combining ClickHouse, HyperDX, and OpenTelemetry for logs, metrics, and traces.

## Quick Start
```bash
helm repo add clickstack https://clickhouse.github.io/ClickStack-helm-charts
helm repo update
helm install my-clickstack clickstack/clickstack
```

For configuration, cloud deployment, ingress setup, and troubleshooting, see the [official documentation](https://clickhouse.com/docs/use-cases/observability/clickstack/deployment/helm).

## Charts

- **`clickstack/clickstack`** (v1.0.0+) - Recommended for all deployments

## Subchart Dependencies

The ClickStack chart uses the following third-party operator charts as subchart dependencies:

- **[MongoDB Kubernetes Operator (MCK)](https://github.com/mongodb/mongodb-kubernetes)** - Manages MongoDB Community replica sets via a `MongoDBCommunity` custom resource. See the [MCK community docs](https://github.com/mongodb/mongodb-kubernetes/tree/master/docs/mongodbcommunity) for advanced configuration.
- **[OpenTelemetry Collector](https://github.com/open-telemetry/opentelemetry-helm-charts)** - Deploys the ClickStack OTEL collector image via the official OpenTelemetry Collector Helm chart. Dynamic environment variables (ClickHouse/HyperDX service discovery) are injected via a chart-managed ConfigMap.
- **[ClickHouse Operator](https://clickhouse.com/docs/clickhouse-operator/overview)** - Manages ClickHouse and Keeper clusters via `ClickHouseCluster` and `KeeperCluster` custom resources. See the [operator configuration guide](https://clickhouse.com/docs/clickhouse-operator/guides/configuration) for advanced settings.

## Support

- **[Documentation](https://clickhouse.com/docs/use-cases/observability/clickstack)** - Installation, configuration, guides
- **[Issues](https://github.com/ClickHouse/ClickStack-helm-charts/issues)** - Report bugs or request features
