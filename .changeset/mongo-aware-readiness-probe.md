---
"helm-charts": minor
---

Point the HyperDX readiness probe at the new Mongo-aware `/ready` endpoint and make both probe paths configurable.

`/ready` (added in HyperDX 2.36.0, see hyperdxio/hyperdx#2968) returns 503 until the API's MongoDB connection is established, so pods that cannot serve Mongo-backed requests are removed from Service endpoints instead of staying Ready indefinitely (hyperdxio/hyperdx#2966). The liveness probe stays on `/health`, which remains a pure process-liveness check.

New values: `hyperdx.deployment.livenessProbe.path` (default `/health`) and `hyperdx.deployment.readinessProbe.path` (default `/ready`). If you pin `hyperdx.deployment.image.tag` to a version older than 2.36.0, set `readinessProbe.path: /health` — those images do not serve `/ready`.
