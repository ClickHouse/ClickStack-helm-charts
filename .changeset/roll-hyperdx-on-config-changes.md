---
"helm-charts": minor
---

Automatically roll HyperDX pods when the chart-managed ConfigMap or Secret content changes. The first upgrade containing this change adds checksum annotations and triggers a one-time HyperDX rollout.

The bundled otel-collector now rolls on every `helm upgrade`, so it picks up changes to `clickstack-config` and `clickstack-secret` such as a new `CLICKHOUSE_PASSWORD`.
