---
"helm-charts": major
---

Add configurable Service api port, optional HPA, NetworkPolicy, and ServiceAccount templates using an `enabled` + passthrough `spec` pattern. Replace the nginx-centric Ingress template with a passthrough `annotations` + `spec` pattern that supports any ingress controller (nginx, ALB, Traefik, etc.); keep `additionalIngresses` as a power feature. Support `secrets: null` to skip `clickstack-secret` creation for deployments that manage secrets externally.

**Breaking:** The Ingress values schema has changed. The old values (`host`, `path`, `pathType`, `tls.enabled`, `proxyBodySize`, etc.) are replaced by `annotations` and `spec` passthrough fields. Users with `ingress.enabled: true` must update their values. See the updated ALB example and documentation.
