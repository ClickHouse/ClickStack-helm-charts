---
"helm-charts": patch
---

chore(deps): bump clickhouse-operator-helm to v0.0.7

Also bumps the clickstack-operators chart to 1.1.0 so the updated
dependency is published. Operator v0.0.7 no longer drops a non-empty
Atomic `default` database during Replicated conversion
(clickhouse-operator#255), which is why the earlier
`enableDatabaseSync: false` workaround is not needed.
