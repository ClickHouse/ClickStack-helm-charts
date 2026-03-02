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

## Support

- **[Documentation](https://clickhouse.com/docs/use-cases/observability/clickstack)** - Installation, configuration, guides
- **[Issues](https://github.com/ClickHouse/ClickStack-helm-charts/issues)** - Report bugs or request features
