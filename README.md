# ClickStack Helm Charts

**ClickStack** is an open-source observability stack combining ClickHouse, HyperDX, and OpenTelemetry for logs, metrics, and traces.

## Quick Start
```bash
helm repo add clickstack https://hyperdxio.github.io/helm-charts
helm repo update
helm install my-clickstack clickstack/clickstack
```

For configuration, cloud deployment, ingress setup, and troubleshooting, see the [official documentation](https://clickhouse.com/docs/use-cases/observability/clickstack/deployment/helm).

## Charts

- **`clickstack/clickstack`** (v1.0.0+) - Recommended for all deployments
- **`clickstack/hdx-oss-v2`** (v0.8.4) - Legacy (migrate to `clickstack`)

## Support

- **[Documentation](https://clickhouse.com/docs/use-cases/observability/clickstack)** - Installation, configuration, guides
- **[Issues](https://github.com/hyperdxio/helm-charts/issues)** - Report bugs or request features
