---
"helm-charts": patch
---

Make the `-app` suffix on HyperDX Deployment and Service names conditional on `fullnameOverride`. When `fullnameOverride` is set, the suffix is omitted so users get full control over resource naming. The default behavior (no override) is unchanged.
