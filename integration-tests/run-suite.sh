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

echo "=== Integration test suite: $SUITE_NAME ==="
echo "Release:        $RELEASE_NAME"
echo "Cluster:        $CLUSTER_NAME"
echo "Operators:      $NEEDS_OPERATORS"
echo "Local storage:  $NEEDS_LOCAL_STORAGE"
echo "Timeout:        ${TIMEOUT}s"
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

echo "--- Building chart dependencies ---"
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts 2>/dev/null || true
if [ "$NEEDS_OPERATORS" = "true" ]; then
    helm repo add mongodb https://mongodb.github.io/helm-charts 2>/dev/null || true
    helm dependency build "$REPO_ROOT/charts/clickstack-operators"
fi
helm dependency build "$REPO_ROOT/charts/clickstack"
echo ""

if [ "$NEEDS_OPERATORS" = "true" ]; then
    echo "--- Installing clickstack-operators ---"
    helm install clickstack-operators "$REPO_ROOT/charts/clickstack-operators" --timeout=5m
    echo "Waiting for CRDs..."
    kubectl wait --for=condition=Established crds --all --timeout=60s
    echo "CRDs registered:"
    kubectl get crds | grep -E "clickhouse|mongodb" || true
    echo ""
fi

if [ -x "$SUITE_DIR/prereq.sh" ]; then
    echo "--- Running prereq.sh ---"
    "$SUITE_DIR/prereq.sh"
    echo ""
fi

echo "--- Installing ClickStack chart ---"
helm install "$RELEASE_NAME" "$REPO_ROOT/charts/clickstack" \
    -f "$SUITE_DIR/values.yaml" \
    --timeout="${TIMEOUT}s"
echo ""

echo "--- Running assert.sh ---"
if [ ! -x "$SUITE_DIR/assert.sh" ]; then
    chmod +x "$SUITE_DIR/assert.sh"
fi
"$SUITE_DIR/assert.sh"

echo ""
echo "=== Suite '$SUITE_NAME' passed ==="
