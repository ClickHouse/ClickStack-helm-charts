# AGENTS.md — ClickStack Helm Charts

## Repository Overview

Helm charts for ClickStack (HyperDX observability platform). Two charts:
- `charts/clickstack` — main chart (HyperDX app, ClickHouse, MongoDB, OTEL collector)
- `charts/clickstack-operators` — operator dependencies (MongoDB, ClickHouse operators)

Package manager: Yarn 4 (via Corepack). Versioning: Changesets.

## Local Development

Use the Makefile for tool setup, unit tests, and template coverage:

```bash
make setup      # install helm-unittest, chart deps, and git hooks
make test       # helm-unittest + example values validation
make coverage   # helmcov template coverage via Docker (requires Docker)
make ci         # test + coverage
```

The pre-commit hook runs `make test` when staged files under `charts/` change, and
`make docs` when chart values, templates, or README templates change. Install hooks
with `make setup` or `make hooks`.

## Build & Dependency Commands

```bash
# Install JS dependencies (for changesets/versioning scripts only)
yarn install

# Build Helm chart dependencies (required before template/test commands)
helm repo add mongodb https://mongodb.github.io/helm-charts
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm dependency build charts/clickstack
```

## Lint & Validate

```bash
# Validate templates render without errors
helm template clickstack-test charts/clickstack

# Validate with specific values file
helm template clickstack-test charts/clickstack -f examples/alb-ingress/values.yaml
helm template clickstack-test charts/clickstack -f examples/api-only/values.yaml
```

## Testing

### Unit Tests (helm-unittest)

```bash
make test

# Run a SINGLE test file
helm unittest -f tests/app-deployment_test.yaml charts/clickstack

# Run tests matching a pattern
helm unittest -f 'tests/clickhouse-*_test.yaml' charts/clickstack
```

Test files live in `charts/clickstack/tests/` and follow the naming convention
`<component>_test.yaml`. Snapshots are stored in `tests/__snapshot__/`.

### Template Coverage (helmcov)

```bash
make coverage

# Verbose per-file output
VERBOSE=1 make coverage

# Gate on minimum line coverage once baseline is known
COVERAGE_THRESHOLD=25 make coverage

# Pin a different image
HELMCOV_IMAGE=ghcr.io/jordan-simonovski/helmcov:v0.3.2 make coverage
```

Uses `ghcr.io/jordan-simonovski/helmcov:v0.3.2` by default with a **25% line
coverage threshold**. Outputs `coverage.out` (Go coverprofile) and `coverage.xml`
(Cobertura). CI runs `make coverage` via `.github/workflows/helmcov.yaml`.

### Chart README (helm-docs)

```bash
make docs
```

Regenerates `charts/*/README.md` from `values.yaml` using [helm-docs](https://github.com/norwoodj/helm-docs).
Only values with `#` comments in `values.yaml` appear in the README (`--ignore-non-descriptions`).
Each chart README includes version and CI build status badges.
The pre-commit hook verifies docs are up to date when values or templates change.

### Integration Tests (Kind cluster)

Suites live under `integration-tests/<suite-name>/`. Each has `suite.yaml`,
`values.yaml`, and `assert.sh`. Run locally with:

```bash
./integration-tests/run-suite.sh api-only    # or full-stack
# Cleanup
helm uninstall test-api-only || true
kind delete cluster --name test-api-only || true
```

Requires: `kind`, `helm`, `kubectl`, `yq`.

## Git Conventions

### Branch Naming
- Always prefix with `warren/`: `warren/HDX-3588-otel-autoscaling`, `warren/fix-rbac-regression`

### Commits
- Conventional commits: `feat:`, `fix:`, `chore:`, `refactor:`, `docs:`, `test:`, `ci:`
- Scope is optional: `fix(ci):`, `feat!:` (breaking)
- Reference Linear ticket when applicable: `fix: make -app suffix conditional on fullnameOverride (HDX-3850)`

### Pull Requests
- Title: `[HDX-<ticket>] <description>`
- Include Linear ticket link in description
- Merge strategy: squash merge (Kodiak auto-merge with `automerge` label)

### Changesets
- Add a changeset for user-facing changes: `npx changeset`
- Changesets live in `.changeset/` and drive version bumps on release

## Helm Template Conventions

### Named Templates (`_helpers.tpl`)
- Prefix all template names with `clickstack.`: `clickstack.fullname`, `clickstack.labels`
- Component-specific: `clickstack.hyperdx.fullname`, `clickstack.mongodb.fullname`
- Always use `include` (not `template`) so output can be piped to functions

### Template Files
- Organized by component: `templates/hyperdx/`, `templates/clickhouse/`, `templates/mongodb/`
- Use `nindent` for indentation in template pipelines: `{{- include "clickstack.labels" . | nindent 4 }}`
- Quote string values with `| quote`; use `toYaml` for complex values
- Guard optional sections with `{{- if .Values.x.y }}` blocks
- Use `tpl` for values that may contain template expressions (see configmap.yaml)

### Values Structure (`values.yaml`)
- Top-level keys: `global`, `hyperdx`, `clickhouse`, `mongodb`, `otel-collector`
- Document user-facing values with `# --` comments directly above each key (helm-docs format)
- `make docs` omits undocumented keys (`--ignore-non-descriptions`); prefer commenting parent keys for operator/subchart passthrough specs
- `hyperdx.config` — non-sensitive env vars (ConfigMap), supports `tpl` expressions
- `hyperdx.secrets` — sensitive env vars (Secret); set to `null` to skip creation
- `hyperdx.deployment` — Deployment spec (image, replicas, resources, probes, etc.)
- Document all values with inline YAML comments

### Labels
- Always include common labels via `{{- include "clickstack.labels" . | nindent 4 }}`
- Always include selector labels via `{{- include "clickstack.selectorLabels" . | nindent 6 }}`

## Unit Test Style

Test files use YAML format with helm-unittest conventions:

```yaml
suite: Test <Component Name>
templates:
  - <component>/<template>.yaml
tests:
  - it: should <describe expected behavior>
    set:
      <values to override>
    asserts:
      - isKind:
          of: <Kind>
      - equal:
          path: <jsonpath>
          value: <expected>
```

- One test file per template (or logical group)
- Use `hasDocuments: count: 0` to assert a template produces no output
- Use `matchRegex` for dynamic names (e.g., `pattern: -app$`)
- Use `contains` for list items (ports, env vars, etc.)
- Test both default values and overridden values
- Test conditional rendering (enabled/disabled features)

## Shell Script Conventions

- Always start with `#!/bin/bash`, `set -e`, and `set -o pipefail`
- Use uppercase for exported env vars: `RELEASE_NAME`, `NAMESPACE`, `SUITE_DIR`
- Use functions for reusable logic (see `smoke-test.sh`, `run-suite.sh`)
- Default variables with `${VAR:-default}` or `${1:?Usage message}`

## CI Workflows

| Workflow | File | Trigger | Purpose |
|----------|------|---------|---------|
| Helm Chart Tests | `helm-test.yaml` | push/PR to main | Unit tests + example validation |
| Helm Template Coverage | `helmcov.yaml` | push/PR to main | helmcov template line/branch coverage |
| Integration Test | `chart-test.yml` | push/PR/nightly | Kind-based integration suites |
| Release | `release.yml` | after tests pass on main | Changeset version + chart release |
| Update App Version | `update-app-version.yml` | workflow_dispatch | Bump `appVersion` in Chart.yaml |

## Key File Locations

- Chart definition: `charts/clickstack/Chart.yaml`
- Default values: `charts/clickstack/values.yaml`
- Helper templates: `charts/clickstack/templates/_helpers.tpl`
- Unit tests: `charts/clickstack/tests/*_test.yaml`
- Integration suites: `integration-tests/*/`
- Example values: `examples/*/values.yaml`
- Version sync script: `scripts/update-chart-versions.js`
- Smoke test: `scripts/smoke-test.sh`
- Makefile: `make setup`, `make test`, `make coverage`
