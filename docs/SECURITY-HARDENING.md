# Security Hardening

This chart's defaults are safe for development. For production deployments exposed to untrusted networks (the public internet or any unrestricted peer), apply the practices below.

## HTTP/2 bomb / HPACK amplification (June 2026)

In June 2026 the [Codex disclosure](https://blog.calif.io/p/codex-discovered-a-hidden-http2-bomb) demonstrated a remote DoS that combines HPACK indexed-reference amplification with HTTP/2 flow-control window stalling. A single 100 Mbps client can exhaust tens of GB of memory in seconds against affected HTTP/2-terminating servers.

ClickStack itself does not directly terminate untrusted HTTP/2 — the HyperDX app uses Next.js (HTTP/1.1) and the chart's default Service type is `ClusterIP`. However, if you front the chart with an Ingress controller or expose the OTel collector's OTLP/gRPC receiver (port 4317) publicly, that termination point is in scope.

### Pin Ingress controllers to patched versions

| Controller | Patched version |
|---|---|
| `kubernetes/ingress-nginx` | chart 4.13.0+ (bundles nginx 1.29.8+) |
| Apache `mod_http2` | 2.0.41+ (fixes CVE-2026-49975) |
| `envoyproxy` / Istio gateway | Track upstream advisories. Apply an `EnvoyFilter` capping `http2_protocol_options.max_concurrent_streams: 100` and `stream_idle_timeout: 30s` until a validated upstream patch lands |
| Microsoft IIS / Cloudflare Pingora | No patch at time of writing. Disable HTTP/2 or front with a patched proxy |

### Don't expose OTLP gRPC (port 4317) publicly

OTLP/gRPC is HTTP/2 by definition. The chart wires HyperDX to talk to the collector over the cluster Service (`ClusterIP`), which is the right pattern. If you must expose 4317 to clients outside the cluster:

- Front it with a patched HTTP/2-aware proxy
- Restrict by source IP via NetworkPolicy or your cloud LB
- Prefer the HTTP receiver (port 4318) for untrusted clients

## NetworkPolicy: deny ingress from outside the cluster by default

The chart ships a NetworkPolicy template at `templates/hyperdx/networkpolicy.yaml`. Enable it and provide a deny-by-default spec, e.g.:

```yaml
hyperdx:
  networkPolicy:
    enabled: true
    spec:
      podSelector:
        matchLabels:
          app.kubernetes.io/component: hyperdx
      policyTypes: ["Ingress"]
      ingress:
        # Allow internal pods to reach HyperDX UI/API
        - from:
            - podSelector: {}
          ports:
            - port: 3000  # app
            - port: 8000  # api
        # Allow your ingress controller (adjust selector to your env)
        - from:
            - namespaceSelector:
                matchLabels:
                  kubernetes.io/metadata.name: ingress-nginx
          ports:
            - port: 3000
            - port: 8000
```

For the OTel collector, configure the analogous NetworkPolicy through the sub-chart's values (`otel-collector.networkPolicy`).

## Cap container memory so cgroup OOM bounds any DoS

The default `hyperdx.deployment.resources` is empty. Setting limits ensures that a memory-exhaustion attack (HTTP/2 bomb, slow-loris variants, large-result query) gets OOM-killed and respawned rather than dragging the host into swap. A conservative starting point:

```yaml
hyperdx:
  deployment:
    resources:
      requests:
        cpu: 200m
        memory: 512Mi
      limits:
        cpu: 1000m
        memory: 2Gi
```

Tune to your traffic volume. Lower limits = faster recovery from a bomb attempt; higher limits = better headroom for legitimate spikes.

## Authenticate access to the HyperDX UI

ClickStack does not enforce authentication at the chart level — that's deferred to your ingress / SSO layer. Don't expose the HyperDX UI to the public internet without OAuth/OIDC in front.

## Restrict ClickHouse and MongoDB access

The bundled ClickHouse and MongoDB are reachable from within the cluster by any pod by default. If you run multi-tenant workloads on the same cluster, add NetworkPolicies restricting access to only the HyperDX pods.

## Upgrade cadence

Subscribe to:

- [Envoy security advisories](https://github.com/envoyproxy/envoy/security/advisories)
- [nginx CHANGES](https://nginx.org/en/CHANGES)
- [Apache httpd vulnerabilities](https://httpd.apache.org/security/vulnerabilities_24.html)

Rev your ingress controller chart and the ClickStack chart on a cadence that pulls fixes within days, not months.
