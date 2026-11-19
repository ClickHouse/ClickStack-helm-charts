---
"helm-charts": minor
---

feat: add `hyperdx.dashboards.includeReleaseNamespace` (default `true`, unchanged behaviour). Set it to `false` with `hyperdx.dashboards.namespaces: [<ns>]` to confine the dashboard watcher, and its ConfigMap read access, to the listed namespaces: the chart then renders a namespaced Role and RoleBinding in each listed namespace, no ClusterRole, and nothing in the release namespace. Those objects are named `<fullname>-<release namespace>-dashboard-provisioner-scoped`, distinct from the RoleBindings the cross-namespace mode renders, so the flag can be flipped either way on an existing install: no upgrade has to change an existing RoleBinding's `roleRef`. The render fails if it is `false` with no namespaces listed, or with inline `configMaps` while the release namespace is not watched.
