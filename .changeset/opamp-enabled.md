---
"helm-charts": minor
---

feat: `clickstack.opamp.enabled` (default `true`) controls whether the OTel collector is managed over OpAMP. Set it to `false` with the HyperDX EE image: EE's OpAMP server only manages ClickStack Cloud collectors, so on the chart the collector crashlooped waiting for config. With `false` the collector runs standalone from its built-in config and the app no longer exposes the OpAMP port. The standalone collector does not check HyperDX ingestion keys, so set `clickstack.secrets.OTLP_AUTH_TOKEN` to require a bearer token on OTLP. Existing installs are unchanged.
