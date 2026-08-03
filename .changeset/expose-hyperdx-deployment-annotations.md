---
"helm-charts": minor
---

Add explicit `hyperdx.deployment.deploymentAnnotations` and `hyperdx.deployment.podAnnotations` values while preserving `hyperdx.deployment.annotations` as a deprecated pod annotation alias. When both pod annotation values contain the same key, `podAnnotations` takes precedence.
