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
kubectl wait --for=condition=Ready pods --all --timeout=600s || true

echo "Pod status:"
kubectl get pods -o wide

echo "Checking MongoDBCommunity CR..."
kubectl get mongodbcommunity -o wide || true

echo "Checking ClickHouseCluster CR..."
kubectl get clickhousecluster -o wide || true

echo "Waiting for all pods to be ready (final check)..."
kubectl wait --for=condition=Ready pods --all --timeout=600s

echo "Final pod status:"
kubectl get pods -o wide
kubectl get services

echo "Running smoke tests..."
chmod +x "$REPO_ROOT/scripts/smoke-test.sh"
TIMEOUT=300 RELEASE_NAME="$RELEASE_NAME" NAMESPACE="$NAMESPACE" "$REPO_ROOT/scripts/smoke-test.sh"
