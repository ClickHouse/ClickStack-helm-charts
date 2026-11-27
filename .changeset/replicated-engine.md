---
"helm-charts": minor
---

feat: fresh installs with the bundled ClickHouse write ClickStack tables to a dedicated `otel` database, created as Replicated with `Replicated*` tables. `helm upgrade` keeps the database and engines of existing installs, and an external ClickHouse keeps `default`. `HYPERDX_OTEL_EXPORTER_CLICKHOUSE_DATABASE` now also drives the default sources and ClickHouse user grants. `HYPERDX_OTEL_EXPORTER_CLICKHOUSE_FALLBACK_DATABASE` keeps existing installs writing to `default` when the chart is rendered without cluster access (ArgoCD, `helm template`). See docs/UPGRADE.md.
