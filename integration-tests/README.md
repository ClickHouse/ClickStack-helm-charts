# Integration tests

This directory contains Kind-based integration test suites for the ClickStack Helm chart. Each suite is a directory with a standard set of files. A shared harness script handles cluster lifecycle, dependency installation, and chart deployment.

## How it works

The CI workflow (`.github/workflows/chart-test.yml`) auto-discovers suites by scanning for `integration-tests/*/suite.yaml`. Each discovered suite runs as a parallel matrix job on its own GitHub Actions runner with its own Kind cluster.

```
discover job                    integration-test matrix
┌─────────────┐     ┌──────────────────────────────────┐
│ scan for     │────▶│ full-stack   (parallel runner)   │
│ suite.yaml   │     │ api-only     (parallel runner)   │
│ → JSON array │     │ your-suite   (parallel runner)   │
└─────────────┘     └──────────────────────────────────┘
```

## Adding a new test suite

1. Create a directory under `integration-tests/`:

```
integration-tests/
  my-new-suite/
    suite.yaml       # required -- declares what the suite needs
    values.yaml      # required -- Helm values for the chart install
    assert.sh        # required -- verification script (exit 0 = pass)
    prereq.sh        # optional -- runs before helm install
    kind-config.yaml # optional -- custom Kind cluster config
```

2. Define `suite.yaml`:

```yaml
needs_operators: false      # install clickstack-operators + wait for CRDs
needs_local_storage: false  # install local-path-provisioner as default StorageClass
needs_nodejs: false         # set up Node.js (for Playwright or other JS-based tests)
timeout: 300                # helm install --timeout in seconds
```

All flags default to `false` and timeout defaults to `300` if omitted.

3. Create `values.yaml` with the Helm values for your test scenario.

4. Create `assert.sh` with your verification logic. The script receives these environment variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `SUITE_NAME` | Directory name | `my-new-suite` |
| `RELEASE_NAME` | Helm release name | `test-my-new-suite` |
| `NAMESPACE` | Kubernetes namespace | `default` |
| `SUITE_DIR` | Absolute path to suite directory | `/path/to/integration-tests/my-new-suite` |
| `REPO_ROOT` | Absolute path to repo root | `/path/to/ClickStack-helm-charts` |

The script should `exit 0` on success, `exit 1` on failure.

5. Optionally create `prereq.sh` for setup that must happen before `helm install` (e.g., deploying a standalone database, creating secrets, applying CRDs). It receives the same environment variables.

6. Optionally create `kind-config.yaml` for a custom Kind cluster configuration (e.g., extra port mappings for NodePort services).

That's it. The CI workflow discovers your new directory automatically on the next PR.

## Execution order

For each suite, the harness (`run-suite.sh`) runs these steps in order:

1. Read `suite.yaml`
2. Create Kind cluster (uses `kind-config.yaml` if present)
3. Install local-path-provisioner (if `needs_local_storage: true`)
4. Build Helm chart dependencies
5. Install clickstack-operators (if `needs_operators: true`)
6. Run `prereq.sh` (if present and executable)
7. `helm install` with `values.yaml` and configured timeout
8. Run `assert.sh`

On failure, the CI workflow collects pod status, events, logs, and resource descriptions for debugging.

## Existing suites

### `full-stack`

Deploys the complete ClickStack platform with all subcharts (MongoDB, ClickHouse, OTEL collector). Runs the comprehensive smoke test (`scripts/smoke-test.sh`) which verifies OTEL ingestion into ClickHouse and runs Playwright e2e tests (user registration + log search).

### `api-only`

Deploys with all subcharts disabled and `secrets: null`. Uses a standalone MongoDB pod for session storage. Verifies all new chart features: Service api port, HPA, NetworkPolicy, ServiceAccount, passthrough Ingress, and the absence of `clickstack-secret`.

## Running locally

You can run a suite locally if you have `kind`, `helm`, `kubectl`, and `yq` installed:

```bash
# From the repo root
./integration-tests/run-suite.sh api-only

# Clean up
helm uninstall test-api-only || true
kind delete cluster --name test-api-only || true
```

## Unit tests

Helm unit tests (`helm unittest`) run in a separate workflow (`Helm Chart Tests` in `.github/workflows/helm-test.yaml`). They do not require a cluster and validate template rendering logic. See `charts/clickstack/tests/` for the test files.
