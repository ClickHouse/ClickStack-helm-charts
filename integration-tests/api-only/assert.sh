#!/bin/bash
set -e
set -o pipefail

DEPLOYMENT_NAME="hyperdx-api"
TIMEOUT=${TIMEOUT:-300}

PASS=0
FAIL=0

PORT_FORWARD_PID=""
PORT_FORWARD_LOG=""

cleanup() {
    if [ -n "$PORT_FORWARD_PID" ] && kill -0 "$PORT_FORWARD_PID" 2>/dev/null; then
        kill "$PORT_FORWARD_PID" 2>/dev/null || true
        wait "$PORT_FORWARD_PID" 2>/dev/null || true
    fi
    if [ -n "$PORT_FORWARD_LOG" ]; then
        rm -f "$PORT_FORWARD_LOG" 2>/dev/null || true
    fi
}

trap cleanup EXIT

assert_pass() {
    local desc=$1
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
}

assert_fail() {
    local desc=$1
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
}

echo "=== API-only deployment verification ==="
echo "Namespace: $NAMESPACE"
echo "Release: $RELEASE_NAME"
echo ""

echo "--- Deployment ---"
if kubectl wait --for=condition=Available "deployment/$DEPLOYMENT_NAME" -n "$NAMESPACE" --timeout="${TIMEOUT}s" > /dev/null 2>&1; then
    assert_pass "Deployment $DEPLOYMENT_NAME is Available"
else
    assert_fail "Deployment $DEPLOYMENT_NAME is not Available"
fi

echo "--- Service ---"
SVC_PORTS=$(kubectl get svc "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.ports[*].name}' 2>/dev/null || echo "")
if echo "$SVC_PORTS" | grep -q "app"; then
    assert_pass "Service has app port"
else
    assert_fail "Service missing app port (got: $SVC_PORTS)"
fi
if echo "$SVC_PORTS" | grep -q "api"; then
    assert_pass "Service has api port"
else
    assert_fail "Service missing api port (got: $SVC_PORTS)"
fi
if echo "$SVC_PORTS" | grep -q "opamp"; then
    assert_pass "Service has opamp port"
else
    assert_fail "Service missing opamp port (got: $SVC_PORTS)"
fi

API_PORT=$(kubectl get svc "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.ports[?(@.name=="api")].port}' 2>/dev/null || echo "")
if [ "$API_PORT" = "8000" ]; then
    assert_pass "Service api port is 8000"
else
    assert_fail "Service api port expected 8000, got $API_PORT"
fi

echo "--- HorizontalPodAutoscaler ---"
if kubectl get hpa "$DEPLOYMENT_NAME" -n "$NAMESPACE" > /dev/null 2>&1; then
    assert_pass "HPA $DEPLOYMENT_NAME exists"
    HPA_TARGET=$(kubectl get hpa "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.scaleTargetRef.name}' 2>/dev/null || echo "")
    if [ "$HPA_TARGET" = "$DEPLOYMENT_NAME" ]; then
        assert_pass "HPA scaleTargetRef targets $DEPLOYMENT_NAME"
    else
        assert_fail "HPA scaleTargetRef expected $DEPLOYMENT_NAME, got $HPA_TARGET"
    fi
else
    assert_fail "HPA $DEPLOYMENT_NAME does not exist"
fi

echo "--- NetworkPolicy ---"
if kubectl get networkpolicy "${DEPLOYMENT_NAME}-network-policy" -n "$NAMESPACE" > /dev/null 2>&1; then
    assert_pass "NetworkPolicy ${DEPLOYMENT_NAME}-network-policy exists"
else
    assert_fail "NetworkPolicy ${DEPLOYMENT_NAME}-network-policy does not exist"
fi

echo "--- ServiceAccount ---"
if kubectl get sa "$DEPLOYMENT_NAME" -n "$NAMESPACE" > /dev/null 2>&1; then
    assert_pass "ServiceAccount $DEPLOYMENT_NAME exists"
    SA_ANNOTATION=$(kubectl get sa "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{.metadata.annotations.ci-test/purpose}' 2>/dev/null || echo "")
    if [ "$SA_ANNOTATION" = "integration-test" ]; then
        assert_pass "ServiceAccount has ci-test/purpose annotation"
    else
        assert_fail "ServiceAccount annotation ci-test/purpose expected 'integration-test', got '$SA_ANNOTATION'"
    fi
else
    assert_fail "ServiceAccount $DEPLOYMENT_NAME does not exist"
fi

DEPLOY_SA=$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.serviceAccountName}' 2>/dev/null || echo "")
if [ "$DEPLOY_SA" = "$DEPLOYMENT_NAME" ]; then
    assert_pass "Deployment references ServiceAccount $DEPLOYMENT_NAME"
else
    assert_fail "Deployment serviceAccountName expected $DEPLOYMENT_NAME, got '$DEPLOY_SA'"
fi

echo "--- Ingress ---"
if kubectl get ingress "${DEPLOYMENT_NAME}-ingress" -n "$NAMESPACE" > /dev/null 2>&1; then
    assert_pass "Ingress ${DEPLOYMENT_NAME}-ingress exists"
else
    assert_fail "Ingress ${DEPLOYMENT_NAME}-ingress does not exist"
fi

echo "--- Secret (should NOT exist) ---"
if kubectl get secret clickstack-secret -n "$NAMESPACE" > /dev/null 2>&1; then
    assert_fail "clickstack-secret exists (should not exist when secrets is null)"
else
    assert_pass "clickstack-secret does not exist (secrets: null)"
fi

echo "--- Health check ---"
PORT_FORWARD_LOG=$(mktemp "/tmp/pf-health.XXXXXX.log")
kubectl port-forward "svc/$DEPLOYMENT_NAME" 18000:8000 -n "$NAMESPACE" > "$PORT_FORWARD_LOG" 2>&1 &
PORT_FORWARD_PID=$!
sleep 5

if kill -0 "$PORT_FORWARD_PID" 2>/dev/null; then
    HEALTH_CODE=$(curl -s -w "%{http_code}" -o /dev/null --max-time 10 "http://localhost:18000/health" 2>/dev/null || echo "000")
    if [ "$HEALTH_CODE" = "200" ]; then
        assert_pass "Health endpoint /health returned 200"
    else
        assert_fail "Health endpoint /health expected 200, got $HEALTH_CODE"
    fi
else
    assert_fail "Port-forward to svc/$DEPLOYMENT_NAME:8000 failed to start"
fi

echo ""
echo "=== Results ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo ""

if [ "$FAIL" -gt 0 ]; then
    echo "VERIFICATION FAILED"
    exit 1
fi

echo "All checks passed"
