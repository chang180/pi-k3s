#!/bin/bash

# Resource Monitoring Script for Pi-K3s VPS Deployment
# Monitors CPU, memory, and resource usage for the application

VPS_HOST="165.154.227.179"
NAMESPACE="pi-k3s"
KUBECONFIG_PATH="$HOME/.kube/config-pi-k3s"

# Colors for output
RED='\033[0.31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if kubeconfig exists
if [ ! -f "$KUBECONFIG_PATH" ]; then
    echo -e "${RED}Error: Kubeconfig not found at $KUBECONFIG_PATH${NC}"
    echo "Please run the deployment script first or set KUBECONFIG manually"
    exit 1
fi

export KUBECONFIG="$KUBECONFIG_PATH"

echo "======================================"
echo "Pi-K3s Resource Monitoring"
echo "======================================"
echo "Target: $VPS_HOST"
echo "Namespace: $NAMESPACE"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Function to print section header
print_header() {
    echo -e "${BLUE}==== $1 ====${NC}"
}

# Function to check if metrics-server is available
check_metrics_server() {
    if ! kubectl top node &>/dev/null; then
        echo -e "${YELLOW}⚠  Warning: Metrics server not available${NC}"
        echo "Installing metrics-server..."
        kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
        echo "Waiting for metrics-server to start (30 seconds)..."
        sleep 30
    fi
}

# 1. Node Resources
print_header "Node Resources"
kubectl get nodes -o wide
echo ""

echo "Node Resource Usage:"
check_metrics_server
kubectl top node 2>/dev/null || echo "Metrics not available yet"
echo ""

# 2. Namespace Resources
print_header "Namespace: $NAMESPACE"
kubectl get all -n $NAMESPACE
echo ""

# 3. Pod Status and Resources
print_header "Pod Details"
pods=$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}')

if [ -z "$pods" ]; then
    echo -e "${RED}No pods found in namespace $NAMESPACE${NC}"
else
    for pod in $pods; do
        echo -e "${GREEN}Pod: $pod${NC}"

        # Pod status
        status=$(kubectl get pod -n $NAMESPACE $pod -o jsonpath='{.status.phase}')
        echo "  Status: $status"

        # Pod age
        age=$(kubectl get pod -n $NAMESPACE $pod -o jsonpath='{.metadata.creationTimestamp}')
        echo "  Created: $age"

        # Resource requests and limits
        echo "  Resource Requests:"
        kubectl get pod -n $NAMESPACE $pod -o jsonpath='{range .spec.containers[*]}    {.name}: CPU={.resources.requests.cpu} Memory={.resources.requests.memory}{"\n"}{end}'

        echo "  Resource Limits:"
        kubectl get pod -n $NAMESPACE $pod -o jsonpath='{range .spec.containers[*]}    {.name}: CPU={.resources.limits.cpu} Memory={.resources.limits.memory}{"\n"}{end}'

        # Current resource usage
        echo "  Current Usage:"
        kubectl top pod -n $NAMESPACE $pod 2>/dev/null || echo "    Metrics not available"

        # Restart count
        restarts=$(kubectl get pod -n $NAMESPACE $pod -o jsonpath='{.status.containerStatuses[0].restartCount}')
        if [ "$restarts" -gt 0 ]; then
            echo -e "  ${YELLOW}⚠  Restarts: $restarts${NC}"
        fi

        echo ""
    done
fi

# 4. Service Endpoints
print_header "Services & Endpoints"
kubectl get svc -n $NAMESPACE
echo ""
kubectl get endpoints -n $NAMESPACE
echo ""

# 5. Ingress Status
print_header "Ingress Rules"
kubectl get ingress -n $NAMESPACE -o wide
echo ""

# 6. Recent Events
print_header "Recent Events (Last 10)"
kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | tail -10
echo ""

# 7. Storage Usage (if PVCs exist)
pvc_count=$(kubectl get pvc -n $NAMESPACE 2>/dev/null | wc -l)
if [ "$pvc_count" -gt 1 ]; then
    print_header "Persistent Volume Claims"
    kubectl get pvc -n $NAMESPACE
    echo ""
fi

# 8. Resource Usage Summary
print_header "Resource Usage Summary"
echo "Total Pods: $(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | wc -l)"
echo "Running Pods: $(kubectl get pods -n $NAMESPACE --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)"
echo "Failed Pods: $(kubectl get pods -n $NAMESPACE --field-selector=status.phase=Failed --no-headers 2>/dev/null | wc -l)"
echo ""

# Calculate total resource requests
echo "Aggregate Resource Requests:"
total_cpu_requests=$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].spec.containers[*].resources.requests.cpu}' | tr ' ' '\n' | sed 's/m$//' | awk '{s+=$1} END {print s}')
total_mem_requests=$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].spec.containers[*].resources.requests.memory}' | tr ' ' '\n' | sed 's/Mi$//' | awk '{s+=$1} END {print s}')
echo "  Total CPU Requests: ${total_cpu_requests}m"
echo "  Total Memory Requests: ${total_mem_requests}Mi"
echo ""

echo "Aggregate Resource Limits:"
total_cpu_limits=$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].spec.containers[*].resources.limits.cpu}' | tr ' ' '\n' | sed 's/m$//' | awk '{s+=$1} END {print s}')
total_mem_limits=$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].spec.containers[*].resources.limits.memory}' | tr ' ' '\n' | sed 's/Mi$//' | awk '{s+=$1} END {print s}')
echo "  Total CPU Limits: ${total_cpu_limits}m"
echo "  Total Memory Limits: ${total_mem_limits}Mi"
echo ""

# 9. Recommendations
print_header "Recommendations for HPA (Phase 4)"
echo ""
echo "Based on current resource configuration:"
echo "  - Monitor these metrics over 24-48 hours"
echo "  - CPU usage above 70%: Consider increasing CPU limits"
echo "  - Memory usage above 80%: Consider increasing memory limits"
echo "  - Frequent restarts: Check logs for OOMKilled events"
echo ""
echo "For HPA configuration:"
echo "  - Set target CPU utilization: 70-80%"
echo "  - Set target memory utilization: 75-85%"
echo "  - Min replicas: 1, Max replicas: 3 (for 1C1G VPS)"
echo ""

# 10. Continuous Monitoring Mode
if [ "$1" == "--watch" ] || [ "$1" == "-w" ]; then
    echo -e "${YELLOW}Entering watch mode (updates every 10 seconds)${NC}"
    echo "Press Ctrl+C to exit"
    echo ""
    while true; do
        clear
        bash "$0"
        sleep 10
    done
fi

# 11. Export Metrics
if [ "$1" == "--export" ] || [ "$1" == "-e" ]; then
    EXPORT_FILE="monitoring-$(date +%Y%m%d-%H%M%S).txt"
    bash "$0" > "$EXPORT_FILE"
    echo -e "${GREEN}✓ Metrics exported to: $EXPORT_FILE${NC}"
fi

echo "======================================"
echo "Monitoring Commands:"
echo "======================================"
echo "  Watch mode:        $0 --watch"
echo "  Export metrics:    $0 --export"
echo "  Pod logs:          kubectl --kubeconfig=$KUBECONFIG_PATH logs -n $NAMESPACE -l app=laravel -f"
echo "  Describe pod:      kubectl --kubeconfig=$KUBECONFIG_PATH describe pod -n $NAMESPACE <pod-name>"
echo "  Exec into pod:     kubectl --kubeconfig=$KUBECONFIG_PATH exec -it -n $NAMESPACE <pod-name> -- /bin/sh"
echo ""
