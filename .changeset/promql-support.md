---
"helm-charts": minor
---

feat: add PromQL support behind `hyperdx.promql.enabled` (on by default). Sets `ENABLE_PROMQL` and `NEXT_PUBLIC_ENABLE_PROMQL`, adds a PromQL default source on the `metrics_ts` TimeSeries table, and configures ClickHouse with Prometheus remote write/read handlers, the `prometheus_api_v1` HTTP handler and `allow_experimental_time_series_table` on the default profile, and grants the `app` user `CREATE TEMPORARY TABLE` so the handler can evaluate queries. The ClickHouse settings need ClickHouse 26.6 or newer and are skipped automatically on older image tags.
