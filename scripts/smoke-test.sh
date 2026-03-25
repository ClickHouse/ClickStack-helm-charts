#!/bin/bash
set -e
set -o pipefail

# Test script for HyperDX deployment
NAMESPACE=${NAMESPACE:-default}
RELEASE_NAME=${RELEASE_NAME:-hyperdx-test}
CHART_NAME=${CHART_NAME:-clickstack}
TIMEOUT=${TIMEOUT:-300}
CLICKHOUSE_SERVICE=${CLICKHOUSE_SERVICE:-$RELEASE_NAME-$CHART_NAME-clickhouse-clickhouse-headless}
CLICKHOUSE_SECRET_NAME=${CLICKHOUSE_SECRET_NAME:-clickstack-secret}
CLICKHOUSE_HTTP_USER=${CLICKHOUSE_HTTP_USER:-app}
CLICKHOUSE_DATABASE=${CLICKHOUSE_DATABASE:-default}
CLICKHOUSE_TRACE_TABLE=${CLICKHOUSE_TRACE_TABLE:-otel_traces}
CLICKHOUSE_LOG_TABLE=${CLICKHOUSE_LOG_TABLE:-otel_logs}
INGESTION_POLL_INTERVAL=${INGESTION_POLL_INTERVAL:-5}

PORT_FORWARD_PIDS=()
PORT_FORWARD_LOGS=()
CLICKHOUSE_HTTP_PASSWORD=""

echo "Starting HyperDX tests..."
echo "Release: $RELEASE_NAME"
echo "Chart: $CHART_NAME"
echo "Namespace: $NAMESPACE"

cleanup_port_forwards() {
    local pid=""
    local log_file=""

    for pid in "${PORT_FORWARD_PIDS[@]}"; do
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            wait "$pid" 2>/dev/null || true
        fi
    done

    for log_file in "${PORT_FORWARD_LOGS[@]}"; do
        rm -f "$log_file" 2>/dev/null || true
    done
}

trap cleanup_port_forwards EXIT

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
    local code=""
    
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

start_port_forward() {
    local resource=$1
    local local_port=$2
    local remote_port=$3
    local name=$4
    local log_file=""
    local pid=""

    log_file=$(mktemp "/tmp/${name}.XXXXXX.log")
    echo "Starting port-forward for $name (${resource} ${local_port}:${remote_port})..." >&2
    kubectl port-forward "$resource" "${local_port}:${remote_port}" -n "$NAMESPACE" >"$log_file" 2>&1 &
    pid=$!

    PORT_FORWARD_PIDS+=("$pid")
    PORT_FORWARD_LOGS+=("$log_file")

    sleep 3
    if ! kill -0 "$pid" 2>/dev/null; then
        echo "ERROR: Failed to start port-forward for $name" >&2
        sed -n '1,120p' "$log_file" >&2 || true
        return 1
    fi

    echo "$pid"
}

stop_port_forward() {
    local pid=$1

    if [ -n "${pid:-}" ] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
    fi
}

get_secret_value() {
    local secret_name=$1
    local key_name=$2

    kubectl get secret "$secret_name" -n "$NAMESPACE" -o "jsonpath={.data.${key_name}}" | base64 --decode
}

run_clickhouse_query() {
    local sql=$1

    curl -sS --fail \
        -u "${CLICKHOUSE_HTTP_USER}:${CLICKHOUSE_HTTP_PASSWORD}" \
        --data-binary "$sql" \
        "http://localhost:8123/?database=${CLICKHOUSE_DATABASE}"
}

get_table_count() {
    local table=$1
    local count=""

    count=$(run_clickhouse_query "SELECT count() FROM \`${CLICKHOUSE_DATABASE}\`.\`${table}\`;")
    count=$(echo "$count" | tr -d '[:space:]')

    if [[ ! "$count" =~ ^[0-9]+$ ]]; then
        echo "ERROR: Non-numeric count for table ${table}: ${count}"
        return 1
    fi

    echo "$count"
}

wait_for_table_queryable() {
    local table=$1
    local timeout_seconds=$2
    local start_time=0
    local now=0
    local count=""

    start_time=$(date +%s)
    while true; do
        count=$(get_table_count "$table" 2>/dev/null || true)
        if [[ "$count" =~ ^[0-9]+$ ]]; then
            echo "$count"
            return 0
        fi

        now=$(date +%s)
        if [ $((now - start_time)) -ge "$timeout_seconds" ]; then
            echo "ERROR: Timed out waiting for table ${CLICKHOUSE_DATABASE}.${table} to become queryable"
            return 1
        fi

        sleep "$INGESTION_POLL_INTERVAL"
    done
}

wait_for_table_count_increase() {
    local table=$1
    local baseline_count=$2
    local timeout_seconds=$3
    local start_time=0
    local now=0
    local current_count=""

    start_time=$(date +%s)
    while true; do
        current_count=$(get_table_count "$table" 2>/dev/null || true)
        if [[ "$current_count" =~ ^[0-9]+$ ]]; then
            echo "Current count for ${CLICKHOUSE_DATABASE}.${table}: ${current_count} (baseline ${baseline_count})"
            if [ "$current_count" -gt "$baseline_count" ]; then
                echo "Detected new rows in ${CLICKHOUSE_DATABASE}.${table}"
                return 0
            fi
        fi

        now=$(date +%s)
        if [ $((now - start_time)) -ge "$timeout_seconds" ]; then
            echo "ERROR: Timed out waiting for row increase in ${CLICKHOUSE_DATABASE}.${table}"
            return 1
        fi

        sleep "$INGESTION_POLL_INTERVAL"
    done
}

# Check pods
echo "Checking pod status..."
kubectl wait --for=condition=Ready pods -l app.kubernetes.io/instance=$RELEASE_NAME --timeout=${TIMEOUT}s -n $NAMESPACE

echo "Pod status:"
kubectl get pods -l app.kubernetes.io/instance=$RELEASE_NAME -n $NAMESPACE

# Test UI
echo "Testing HyperDX UI..."
pf_pid=$(start_port_forward "service/$RELEASE_NAME-$CHART_NAME-app" "3000" "3000" "hyperdx-ui")
sleep 2

wait_for_service "http://localhost:3000" "HyperDX UI"
check_endpoint "http://localhost:3000" "200" "UI"

stop_port_forward "$pf_pid"
sleep 2

# Test OTEL collector metrics endpoint
echo "Testing OTEL collector metrics endpoint..."
metrics_pf_pid=$(start_port_forward "service/$RELEASE_NAME-otel-collector" "8888" "8888" "otel-metrics")
sleep 2

wait_for_service "http://localhost:8888/metrics" "OTEL Metrics"
check_endpoint "http://localhost:8888/metrics" "200" "OTEL Metrics endpoint"

stop_port_forward "$metrics_pf_pid"
sleep 2

# Verify OTEL Collector Deployment is Available
echo "Verifying OTEL Collector Deployment..."
kubectl wait --for=condition=Available deployment/$RELEASE_NAME-otel-collector -n $NAMESPACE --timeout=${TIMEOUT}s
echo "OTEL Collector Deployment: OK (Available)"

# Verify ClickHouseCluster CR reconciled successfully
echo "Verifying ClickHouseCluster reconciliation..."
kubectl wait --for=condition=Ready clickhousecluster/$RELEASE_NAME-$CHART_NAME-clickhouse -n $NAMESPACE --timeout=${TIMEOUT}s
echo "ClickHouseCluster: OK (condition Ready=True)"

# Verify MongoDBCommunity CR reconciled successfully
echo "Verifying MongoDBCommunity reconciliation..."
mdb_phase=$(kubectl get mongodbcommunity -n $NAMESPACE $RELEASE_NAME-$CHART_NAME-mongodb -o jsonpath='{.status.phase}')
if [ "$mdb_phase" = "Running" ]; then
    echo "MongoDBCommunity: OK (phase=$mdb_phase)"
else
    echo "ERROR: MongoDBCommunity phase is '$mdb_phase', expected 'Running'"
    kubectl get mongodbcommunity -n $NAMESPACE $RELEASE_NAME-$CHART_NAME-mongodb -o yaml
    exit 1
fi

# Verify OTEL data ingestion to ClickHouse
echo "Verifying OTEL ingestion into ClickHouse..."
clickhouse_pf_pid=$(start_port_forward "service/$CLICKHOUSE_SERVICE" "8123" "8123" "clickhouse-http")

CLICKHOUSE_HTTP_PASSWORD=$(get_secret_value "$CLICKHOUSE_SECRET_NAME" "CLICKHOUSE_APP_PASSWORD")
if [ -z "${CLICKHOUSE_HTTP_PASSWORD:-}" ]; then
    echo "ERROR: Could not read CLICKHOUSE_APP_PASSWORD from secret ${CLICKHOUSE_SECRET_NAME}"
    exit 1
fi

trace_baseline=$(wait_for_table_queryable "$CLICKHOUSE_TRACE_TABLE" "$TIMEOUT")
log_baseline=$(wait_for_table_queryable "$CLICKHOUSE_LOG_TABLE" "$TIMEOUT")
echo "Baseline count ${CLICKHOUSE_DATABASE}.${CLICKHOUSE_TRACE_TABLE}: ${trace_baseline}"
echo "Baseline count ${CLICKHOUSE_DATABASE}.${CLICKHOUSE_LOG_TABLE}: ${log_baseline}"

# Trigger app activity to generate telemetry that should be exported to collector.
echo "Generating HyperDX activity to trigger OTEL telemetry..."
activity_pf_pid=$(start_port_forward "service/$RELEASE_NAME-$CHART_NAME-app" "3000" "3000" "hyperdx-activity")
check_endpoint "http://localhost:3000" "200" "UI activity request 1"
check_endpoint "http://localhost:3000" "200" "UI activity request 2"
check_endpoint "http://localhost:3000" "200" "UI activity request 3"
stop_port_forward "$activity_pf_pid"

echo "Waiting for traces/logs to land in ClickHouse..."

wait_for_table_count_increase "$CLICKHOUSE_TRACE_TABLE" "$trace_baseline" "$TIMEOUT"
wait_for_table_count_increase "$CLICKHOUSE_LOG_TABLE" "$log_baseline" "$TIMEOUT"

stop_port_forward "$clickhouse_pf_pid"

echo ""
echo "All smoke tests passed"
echo "- All pods running"
echo "- HyperDX UI responding"
echo "- OTEL Collector metrics accessible"
echo "- OTEL Collector Deployment available"
echo "- ClickHouseCluster reconciled (Ready)"
echo "- MongoDBCommunity reconciled (Running)"
echo "- OTEL traces and logs persisted to ClickHouse"
