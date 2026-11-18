# ClickStack Helm charts

[ClickStack](https://clickhouse.com/docs/use-cases/observability/clickstack) is an open-source observability stack for logs, metrics and traces, built on ClickHouse, OpenTelemetry and HyperDX. This is its Helm chart repository.

## Install

```bash
helm repo add clickstack https://clickhouse.github.io/ClickStack-helm-charts
helm repo update

# Install the operators and their CRDs first
helm install clickstack-operators clickstack/clickstack-operators

# Then ClickStack, once the operators are ready
helm install my-clickstack clickstack/clickstack
```

## Charts

| Chart | What it installs |
|---|---|
| [clickstack-operators](https://github.com/ClickHouse/ClickStack-helm-charts/blob/main/charts/clickstack-operators/README.md) | The ClickHouse and MongoDB operators and their CRDs. Install it first. |
| [clickstack](https://github.com/ClickHouse/ClickStack-helm-charts/blob/main/charts/clickstack/README.md) | HyperDX, the OpenTelemetry Collector, and the ClickHouse and MongoDB resources the operators manage. |

## Documentation

- [Deploying with Helm](https://clickhouse.com/docs/use-cases/observability/clickstack/deployment/helm): configuration, cloud providers, ingress and troubleshooting
- [Upgrade guide](https://github.com/ClickHouse/ClickStack-helm-charts/blob/main/docs/UPGRADE.md): what to change when moving between chart versions
- [Artifact Hub](https://artifacthub.io/packages/search?repo=clickstack): both charts with their versions, default values and security reports
- [Releases](https://github.com/ClickHouse/ClickStack-helm-charts/releases): chart packages and release notes
- [Source and issues](https://github.com/ClickHouse/ClickStack-helm-charts)
