---
"helm-charts": minor
---

feat(clickstack): surface ClickHouse table TTL as configurable values

Defaults and documents `HYPERDX_OTEL_EXPORTER_TABLES_TTL` (720h) in `hyperdx.config`, and documents the per-signal overrides (`HYPERDX_OTEL_EXPORTER_LOGS_TTL` / `_TRACES_TTL` / `_METRICS_TTL` / `_SESSIONS_TTL`) plus `HYPERDX_OTEL_EXPORTER_RECONCILE_TABLE_TTL`. Operators can now set ClickHouse data retention per signal — e.g. keep logs and traces for 6 months for compliance while metrics stay short — without hand-crafting collector env vars. The global TTL works today; the per-signal overrides and reconcile require a collector image that includes hyperdxio/hyperdx#2709.
