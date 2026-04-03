# ClickStack API-only deployment

This example shows an advanced deployment pattern where only the HyperDX API is deployed, with MongoDB, ClickHouse, and the OTEL collector provided externally.

## What's included

The `values.yaml` in this directory:

- Disables all subcharts (MongoDB, ClickHouse, OTEL collector)
- Sets `secrets: null` to skip the `clickstack-secret` creation (secrets are managed externally via `deployment.env` `valueFrom` entries)
- Uses the API-only image and exposes port 8000 on the service (`service.apiPort.enabled`)
- Enables autoscaling, network policy (egress deny-list for instance metadata), and a service account with IAM role annotation
- Configures an ALB ingress targeting port 8000

## Managing secrets externally

When `secrets: null` is set, the chart does not create a `clickstack-secret` Kubernetes Secret. You must provide all required environment variables through your own secret management:

| Variable | Description |
|----------|-------------|
| `MONGO_URI` | MongoDB connection string |
| `HYPERDX_API_KEY` | HyperDX API key |

These are provided via `deployment.env` with `valueFrom` references to pre-existing Kubernetes Secrets in the namespace.

The chart will fail to render if `secrets: null` is used while any subchart (MongoDB, ClickHouse, OTEL collector) is enabled, since those subcharts require the `clickstack-secret` for credentials.

## Prerequisites

1. External MongoDB, ClickHouse, and OTEL collector services available and reachable from the cluster.
2. Kubernetes Secrets pre-created in the target namespace with connection strings and API keys.

## Usage

```bash
helm install my-api clickstack/clickstack \
  -f examples/api-only/values.yaml
```

## Customization

| Setting | Where to change | Description |
|---------|-----------------|-------------|
| Image | `deployment.image.repository` / `tag` | Point to your API-only image registry and version |
| Secrets | `deployment.env` | Add/modify `valueFrom` entries for your secret names and keys |
| Config | `config.*` | Override any environment variable in the configmap |
| Ingress | `ingress.annotations` / `spec` | Configure your ingress controller |
| HPA | `autoscaling.spec` | Tune scaling thresholds |
| Service account | `serviceAccount.annotations` | Set provider-specific role bindings |
