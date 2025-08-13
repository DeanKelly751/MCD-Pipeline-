#!/bin/bash

# Generate deployment report for SxM components
# Usage: ./generate-report.sh

set -euo pipefail

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

generate_cluster_info() {
    local cluster_context=$1
    
    echo "### Cluster: $cluster_context"
    echo ""
    
    # Switch to cluster context
    kubectl config use-context "$cluster_context" >/dev/null 2>&1 || {
        echo "❌ **Unable to connect to cluster $cluster_context**"
        echo ""
        return 1
    }
    
    # Basic cluster info
    echo "**Cluster Information:**"
    echo "- Context: \`$cluster_context\`"
    
    # Get cluster version
    version=$(kubectl version --short 2>/dev/null | grep "Server Version" | cut -d' ' -f3 || echo "Unknown")
    echo "- Kubernetes Version: \`$version\`"
    
    # Get node count
    node_count=$(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo "0")
    echo "- Node Count: $node_count"
    
    echo ""
    
    # Namespace summary
    echo "**Namespaces:**"
    sxm_namespaces=("he-codeco-mdm" "he-codeco-acm" "he-codeco-swm" "he-codeco-pdlc" "monitoring" "kepler")
    
    for ns in "${sxm_namespaces[@]}"; do
        if kubectl get namespace "$ns" >/dev/null 2>&1; then
            pod_count=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | wc -l || echo "0")
            running_count=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | grep -c "Running" || echo "0")
            echo "- ✅ \`$ns\`: $running_count/$pod_count pods running"
        else
            echo "- ❌ \`$ns\`: Not found"
        fi
    done
    
    echo ""
}

generate_component_status() {
    local cluster_context=$1
    
    echo "**Component Status:**"
    
    # Switch to cluster context
    kubectl config use-context "$cluster_context" >/dev/null 2>&1 || return 1
    
    # Check MDM components
    if kubectl get namespace he-codeco-mdm >/dev/null 2>&1; then
        echo ""
        echo "*MDM Components:*"
        kubectl get pods -n he-codeco-mdm --no-headers 2>/dev/null | while read -r line; do
            pod_name=$(echo "$line" | awk '{print $1}')
            status=$(echo "$line" | awk '{print $3}')
            if [[ "$status" == "Running" ]]; then
                echo "- ✅ $pod_name: $status"
            else
                echo "- ❌ $pod_name: $status"
            fi
        done
    fi
    
    # Check Kepler
    if kubectl get namespace kepler >/dev/null 2>&1; then
        echo ""
        echo "*Kepler:*"
        if kubectl get daemonset kepler-exporter -n kepler >/dev/null 2>&1; then
            desired=$(kubectl get daemonset kepler-exporter -n kepler -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "0")
            ready=$(kubectl get daemonset kepler-exporter -n kepler -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
            if [[ "$desired" == "$ready" ]] && [[ "$ready" -gt 0 ]]; then
                echo "- ✅ Kepler DaemonSet: $ready/$desired pods ready"
            else
                echo "- ❌ Kepler DaemonSet: $ready/$desired pods ready"
            fi
        else
            echo "- ❌ Kepler DaemonSet: Not found"
        fi
    fi
    
    # Check QoS Scheduler
    if kubectl get namespace he-codeco-swm >/dev/null 2>&1; then
        echo ""
        echo "*QoS Scheduler:*"
        kubectl get pods -n he-codeco-swm --no-headers 2>/dev/null | while read -r line; do
            pod_name=$(echo "$line" | awk '{print $1}')
            status=$(echo "$line" | awk '{print $3}')
            if [[ "$status" == "Running" ]]; then
                echo "- ✅ $pod_name: $status"
            else
                echo "- ❌ $pod_name: $status"
            fi
        done
    fi
    
    # Check PDLC
    if kubectl get namespace he-codeco-pdlc >/dev/null 2>&1; then
        echo ""
        echo "*PDLC:*"
        kubectl get pods -n he-codeco-pdlc --no-headers 2>/dev/null | while read -r line; do
            pod_name=$(echo "$line" | awk '{print $1}')
            status=$(echo "$line" | awk '{print $3}')
            if [[ "$status" == "Running" ]]; then
                echo "- ✅ $pod_name: $status"
            else
                echo "- ❌ $pod_name: $status"
            fi
        done
    fi
    
    # Check Prometheus/Monitoring
    if kubectl get namespace monitoring >/dev/null 2>&1; then
        echo ""
        echo "*Monitoring:*"
        kubectl get pods -n monitoring --no-headers 2>/dev/null | while read -r line; do
            pod_name=$(echo "$line" | awk '{print $1}')
            status=$(echo "$line" | awk '{print $3}')
            if [[ "$status" == "Running" ]]; then
                echo "- ✅ $pod_name: $status"
            else
                echo "- ❌ $pod_name: $status"
            fi
        done
    fi
    
    if kubectl get namespace he-codeco-acm >/dev/null 2>&1; then
        echo ""
        echo "*Thanos (Hub):*"
        kubectl get pods -n he-codeco-acm --no-headers 2>/dev/null | while read -r line; do
            pod_name=$(echo "$line" | awk '{print $1}')
            status=$(echo "$line" | awk '{print $3}')
            if [[ "$status" == "Running" ]]; then
                echo "- ✅ $pod_name: $status"
            else
                echo "- ❌ $pod_name: $status"
            fi
        done
    fi
    
    echo ""
}

generate_policy_status() {
    echo "## OCM Policy Status"
    echo ""
    
    # Get current context (should be hub)
    current_context=$(kubectl config current-context)
    
    # Check if OCM is available
    if kubectl get policies -A >/dev/null 2>&1; then
        echo "**Policy Summary:**"
        
        total_policies=$(kubectl get policies -A --no-headers 2>/dev/null | wc -l || echo "0")
        compliant_policies=$(kubectl get policies -A -o jsonpath='{.items[*].status.compliant}' 2>/dev/null | grep -o "Compliant" | wc -l || echo "0")
        
        echo "- Total Policies: $total_policies"
        echo "- Compliant Policies: $compliant_policies"
        
        if [[ "$total_policies" -gt 0 ]]; then
            compliance_rate=$((compliant_policies * 100 / total_policies))
            echo "- Compliance Rate: ${compliance_rate}%"
            
            if [[ "$compliance_rate" -eq 100 ]]; then
                echo "- Status: ✅ All policies compliant"
            else
                echo "- Status: ⚠️ Some policies non-compliant"
            fi
        else
            echo "- Status: ❌ No policies found"
        fi
        
        echo ""
        
        # List individual policies
        echo "**Individual Policy Status:**"
        kubectl get policies -A --no-headers 2>/dev/null | while read -r line; do
            namespace=$(echo "$line" | awk '{print $1}')
            name=$(echo "$line" | awk '{print $2}')
            compliant=$(echo "$line" | awk '{print $3}')
            
            if [[ "$compliant" == "Compliant" ]]; then
                echo "- ✅ \`$namespace/$name\`: $compliant"
            else
                echo "- ❌ \`$namespace/$name\`: $compliant"
            fi
        done
        
    else
        echo "❌ **OCM not available or no policies found**"
    fi
    
    echo ""
}

generate_connectivity_status() {
    echo "## Connectivity Status"
    echo ""
    
    current_context=$(kubectl config current-context)
    
    if [[ "$current_context" == *"managed"* ]] || [[ "$current_context" == *"cluster"* ]]; then
        echo "**Hub Connectivity (from managed cluster):**"
        
        # Test Thanos connectivity
        if timeout 10 kubectl run connectivity-test-thanos --image=curlimages/curl --rm -i --restart=Never -- \
           curl -s -o /dev/null -w "%{http_code}" http://thanos-receive-router.he-codeco-acm.svc.cluster.local:19291/api/v1/receive >/dev/null 2>&1; then
            echo "- ✅ Thanos Receiver: Reachable"
        else
            echo "- ❌ Thanos Receiver: Not reachable"
        fi
        
        # Test MDM API connectivity
        if timeout 10 kubectl run connectivity-test-mdm --image=curlimages/curl --rm -i --restart=Never -- \
           curl -s -o /dev/null -w "%{http_code}" http://mdm-api.he-codeco-mdm.svc.cluster.local:8090/health >/dev/null 2>&1; then
            echo "- ✅ MDM API: Reachable"
        else
            echo "- ❌ MDM API: Not reachable"
        fi
        
    else
        echo "**Hub Cluster Services:**"
        
        # Check if services are accessible
        if kubectl get service -n he-codeco-acm thanos-receive-router >/dev/null 2>&1; then
            echo "- ✅ Thanos Receiver Service: Available"
        else
            echo "- ❌ Thanos Receiver Service: Not found"
        fi
        
        if kubectl get service -n he-codeco-mdm mdm-api >/dev/null 2>&1; then
            echo "- ✅ MDM API Service: Available"
        else
            echo "- ❌ MDM API Service: Not found"
        fi
    fi
    
    echo ""
}

# Main report generation
main() {
    echo "## Component Status by Cluster"
    echo ""
    
    # Get all available contexts
    contexts=$(kubectl config get-contexts -o name 2>/dev/null || echo "")
    
    if [[ -z "$contexts" ]]; then
        echo "❌ **No kubectl contexts available**"
        return 1
    fi
    
    # Generate report for each context
    for context in $contexts; do
        generate_cluster_info "$context"
        generate_component_status "$context"
        echo "---"
        echo ""
    done
    
    # Generate policy status (from hub context)
    hub_context=$(echo "$contexts" | grep -E "(hub|local)" | head -n1 || echo "")
    if [[ -n "$hub_context" ]]; then
        kubectl config use-context "$hub_context" >/dev/null 2>&1
        generate_policy_status
    fi
    
    # Generate connectivity status
    generate_connectivity_status
    
    echo "## Summary"
    echo ""
    echo "**Deployment completed at:** $(date)"
    echo ""
    echo "**Next Steps:**"
    echo "1. Monitor component health and resource usage"
    echo "2. Verify data flow between managed clusters and hub"
    echo "3. Check application logs for any errors"
    echo "4. Validate OCM policy compliance regularly"
    echo ""
    echo "**Troubleshooting:**"
    echo "- Use \`kubectl get pods -A\` to check pod status"
    echo "- Use \`kubectl logs <pod-name> -n <namespace>\` to check logs"
    echo "- Use \`kubectl get policies -A\` to check policy status"
    echo "- Use OCM console for centralized monitoring"
}

# Execute main function
main "$@"
