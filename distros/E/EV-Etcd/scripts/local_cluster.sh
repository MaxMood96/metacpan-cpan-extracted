#!/bin/bash
#
# Start a minimal 3-node etcd cluster for testing
#
# Usage:
#   ./scripts/local_cluster.sh start   # Start cluster
#   ./scripts/local_cluster.sh stop    # Stop cluster
#   ./scripts/local_cluster.sh status  # Show cluster status
#
set -e

CLUSTER_DIR="${ETCD_CLUSTER_DIR:-/tmp/etcd-cluster}"
CLUSTER_TOKEN="etcd-cluster-test"

# Node configurations
NODE1_NAME="etcd1"
NODE1_CLIENT="127.0.0.1:2379"
NODE1_PEER="127.0.0.1:2380"

NODE2_NAME="etcd2"
NODE2_CLIENT="127.0.0.1:22379"
NODE2_PEER="127.0.0.1:22380"

NODE3_NAME="etcd3"
NODE3_CLIENT="127.0.0.1:32379"
NODE3_PEER="127.0.0.1:32380"

INITIAL_CLUSTER="${NODE1_NAME}=http://${NODE1_PEER},${NODE2_NAME}=http://${NODE2_PEER},${NODE3_NAME}=http://${NODE3_PEER}"

start_node() {
    local name=$1
    local client=$2
    local peer=$3
    local dir="${CLUSTER_DIR}/${name}"

    mkdir -p "$dir"

    echo "Starting $name (client=$client, peer=$peer)..."

    etcd \
        --name "$name" \
        --data-dir "$dir" \
        --listen-client-urls "http://${client}" \
        --advertise-client-urls "http://${client}" \
        --listen-peer-urls "http://${peer}" \
        --initial-advertise-peer-urls "http://${peer}" \
        --initial-cluster "$INITIAL_CLUSTER" \
        --initial-cluster-token "$CLUSTER_TOKEN" \
        --initial-cluster-state new \
        > "${dir}/etcd.log" 2>&1 &

    echo $! > "${dir}/etcd.pid"
    echo "  PID: $(cat ${dir}/etcd.pid)"
}

start_cluster() {
    echo "Starting 3-node etcd cluster..."
    echo "Cluster directory: $CLUSTER_DIR"
    echo ""

    # Clean up old data
    rm -rf "$CLUSTER_DIR"
    mkdir -p "$CLUSTER_DIR"

    start_node "$NODE1_NAME" "$NODE1_CLIENT" "$NODE1_PEER"
    start_node "$NODE2_NAME" "$NODE2_CLIENT" "$NODE2_PEER"
    start_node "$NODE3_NAME" "$NODE3_CLIENT" "$NODE3_PEER"

    echo ""
    echo "Waiting for cluster to form..."
    sleep 3

    # Check health
    if etcdctl --endpoints="http://${NODE1_CLIENT}" endpoint health 2>/dev/null; then
        echo ""
        echo "Cluster is healthy!"
        echo ""
        echo "Endpoints:"
        echo "  Node 1: http://${NODE1_CLIENT}"
        echo "  Node 2: http://${NODE2_CLIENT}"
        echo "  Node 3: http://${NODE3_CLIENT}"
        echo ""
        echo "To use with EV::Etcd:"
        echo "  my \$client = EV::Etcd->new(endpoints => ['${NODE1_CLIENT}', '${NODE2_CLIENT}', '${NODE3_CLIENT}']);"
    else
        echo "Warning: Cluster may not be fully healthy yet"
    fi
}

stop_cluster() {
    echo "Stopping etcd cluster..."

    for name in "$NODE1_NAME" "$NODE2_NAME" "$NODE3_NAME"; do
        local pidfile="${CLUSTER_DIR}/${name}/etcd.pid"
        if [ -f "$pidfile" ]; then
            local pid=$(cat "$pidfile")
            if kill -0 "$pid" 2>/dev/null; then
                echo "Stopping $name (PID $pid)..."
                kill "$pid" 2>/dev/null || true
            fi
            rm -f "$pidfile"
        fi
    done

    # Wait for processes to stop
    sleep 1

    # Force kill if still running
    pkill -f "etcd.*${CLUSTER_TOKEN}" 2>/dev/null || true

    echo "Cluster stopped."
}

show_status() {
    echo "Cluster status:"
    echo ""

    local running=0
    for name in "$NODE1_NAME" "$NODE2_NAME" "$NODE3_NAME"; do
        local pidfile="${CLUSTER_DIR}/${name}/etcd.pid"
        if [ -f "$pidfile" ]; then
            local pid=$(cat "$pidfile")
            if kill -0 "$pid" 2>/dev/null; then
                echo "  $name: RUNNING (PID $pid)"
                running=$((running + 1))
            else
                echo "  $name: STOPPED (stale PID file)"
            fi
        else
            echo "  $name: NOT STARTED"
        fi
    done

    echo ""

    if [ $running -eq 3 ]; then
        echo "Endpoint health:"
        etcdctl --endpoints="http://${NODE1_CLIENT},http://${NODE2_CLIENT},http://${NODE3_CLIENT}" endpoint health 2>/dev/null || echo "  (health check failed)"
        echo ""
        echo "Endpoint status:"
        etcdctl --endpoints="http://${NODE1_CLIENT},http://${NODE2_CLIENT},http://${NODE3_CLIENT}" endpoint status --write-out=table 2>/dev/null || echo "  (status check failed)"
    fi
}

case "${1:-}" in
    start)
        stop_cluster 2>/dev/null || true
        start_cluster
        ;;
    stop)
        stop_cluster
        ;;
    status)
        show_status
        ;;
    restart)
        stop_cluster
        sleep 1
        start_cluster
        ;;
    *)
        echo "Usage: $0 {start|stop|status|restart}"
        exit 1
        ;;
esac
