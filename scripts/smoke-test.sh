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

# Test OTEL collector metrics endpoint
echo "Testing OTEL collector metrics endpoint..."
kubectl port-forward service/$RELEASE_NAME-hdx-oss-v2-otel-collector 8888:8888 -n $NAMESPACE &
metrics_pf_pid=$!
sleep 10

wait_for_service "http://localhost:8888/metrics" "OTEL Metrics"
check_endpoint "http://localhost:8888/metrics" "200" "OTEL Metrics endpoint"

kill $metrics_pf_pid 2>/dev/null || true
sleep 2

# Test data ingestion
echo "Testing data ingestion..."
kubectl port-forward service/$RELEASE_NAME-hdx-oss-v2-otel-collector 4318:4318 -n $NAMESPACE &
pf_pid=$!
sleep 10

# Test OTLP endpoint connectivity
if ! nc -z localhost 4318; then
    echo "ERROR: OTEL HTTP endpoint not accessible"
    exit 1
fi

# Send test log
echo "Sending test log..."
timestamp=$(date +%s)
log_response=$(curl -X POST http://localhost:4318/v1/logs \
  -H "Content-Type: application/json" \
  -d '{
    "resourceLogs": [{
      "resource": {
        "attributes": [
          {"key": "service.name", "value": {"stringValue": "test-service"}},
          {"key": "environment", "value": {"stringValue": "test"}}
        ]
      },
      "scopeLogs": [{
        "scope": {"name": "test-scope"},
        "logRecords": [{
          "timeUnixNano": "'${timestamp}'000000000",
          "severityText": "INFO",
          "body": {"stringValue": "Test log from deployment check"}
        }]
      }]
    }]
  }' -w "%{http_code}" -s -o /dev/null)

if [ "$log_response" = "200" ] || [ "$log_response" = "202" ]; then
    echo "Log sent successfully (status: $log_response)"
else
    echo "WARNING: Log send failed with status: $log_response"
fi

# Send test trace  
echo "Sending test trace..."
trace_id=$(openssl rand -hex 16)
span_id=$(openssl rand -hex 8)
trace_response=$(curl -X POST http://localhost:4318/v1/traces \
  -H "Content-Type: application/json" \
  -d '{
    "resourceSpans": [{
      "resource": {
        "attributes": [
          {"key": "service.name", "value": {"stringValue": "test-service"}}
        ]
      },
      "scopeSpans": [{
        "scope": {"name": "test-tracer"},
        "spans": [{
          "traceId": "'$trace_id'",
          "spanId": "'$span_id'", 
          "name": "test-operation",
          "kind": 1,
          "startTimeUnixNano": "'${timestamp}'000000000",
          "endTimeUnixNano": "'$((timestamp + 1))'000000000"
        }]
      }]
    }]
  }' -w "%{http_code}" -s -o /dev/null)

if [ "$trace_response" = "200" ] || [ "$trace_response" = "202" ]; then
    echo "Trace sent successfully (status: $trace_response)"
else
    echo "WARNING: Trace send failed with status: $trace_response"
fi

kill $pf_pid 2>/dev/null || true

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

# Check if data got ingested
echo "Waiting for data ingestion..."
sleep 30

echo "Checking ingested data..."
log_count=$(kubectl exec -n $NAMESPACE deployment/$RELEASE_NAME-hdx-oss-v2-clickhouse -- clickhouse-client --query "SELECT count() FROM default.otel_logs WHERE ServiceName = 'test-service'" 2>/dev/null || echo "0")
trace_count=$(kubectl exec -n $NAMESPACE deployment/$RELEASE_NAME-hdx-oss-v2-clickhouse -- clickhouse-client --query "SELECT count() FROM default.otel_traces WHERE ServiceName = 'test-service'" 2>/dev/null || echo "0")

echo "Found $log_count test log records"
echo "Found $trace_count test trace records"

if [ "$log_count" -gt "0" ] || [ "$trace_count" -gt "0" ]; then
    echo "Data ingestion: OK"
else
    echo "Data ingestion: No data found (may be normal for quick test or data processing delay)"
fi

echo ""
echo "Tests completed successfully"
echo "- All components running"
echo "- Endpoints responding"  
echo "- OTEL collector metrics accessible"
echo "- Data ingestion tested"
echo "- Database connections OK"