#!/bin/bash
set -e
set -o pipefail

echo "Waiting for ClickHouseCluster to be ready..."
kubectl wait --for=condition=Ready clickhousecluster --all --timeout=300s

echo "Waiting for MongoDBCommunity to reach Running phase..."
kubectl wait --for=jsonpath='{.status.phase}'=Running mongodbcommunity --all --timeout=300s

echo "Waiting for services to initialize..."
sleep 30

echo "Waiting for all pods to be ready..."
kubectl wait --for=condition=Ready pods --all --field-selector=status.phase!=Succeeded --timeout=600s || true

echo "Pod status:"
kubectl get pods -o wide

echo "Checking MongoDBCommunity CR..."
kubectl get mongodbcommunity -o wide || true

echo "Checking ClickHouseCluster CR..."
kubectl get clickhousecluster -o wide || true

echo "Waiting for all pods to be ready (final check)..."
kubectl wait --for=condition=Ready pods --all --field-selector=status.phase!=Succeeded --timeout=600s

echo "Final pod status:"
kubectl get pods -o wide
kubectl get services

if [ -n "${PRE_UPGRADE_DATABASE:-}" ]; then
    # An upgrade must keep writing to the base release's database, whatever the new ConfigMap says:
    # a render without cluster access sets the new default and relies on the collector's fallback.
    echo "Upgraded from a release writing to '$PRE_UPGRADE_DATABASE'; checking new data still lands there"
    export CLICKHOUSE_DATABASE="$PRE_UPGRADE_DATABASE"
else
    # A fresh install with the bundled ClickHouse seeds a Replicated database.
    export CLICKHOUSE_EXPECT_REPLICATED=true
fi

echo "Running smoke tests..."
chmod +x "$REPO_ROOT/scripts/smoke-test.sh"
TIMEOUT=300 RELEASE_NAME="$RELEASE_NAME" NAMESPACE="$NAMESPACE" "$REPO_ROOT/scripts/smoke-test.sh"
