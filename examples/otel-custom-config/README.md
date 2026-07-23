# ClickStack with a custom OTEL Collector configuration

This example shows how to layer a custom OpenTelemetry Collector configuration on top of the built-in ClickStack collector config using `global.otelCollector.customConfig`.

## How it works

When `global.otelCollector.customConfig` is set, the chart:

1. Renders the value into the `clickstack-otel-custom-config` ConfigMap (key `custom.config.yaml`)
2. Mounts it into the collector pod at `/etc/otelcol-contrib/custom/custom.config.yaml` (the mount is pre-wired via `otel-collector.extraVolumes`/`extraVolumeMounts` and marked `optional`, so it is a no-op when unset)
3. Adds `CUSTOM_OTELCOL_CONFIG_FILE=/etc/otelcol-contrib/custom/custom.config.yaml` to the shared `clickstack-config` ConfigMap, which the collector image's entrypoint picks up in both OpAMP supervisor mode (the default) and standalone mode
4. Stamps a `checksum/custom-config` pod annotation so collector pods restart automatically when the config changes

## What's included

The `values.yaml` in this directory:

- Adds a `hostmetrics` receiver and a new `metrics/hostmetrics` pipeline exporting to ClickHouse
- Swaps the built-in `memory_limiter` processor for a percentage-based `memory_limiter/custom` that scales with the pod's memory allocation

## Merge semantics

The custom config is merged **leaf-by-leaf** on top of the collector's built-in configuration by the OTel confmap resolver:

- New receivers/processors/exporters/pipelines are added
- To change a built-in component's settings, prefer defining a **new component under a different name** (e.g. `memory_limiter/custom`) and re-declaring the pipeline `processors:` lists that should use it. Leaf-merging into some built-in components (notably `memory_limiter`) does not behave as expected
- Pipelines you don't re-declare keep their built-in configuration

## Caveats

- The subchart's native `config:`/`alternateConfig:` values are **not** honored by the ClickStack collector image — its entrypoint ignores the chart-generated `relay.yaml`. Always use `global.otelCollector.customConfig`.
- If you override `otel-collector.extraVolumes` or `otel-collector.extraVolumeMounts` yourself, Helm replaces the pre-wired lists entirely — re-include the `custom-config` entries from the chart's default `values.yaml` to keep this feature working.

## Usage

```bash
helm install my-clickstack clickstack/clickstack -f values.yaml
```

Verify the merged config took effect (supervisor mode) by checking the effective config inside the collector pod:

```bash
kubectl exec deploy/my-clickstack-otel-collector -- cat /etc/otel/supervisor-data/effective.yaml
```
