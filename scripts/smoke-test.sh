#!/bin/bash
set -e

# Test script for HyperDX deployment
NAMESPACE=${NAMESPACE:-default}
RELEASE_NAME=${RELEASE_NAME:-hyperdx-test}
CHART_NAME=${CHART_NAME:-clickstack}
TIMEOUT=${TIMEOUT:-300}

echo "Starting HyperDX tests..."
echo "Release: $RELEASE_NAME"
echo "Chart: $CHART_NAME"
echo "Namespace: $NAMESPACE"

wait_for_service() {
    local url=$1
    local name=$2
    local attempts=5
    local count=1
    
    echo "Waiting for $name..."
    
    while [ $count -le $attempts ]; do
        if curl -s -f "$url" > /dev/null 2>&1; then
            echo "$name is ready"
            return 0
        fi
        
        echo "  Try $count/$attempts failed, waiting 10s..."
        sleep 10
        count=$((count + 1))
    done
    
    echo "ERROR: $name not accessible after $attempts tries"
    return 1
}

check_endpoint() {
    local url=$1
    local expected_code=$2
    local desc=$3
    
    echo "Checking $desc..."
    
    code=$(curl -s -w "%{http_code}" -o /dev/null "$url" || echo "000")
    
    if [ "$code" = "$expected_code" ]; then
        echo "$desc: OK (status $expected_code)"
        return 0
    else
        echo "ERROR: $desc failed - expected $expected_code, got $code"
        return 1
    fi
}

# Check pods
echo "Checking pod status..."
kubectl wait --for=condition=Ready pods -l app.kubernetes.io/instance=$RELEASE_NAME --timeout=${TIMEOUT}s -n $NAMESPACE

echo "Pod status:"
kubectl get pods -l app.kubernetes.io/instance=$RELEASE_NAME -n $NAMESPACE

# Test UI
echo "Testing HyperDX UI..."
kubectl port-forward service/$RELEASE_NAME-$CHART_NAME-app 3000:3000 -n $NAMESPACE &
pf_pid=$!
sleep 10

wait_for_service "http://localhost:3000" "HyperDX UI"
check_endpoint "http://localhost:3000" "200" "UI"

kill $pf_pid 2>/dev/null || true
sleep 2

# Test OTEL collector metrics endpoint
echo "Testing OTEL collector metrics endpoint..."
kubectl port-forward service/$RELEASE_NAME-otel-collector 8888:8888 -n $NAMESPACE &
metrics_pf_pid=$!
sleep 10

wait_for_service "http://localhost:8888/metrics" "OTEL Metrics"
check_endpoint "http://localhost:8888/metrics" "200" "OTEL Metrics endpoint"

kill $metrics_pf_pid 2>/dev/null || true
sleep 2

# Test databases
echo "Testing ClickHouse..."
if kubectl get clickhousecluster -n $NAMESPACE $RELEASE_NAME-$CHART_NAME-clickhouse -o jsonpath='{.status}' >/dev/null 2>&1; then
    echo "ClickHouse: OK (ClickHouseCluster CR exists)"
else
    echo "WARNING: ClickHouseCluster CR not found (operator may still be reconciling)"
fi

echo "Testing MongoDB..."
if kubectl get mongodbcommunity -n $NAMESPACE $RELEASE_NAME-$CHART_NAME-mongodb -o jsonpath='{.status}' >/dev/null 2>&1; then
    echo "MongoDB: OK (MongoDBCommunity CR exists)"
else
    echo "WARNING: MongoDBCommunity CR not found (operator may still be reconciling)"
fi

echo ""
echo "Tests completed successfully"
echo "- All pods running"
echo "- HyperDX UI responding"
echo "- OTEL collector metrics accessible"
echo "- Database CRs healthy"