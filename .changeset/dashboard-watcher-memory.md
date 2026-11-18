---
"helm-charts": patch
---

fix: raise the dashboard watcher's default memory to a 128Mi limit and a 64Mi request (were 64Mi and 32Mi). At 64Mi the `kiwigrid/k8s-sidecar` watcher was OOMKilled about once a minute even with only a few small dashboards, so its initial sync never finished and the pod never became Ready; at 128Mi its working set stayed near 72Mi with a 95Mi peak and it did not restart. Override `hyperdx.dashboards.resources` to keep the old values.
