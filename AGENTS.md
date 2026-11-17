# AGENTS.md — ClickStack Helm Charts

## Repository Overview

Helm charts for ClickStack (HyperDX observability platform). Two charts:
- `charts/clickstack` — main chart (HyperDX app, ClickHouse, MongoDB, OTEL collector)
- `charts/clickstack-operators` — operator dependencies (MongoDB, ClickHouse operators)

Package manager: Yarn 4 (via Corepack). Versioning: Changesets.

## Local Development

Use the Makefile for tool setup, unit tests, and template coverage:

```bash
make setup        # install helm-unittest, helm-docs, chart deps, and git hooks
make test         # helm-unittest + example values validation
make coverage     # helmcov template coverage
make docs         # regenerate chart READMEs via helm-docs
make integration  # Kind integration suites (SUITES=api-only for one)
make ci           # test + coverage + docs verification
```

The pre-commit hook runs `make test` when staged files under `charts/` change, and
`make docs-check` (fails if the chart READMEs are stale) when `Chart.yaml`, `values.yaml`,
templates, or README templates change. It skips both with a warning if `helm` is not
installed. Install hooks with `make setup` or `make hooks`.

## Build & Dependency Commands

```bash
# Install JS dependencies (for changesets/versioning scripts only)
yarn install

# Build Helm chart dependencies (required before template/test commands)
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
`<component>_test.yaml`.

Shared value fixtures live in `charts/clickstack/tests/values/<case>.yaml` and are
loaded with the suite-level `values:` key when a test needs more data than inline
`set:` overrides comfortably provide:

```yaml
suite: Test Deployment Default Sources Tpl
templates:
  - hyperdx/deployment.yaml
values:
  - values/deployment-tpl-defaults.yaml
tests:
  - it: should render tpl-interpolated default connections
    asserts:
      - matchRegex:
          path: spec.template.spec.containers[0].env[?(@.name=="DEFAULT_CONNECTIONS")].value
          pattern: clickhouse-headless
```

Prefer inline `set:` for small overrides; use `tests/values/` for multi-field
fixtures or tpl-heavy defaults reused across assertions.

### Template Coverage (helmcov)

```bash
make coverage

# Verbose per-file output
VERBOSE=1 make coverage

# Override the line and branch minimums
COVERAGE_THRESHOLD=99 BRANCH_COVERAGE_THRESHOLD=90 make coverage
```

Downloads the helmcov release pinned in `scripts/tool-versions.env` into `.tools/`
and fails below **99% line and 90% branch coverage**. Outputs `coverage.out` (Go
coverprofile) and `coverage.xml` (Cobertura).

CI runs the [helmcov GitHub Action](https://github.com/ClickHouse/helmcov)
via the `helmcov` job in `.github/workflows/helm-test.yaml`, which posts or updates
a pull request comment with line/branch coverage and uncovered details.

### Chart README (helm-docs)

```bash
make docs
```

Regenerates `charts/*/README.md` from `values.yaml` using [helm-docs](https://github.com/norwoodj/helm-docs).
Only values with `# --` comments in `values.yaml` appear in the README (`--ignore-non-descriptions`).
Each chart README includes version and CI build status badges.
The pre-commit hook and CI (`make docs-check`) fail when the READMEs are out of date.

### Integration Tests (Kind cluster)

Suites live under `integration-tests/<suite-name>/`. Each has `suite.yaml`,
`values.yaml`, and `assert.sh`. Run locally with:

```bash
make integration                 # every suite, as CI runs them
make integration SUITES=api-only # one suite
```

Each suite creates a `test-<suite>` Kind cluster and deletes it afterwards. The
full-stack suite also runs `scripts/smoke-test.sh` and the Playwright checks in `scripts/e2e/`.

Requires: `kind`, `helm`, `kubectl`, `yq`. The full-stack suite also needs Node.js and npm
for Playwright.

## Git Conventions

### Branch Naming
- Always prefix with the author's name or handle: `<author>/HDX-3588-otel-autoscaling`, `<author>/fix-rbac-regression`

### Commits
- Conventional commits: `feat:`, `fix:`, `chore:`, `refactor:`, `docs:`, `test:`, `ci:`
- Scope is optional: `fix(ci):`, `feat!:` (breaking)
- Reference Linear ticket when applicable: `fix: make -app suffix conditional on fullnameOverride (HDX-3850)`

### Pull Requests
- Title: conventional-commit style, same as commits: `fix(ci): pin changesets/action to v1`.
  Kodiak uses the PR title as the squash commit subject.
- Include Linear ticket link in description when there is one
- Merge strategy: squash merge (Kodiak auto-merge with `automerge` label)

### Changesets
- Add a changeset for user-facing changes: `yarn changeset`
- Changesets live in `.changeset/` and drive version bumps on release
- If a change needs action on upgrade or restarts pods, add a bullet under `## Unreleased` in
  `docs/UPGRADE.md` (create the heading if the last release consumed it). The release renames it to
  the new version. The Upgrade Notes check fails a `major` changeset without one and warns on `minor`.

## Helm Template Conventions

### Named Templates (`_helpers.tpl`)
- Prefix all template names with `clickstack.`: `clickstack.fullname`, `clickstack.labels`
- Component-specific: `clickstack.hyperdx.fullname`, `clickstack.mongodb.fullname`
- Always use `include` (not `template`) so output can be piped to functions

### Template Files
- Organized by component: `templates/hyperdx/`, `templates/clickhouse/`, `templates/mongodb/`, `templates/otel-collector/`
- Use `nindent` for indentation in template pipelines: `{{- include "clickstack.labels" . | nindent 4 }}`
- Quote string values with `| quote`; use `toYaml` for complex values
- Guard optional sections with `{{- if .Values.x.y }}` blocks
- Use `tpl` for values that may contain template expressions (see `clickstack.hyperdx.configmap` in `_helpers.tpl`)

### Values Structure (`values.yaml`)
- Top-level keys: `global`, `hyperdx`, `mongodb`, `clickhouse`, `additionalManifests`, `otel-collector`
- Document user-facing values with `# --` comments directly above each key (helm-docs format)
- `make docs` omits undocumented keys (`--ignore-non-descriptions`); prefer commenting parent keys for operator/subchart passthrough specs
- `hyperdx.config` — non-sensitive env vars (ConfigMap), supports `tpl` expressions
- `hyperdx.secrets` — sensitive env vars (Secret); set to `null` to skip creation
- `hyperdx.deployment` — Deployment spec (image, replicas, resources, probes, etc.)

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

- Always start with `#!/usr/bin/env bash` and `set -euo pipefail` (see `scripts/helmcov.sh`)
- Use uppercase for exported env vars: `RELEASE_NAME`, `NAMESPACE`, `SUITE_DIR`
- Use functions for reusable logic (see `scripts/smoke-test.sh`, `integration-tests/run-suite.sh`)
- Default variables with `${VAR:-default}` or `${1:?Usage message}`

## CI Workflows

| Workflow | File | Trigger | Purpose |
|----------|------|---------|---------|
| Helm Chart Tests | `helm-test.yaml` | push/PR to main | `helm-unittest` job (unit tests + example validation + docs check), `helmcov` job (template coverage; PR comment with line/branch coverage), and `version-script-smoke` job (changeset version and release-notes scripts) |
| Helm Chart Integration Test | `chart-test.yml` | push/PR/nightly | Kind-based integration suites |
| Release Helm Charts | `release.yml` | after either test workflow succeeds on a push to main | Changeset version + chart release; syncs `pages/` to the gh-pages landing page |
| Upgrade Notes | `upgrade-notes.yml` | PR to main | Requires a `docs/UPGRADE.md` note for `major` changesets; warns on `minor` |
| Lint Workflows | `lint-workflows.yml` | push/PR to main touching workflows | `actionlint` and `zizmor` |
| Deep Code Review | `deep-review.yml` | non-draft PR opened/updated, workflow_dispatch | Multi-agent Claude review posted as a sticky PR comment |
| Alert on external contributions | `external-contributor-alerts.yml` | issue/PR opened | Labels external issues/PRs and posts them to Slack |
| Update App Version | `update-app-version.yml` | workflow_dispatch | Bump `appVersion` in Chart.yaml |
| Bump ClickHouse Image | `bump-clickhouse-image.yml` | weekly/workflow_dispatch | PR moving the ClickHouse server and keeper tags to the newest patch on their LTS line |

## Key File Locations

- Chart definition: `charts/clickstack/Chart.yaml`
- Default values: `charts/clickstack/values.yaml`
- Helper templates: `charts/clickstack/templates/_helpers.tpl`
- Unit tests: `charts/clickstack/tests/*_test.yaml`
- Integration suites: `integration-tests/*/`
- Example values: `examples/*/values.yaml`
- Version sync script: `scripts/update-chart-versions.js`
- Smoke test: `scripts/smoke-test.sh`
- Makefile: `Makefile`
- Pinned tool versions and coverage thresholds: `scripts/tool-versions.env`
- Upgrade guide: `docs/UPGRADE.md`
