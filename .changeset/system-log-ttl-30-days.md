---
"helm-charts": patch
---

fix: raise the system log table TTL from 7 to 30 days to match the ClickHouse operator's `systemLogsTTLDays` default (ClickHouse/clickhouse-operator#329). ClickHouse recreates each system table whose TTL changed and keeps the old rows in `system.<table>_0`; drop those once you no longer need them.
