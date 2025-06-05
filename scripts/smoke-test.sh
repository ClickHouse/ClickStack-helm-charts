#!/bin/bash
set -e

# Test script for HyperDX deployment
NAMESPACE=${NAMESPACE:-default}
RELEASE_NAME=${RELEASE_NAME:-hyperdx-test}
TIMEOUT=${TIMEOUT:-300}

echo "Starting HyperDX tests..."
echo "Release: $RELEASE_NAME"
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
kubectl port-forward service/$RELEASE_NAME-hdx-oss-v2-app 3000:3000 -n $NAMESPACE &
pf_pid=$!
sleep 10

wait_for_service "http://localhost:3000" "HyperDX UI"
check_endpoint "http://localhost:3000" "200" "UI"

kill $pf_pid 2>/dev/null || true
sleep 2

# # Skip OTEL collector metrics test (port 8888 not exposed by HyperDX collector)
# echo "Skipping OTEL collector metrics test (not exposed on port 8888)"

# # Test data ingestion
# echo "Testing data ingestion..."
# kubectl port-forward service/$RELEASE_NAME-hdx-oss-v2-otel-collector 4318:4318 -n $NAMESPACE &
# pf_pid=$!
# sleep 10

# # Send test log
# echo "Sending test log..."
# timestamp=$(date +%s)
# curl -X POST http://localhost:4318/v1/logs \
#   -H "Content-Type: application/json" \
#   -d '{
#     "resourceLogs": [{
#       "resource": {
#         "attributes": [
#           {"key": "service.name", "value": {"stringValue": "test-service"}},
#           {"key": "environment", "value": {"stringValue": "test"}}
#         ]
#       },
#       "scopeLogs": [{
#         "scope": {"name": "test-scope"},
#         "logRecords": [{
#           "timeUnixNano": "'${timestamp}'000000000",
#           "severityText": "INFO",
#           "body": {"stringValue": "Test log from deployment check"}
#         }]
#       }]
#     }]
#   }' > /dev/null 2>&1

# echo "Log sent"

# # Send test trace  
# echo "Sending test trace..."
# trace_id=$(openssl rand -hex 16)
# span_id=$(openssl rand -hex 8)
# curl -X POST http://localhost:4318/v1/traces \
#   -H "Content-Type: application/json" \
#   -d '{
#     "resourceSpans": [{
#       "resource": {
#         "attributes": [
#           {"key": "service.name", "value": {"stringValue": "test-service"}}
#         ]
#       },
#       "scopeSpans": [{
#         "scope": {"name": "test-tracer"},
#         "spans": [{
#           "traceId": "'$trace_id'",
#           "spanId": "'$span_id'", 
#           "name": "test-operation",
#           "kind": 1,
#           "startTimeUnixNano": "'${timestamp}'000000000",
#           "endTimeUnixNano": "'$((timestamp + 1))'000000000"
#         }]
#       }]
#     }]
#   }' > /dev/null 2>&1

# echo "Trace sent"

# kill $pf_pid 2>/dev/null || true

# Test databases
echo "Testing ClickHouse..."
if kubectl exec -n $NAMESPACE deployment/$RELEASE_NAME-hdx-oss-v2-clickhouse -- clickhouse-client --query "SELECT 1" >/dev/null 2>&1; then
    echo "ClickHouse: OK"
else
    echo "ERROR: ClickHouse test failed"
    exit 1
fi

echo "Testing MongoDB..."
if kubectl exec -n $NAMESPACE deployment/$RELEASE_NAME-hdx-oss-v2-mongodb -- mongosh --eval "db.adminCommand('ismaster')" --quiet >/dev/null 2>&1; then
    echo "MongoDB: OK"
else
    echo "ERROR: MongoDB test failed"
    exit 1
fi

# # Check if data got ingested
# echo "Waiting for data ingestion..."
# sleep 30

# echo "Checking ingested data..."
# log_count=$(kubectl exec -n $NAMESPACE deployment/$RELEASE_NAME-hdx-oss-v2-clickhouse -- clickhouse-client --query "SELECT count() FROM default.otel_logs WHERE ServiceName = 'test-service'" 2>/dev/null || echo "0")

# echo "Found $log_count test log records"

# if [ "$log_count" -gt "0" ]; then
#     echo "Data ingestion: OK"
# else
#     echo "Data ingestion: No data found (may be normal for quick test)"
# fi

echo ""
echo "Tests completed successfully"
echo "- All components running"
echo "- Endpoints responding"  
# echo "- Data ingestion working"
echo "- Database connections OK"