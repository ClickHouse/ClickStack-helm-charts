#!/bin/bash
set -e
set -o pipefail

SUITE_NAME="${1:?Usage: run-suite.sh <suite-name>}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SUITE_DIR="$REPO_ROOT/integration-tests/$SUITE_NAME"

if [ ! -f "$SUITE_DIR/suite.yaml" ]; then
    echo "ERROR: Suite directory '$SUITE_DIR' does not contain suite.yaml"
    exit 1
fi

RELEASE_NAME="test-${SUITE_NAME}"
NAMESPACE="default"
CLUSTER_NAME="test-${SUITE_NAME}"

export SUITE_NAME RELEASE_NAME NAMESPACE SUITE_DIR REPO_ROOT

read_config() {
    local key=$1
    local default=$2
    yq -r "${key} // \"${default}\"" "$SUITE_DIR/suite.yaml"
}

NEEDS_OPERATORS=$(read_config '.needs_operators' 'false')
NEEDS_LOCAL_STORAGE=$(read_config '.needs_local_storage' 'false')
TIMEOUT=$(read_config '.timeout' '300')

# Optional checkout of an older ref: install its chart first, then upgrade to this checkout.
UPGRADE_FROM="${UPGRADE_FROM:-}"
# How the upgrade is applied: "helm" runs helm upgrade; "template" pipes helm template into
# kubectl apply, as Argo CD and other GitOps tools do, so the chart's lookup calls see nothing.
UPGRADE_METHOD="${UPGRADE_METHOD:-helm}"
case "$UPGRADE_METHOD" in
    helm|template) ;;
    *) echo "ERROR: UPGRADE_METHOD must be 'helm' or 'template', got '$UPGRADE_METHOD'"; exit 1 ;;
esac
BASE_ROOT="${UPGRADE_FROM:-$REPO_ROOT}"
BASE_SUITE_DIR="$BASE_ROOT/integration-tests/$SUITE_NAME"
if [ -n "$UPGRADE_FROM" ] && [ ! -f "$BASE_SUITE_DIR/values.yaml" ]; then
    echo "Suite '$SUITE_NAME' does not exist in $BASE_ROOT, nothing to upgrade from"
    exit 0
fi
# Database the base release writes ClickStack tables to, recorded before an upgrade. Empty on a
# fresh install. The post-upgrade assert.sh checks that new data still lands there.
export PRE_UPGRADE_DATABASE=""

echo "=== Integration test suite: $SUITE_NAME ==="
echo "Release:        $RELEASE_NAME"
echo "Cluster:        $CLUSTER_NAME"
echo "Operators:      $NEEDS_OPERATORS"
echo "Local storage:  $NEEDS_LOCAL_STORAGE"
echo "Timeout:        ${TIMEOUT}s"
echo "Upgrade from:   ${UPGRADE_FROM:-none}"
if [ -n "$UPGRADE_FROM" ]; then
    echo "Upgrade method: $UPGRADE_METHOD"
fi
echo ""

echo "--- Creating Kind cluster: $CLUSTER_NAME ---"
KIND_CONFIG=""
if [ -f "$SUITE_DIR/kind-config.yaml" ]; then
    KIND_CONFIG="--config $SUITE_DIR/kind-config.yaml"
fi
kind create cluster --name "$CLUSTER_NAME" $KIND_CONFIG --wait 60s
echo ""

if [ "$NEEDS_LOCAL_STORAGE" = "true" ]; then
    echo "--- Installing local-path-provisioner ---"
    kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml
    kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
    echo ""
fi

deploy_operators() {
    local root=$1 verb=$2
    echo "--- helm $verb clickstack-operators from $root ---"
    helm dependency build "$root/charts/clickstack-operators"
    helm "$verb" clickstack-operators "$root/charts/clickstack-operators" --timeout=5m
    echo "Waiting for CRDs..."
    kubectl wait --for=condition=Established crds --all --timeout=60s
    echo "CRDs registered:"
    kubectl get crds | grep -E "clickhouse|mongodb" || true
    echo ""
}

deploy_chart() {
    local root=$1 suite_dir=$2 verb=$3
    shift 3
    echo "--- helm $verb ClickStack chart from $root ---"
    helm dependency build "$root/charts/clickstack"
    helm "$verb" "$RELEASE_NAME" "$root/charts/clickstack" \
        -f "$suite_dir/values.yaml" \
        --timeout="${TIMEOUT}s" "$@"
    echo ""
}

run_assert() {
    local root=$1 suite_dir=$2
    echo "--- Running assert.sh from $suite_dir ---"
    chmod +x "$suite_dir/assert.sh"
    REPO_ROOT="$root" SUITE_DIR="$suite_dir" "$suite_dir/assert.sh"
    echo ""
}

# Show reviewers what the upgrade changes; the upgrade itself is the test, so a diff failure is not fatal.
show_upgrade_diff() {
    if ! helm diff version >/dev/null 2>&1; then
        echo "helm-diff plugin not installed, skipping diff"
        return
    fi
    helm dependency build "$REPO_ROOT/charts/clickstack" >/dev/null
    local out=${GITHUB_STEP_SUMMARY:-/dev/stdout}
    {
        echo "### Upgrade diff: $SUITE_NAME"
        echo '```diff'
        helm diff upgrade "$RELEASE_NAME" "$REPO_ROOT/charts/clickstack" \
            -f "$SUITE_DIR/values.yaml" \
            --normalize-manifests --no-color -C 5 \
            --suppress-output-line-regex='helm.sh/chart:' \
            --suppress-output-line-regex='app.kubernetes.io/version:' \
            || echo "helm diff failed"
        echo '```'
    } >>"$out"
}

# Upgrade the way GitOps tools do: render without cluster access and apply the manifests.
template_upgrade() {
    local selector="app.kubernetes.io/instance=$RELEASE_NAME"
    echo "--- helm template | kubectl apply ClickStack chart from $REPO_ROOT ---"
    helm dependency build "$REPO_ROOT/charts/clickstack"
    helm template "$RELEASE_NAME" "$REPO_ROOT/charts/clickstack" \
        -n "$NAMESPACE" -f "$SUITE_DIR/values.yaml" \
        | kubectl apply -n "$NAMESPACE" --server-side --force-conflicts -f -
    # Pods whose template didn't change keep running with the old config, and .Release.Revision is
    # always 1 here, so the otel-collector doesn't roll. Restart the release's Deployments, as a
    # later image bump or node drain would, so the asserts see what the new config does.
    kubectl rollout restart deployment -n "$NAMESPACE" -l "$selector"
    for deployment in $(kubectl get deployment -n "$NAMESPACE" -l "$selector" -o name); do
        kubectl rollout status "$deployment" -n "$NAMESPACE" --timeout="${TIMEOUT}s"
    done
    echo ""
}

if [ "$NEEDS_OPERATORS" = "true" ]; then
    deploy_operators "$BASE_ROOT" install
fi

if [ -x "$SUITE_DIR/prereq.sh" ]; then
    echo "--- Running prereq.sh ---"
    "$SUITE_DIR/prereq.sh"
    echo ""
fi

deploy_chart "$BASE_ROOT" "$BASE_SUITE_DIR" install

if [ -n "$UPGRADE_FROM" ]; then
    # Prove the old release works before upgrading it, so a failure after the upgrade is the upgrade's fault.
    run_assert "$UPGRADE_FROM" "$BASE_SUITE_DIR"
    PRE_UPGRADE_DATABASE=$(kubectl get configmap clickstack-config -n "$NAMESPACE" \
        -o jsonpath='{.data.HYPERDX_OTEL_EXPORTER_CLICKHOUSE_DATABASE}' 2>/dev/null || true)
    echo "Database before upgrade: ${PRE_UPGRADE_DATABASE:-none}"
    if [ "$NEEDS_OPERATORS" = "true" ]; then
        deploy_operators "$REPO_ROOT" upgrade
    fi
    if [ "$UPGRADE_METHOD" = "template" ]; then
        template_upgrade
    else
        show_upgrade_diff
        # --wait so assert.sh checks the new pods, not old ones that are still Ready.
        deploy_chart "$REPO_ROOT" "$SUITE_DIR" upgrade --wait
    fi
fi

run_assert "$REPO_ROOT" "$SUITE_DIR"

echo "=== Suite '$SUITE_NAME' passed ==="
