---
"helm-charts": patch
---

fix(clickhouse): set explicit container resources for the ClickHouse server

The clickhouse-operator applies a small default resource block (512Mi memory,
request == limit as of operator v0.0.6) when none is provided. That is too low
for the full ClickStack schema (many materialized views) and caused the
ClickHouse server to OOMKill (exit 137) and crash-loop under ingestion plus
background merges. The chart now sets explicit `containerTemplate.resources`
(2Gi memory, 500m CPU request) which can be overridden per environment.
