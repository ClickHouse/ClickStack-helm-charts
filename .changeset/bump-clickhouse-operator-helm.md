---
"helm-charts": minor
---

fix(clickstack-operators): bump clickhouse-operator-helm dependency to `>=0.0.5, <0.1.0`

The operator was pinned to v0.0.2 by a stale `Chart.lock`, not by the `~0.0.2` constraint — under Masterminds semver `~0.0.2` already permits the full `>=0.0.2, <0.1.0` range. Widening the constraint to `>=0.0.5, <0.1.0` and regenerating the lock moves the operator to the latest 0.0.x (currently v0.0.6), which includes the changes introduced in v0.0.5:

- New CRD schema with the `spec.podDisruptionBudget` field on both `ClickHouseCluster` and `KeeperCluster` (lets users override the auto-generated PDB).
- Smart default for `ClickHouseCluster` with `replicas <= 1`: `maxUnavailable=1` instead of `minAvailable=1`, so single-replica deployments no longer deadlock on node drains.
- RBAC additions (e.g. `Jobs` informer) required by the newer controller manager.

Users on `clickstack-operators` v1.0.0 cannot benefit from any of these because the published chart's lock pins the dependency to v0.0.2, and the newer binary cannot run against v0.0.2's RBAC or CRD schema.
