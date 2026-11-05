---
"helm-charts": minor
---

Automatically roll HyperDX pods when the chart-managed ConfigMap or Secret content changes. The first upgrade containing this change adds checksum annotations and triggers a one-time HyperDX rollout.
