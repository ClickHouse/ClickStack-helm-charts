# Helm Chart Tests for ClickStack

This directory contains unit tests for the ClickStack Helm chart using the [helm-unittest](https://github.com/quintush/helm-unittest) plugin.

## Prerequisites

1. Helm v3
2. Helm-unittest plugin

## Installing the Helm-unittest Plugin

```bash
helm plugin install https://github.com/quintush/helm-unittest
```

## Running Tests

To run all tests:

```bash
# From the root of the chart
helm unittest charts/clickstack
```

To run a specific test suite:

```bash
helm unittest -f tests/app-deployment_test.yaml charts/clickstack
```

## Test Files

- `app-deployment_test.yaml`: Tests for the HyperDX application deployment
- `clickhouse-deployment_test.yaml`: Tests for the ClickHouse deployment
- `configmap_test.yaml`: Tests for the application ConfigMap
- `ingress_test.yaml`: Tests for the Ingress resources
- `mongodb-deployment_test.yaml`: Tests for the MongoDB deployment
- `otel-collector_test.yaml`: Tests for the OTEL collector deployment
- `pvc_test.yaml`: Tests for the Persistent Volume Claims

## Writing New Tests

Tests are written in YAML format and include:
- `suite`: The name of the test suite
- `templates`: List of templates to test
- `tests`: List of test cases, each with:
  - `it`: Description of the test
  - `set`: Values to set for the test
  - `asserts`: List of assertions to check

For more information, see the [helm-unittest documentation](https://github.com/quintush/helm-unittest/blob/master/DOCUMENT.md).
