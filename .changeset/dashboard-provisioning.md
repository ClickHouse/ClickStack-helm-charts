---
"helm-charts": minor
---

feat: add dashboard provisioning via a k8s-sidecar that discovers ConfigMaps labeled `hyperdx.io/dashboard: true`. Discovery is scoped to the release namespace by default (a namespaced Role, no cluster-wide access); set `hyperdx.dashboards.namespaces` to also watch specific namespaces, or `hyperdx.dashboards.namespaces: [ALL]` for cluster-wide discovery. Requires hyperdxio/hyperdx#1962 (file-based dashboard provisioner).
