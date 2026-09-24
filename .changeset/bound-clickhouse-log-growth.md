---
"helm-charts": minor
---

fix(clickstack): bound ClickHouse server log and system log table growth on the data volume

The ClickHouse operator defaults to `logger.level: trace` with 50 x 1000M rotated log files, and enables `query_log`, `part_log`, `text_log`, `metric_log` and `asynchronous_metric_log` without a TTL. Both are written to the ClickHouse data volume, so the chart's 10Gi default fills up within days of light use, after which the OTel collector drops every batch. The chart now sets `clickhouse.cluster.spec.settings.logger` to `information` / `100M` / 10 files and adds a 7 day TTL to those five system tables via `extraConfig`. Override either block in your values to keep more history.

On upgrade, ClickHouse recreates each system table whose TTL changed and keeps the old rows in `system.<table>_0`; drop those once you no longer need them.
