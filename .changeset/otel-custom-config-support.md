---
"helm-charts": minor
---

feat: restore inline custom OTEL collector config support (HDX-4879)

Adds `global.otelCollector.customConfig` to the clickstack chart, restoring
the `otel.customConfig` capability that was lost in the v3 migration to the
official OpenTelemetry Collector subchart. When set, the config is rendered
into the `clickstack-otel-custom-config` ConfigMap, mounted at
`/etc/otelcol-contrib/custom/custom.config.yaml`, and exposed to the
collector via the `CUSTOM_OTELCOL_CONFIG_FILE` environment variable so it is
merged on top of the built-in configuration in both OpAMP supervisor and
standalone mode. Collector pods restart automatically when the config
changes via a `checksum/custom-config` pod annotation.
