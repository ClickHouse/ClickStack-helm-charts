---
"helm-charts": patch
---

fix: stop the HyperDX UI sending its own telemetry to the in-cluster collector address, which browsers can't reach (#110, #158). `HDX_EXPORTER_ENABLED` now defaults to on only when `hyperdx.config.NEXT_PUBLIC_OTEL_EXPORTER_OTLP_ENDPOINT` is set to a browser-reachable collector URL. This also turns off the Next.js server's own telemetry by default; set `HDX_EXPORTER_ENABLED: "true"` to keep it.
