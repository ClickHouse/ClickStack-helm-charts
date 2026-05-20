---
"helm-charts": minor
---

Expose hyperdx.deployment.initContainers, volumes, and volumeMounts passthrough fields for injecting additional init containers, pod-level volumes, and container-level volume mounts into the HyperDX Deployment. Defaults are empty lists, so existing values files render unchanged.
