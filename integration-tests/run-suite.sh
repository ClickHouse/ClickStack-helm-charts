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
BASE_ROOT="${UPGRADE_FROM:-$REPO_ROOT}"
BASE_SUITE_DIR="$BASE_ROOT/integration-tests/$SUITE_NAME"
if [ -n "$UPGRADE_FROM" ] && [ ! -f "$BASE_SUITE_DIR/values.yaml" ]; then
    echo "Suite '$SUITE_NAME' does not exist in $BASE_ROOT, nothing to upgrade from"
    exit 0
fi

echo "=== Integration test suite: $SUITE_NAME ==="
echo "Release:        $RELEASE_NAME"
echo "Cluster:        $CLUSTER_NAME"
echo "Operators:      $NEEDS_OPERATORS"
echo "Local storage:  $NEEDS_LOCAL_STORAGE"
echo "Timeout:        ${TIMEOUT}s"
echo "Upgrade from:   ${UPGRADE_FROM:-none}"
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
    if [ "$NEEDS_OPERATORS" = "true" ]; then
        deploy_operators "$REPO_ROOT" upgrade
    fi
    show_upgrade_diff
    # --wait so assert.sh checks the new pods, not old ones that are still Ready.
    deploy_chart "$REPO_ROOT" "$SUITE_DIR" upgrade --wait
fi

run_assert "$REPO_ROOT" "$SUITE_DIR"

echo "=== Suite '$SUITE_NAME' passed ==="
