---
"helm-charts": minor
---

fix: fail rendering when a 1.x value the chart no longer reads is still set (for example `hyperdx.replicas`, `mongodb.password`, `hyperdx.frontendUrl`, `hyperdx.ingress.tls`, the `otel:` block), listing each key with its replacement. Before, these were ignored and the chart fell back to its defaults, including default database passwords. Values files that still carry any of these keys must drop or move them before upgrading.

fix: `hyperdx.podDisruptionBudget` now defaults to `maxUnavailable: 1` instead of `minAvailable: 1`, which blocked node drains on a single replica. Set `minAvailable` or `maxUnavailable` to override.

docs: the upgrade guide now points `hyperdx.appUrl` and `hyperdx.frontendUrl` at `hyperdx.config.FRONTEND_URL`, and lists the moved ingress and deployment keys.
