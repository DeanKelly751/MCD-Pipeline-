#!/bin/bash

# Verify SxM component deployment across clusters
# Usage: ./verify-deployment.sh [hub|managed] "mdm,kepler,qos,pdlc,prometheus"

set -euo pipefail

CLUSTER_TYPE=${1:-"managed"}
COMPONENTS=${2:-"mdm,kepler,qos,pdlc,prometheus"}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[ERROR] [$(date '+%Y-%m-%d %H:%M:%S')] $1" >&2
}

success() {
    echo "[SUCCESS] [$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Verification functions for each component
verify_mdm() {
    local cluster_type=$1
    log "Verifying MDM components for $cluster_type cluster..."
    
    if [[ "$cluster_type" == "hub" ]]; then
        # Check hub MDM components
        namespaces=("he-codeco-mdm")
        expected_pods=("mdm-api" "mdm-controller" "mdm-zookeeper" "mdm-kafka" "mdm-neo4j")
        
        for ns in "${namespaces[@]}"; do
            if kubectl get namespace "$ns" >/dev/null 2>&1; then
                success "Namespace $ns exists"
                
                for pod_pattern in "${expected_pods[@]}"; do
                    if kubectl get pods -n "$ns" | grep -q "$pod_pattern.*Running"; then
                        success "Pod $pod_pattern is running in $ns"
                    else
                        error "Pod $pod_pattern not found or not running in $ns"
                        kubectl get pods -n "$ns" | grep "$pod_pattern" || echo "No pods matching $pod_pattern"
                    fi
                done
            else
                error "Namespace $ns does not exist"
            fi
        done
    else
        # Check managed cluster MDM connectors
        namespaces=("he-codeco-mdm")
        expected_pods=("mdm-k8s-connector" "mdm-prometheus-connector" "mdm-kubescape-connector")
        
        for ns in "${namespaces[@]}"; do
            if kubectl get namespace "$ns" >/dev/null 2>&1; then
                success "Namespace $ns exists"
                
                for pod_pattern in "${expected_pods[@]}"; do
                    if kubectl get pods -n "$ns" | grep -q "$pod_pattern.*Running"; then
                        success "Pod $pod_pattern is running in $ns"
                    else
                        error "Pod $pod_pattern not found or not running in $ns"
                    fi
                done
            else
                error "Namespace $ns does not exist"
            fi
        done
    fi
}

verify_kepler() {
    local cluster_type=$1
    log "Verifying Kepler components for $cluster_type cluster..."
    
    namespace="kepler"
    
    if kubectl get namespace "$namespace" >/dev/null 2>&1; then
        success "Namespace $namespace exists"
        
        # Check Kepler DaemonSet
        if kubectl get daemonset kepler-exporter -n "$namespace" >/dev/null 2>&1; then
            success "Kepler DaemonSet exists"
            
            # Check if DaemonSet is ready
            desired=$(kubectl get daemonset kepler-exporter -n "$namespace" -o jsonpath='{.status.desiredNumberScheduled}')
            ready=$(kubectl get daemonset kepler-exporter -n "$namespace" -o jsonpath='{.status.numberReady}')
            
            if [[ "$desired" == "$ready" ]] && [[ "$ready" -gt 0 ]]; then
                success "Kepler DaemonSet is ready ($ready/$desired pods)"
            else
                error "Kepler DaemonSet not ready ($ready/$desired pods)"
            fi
        else
            error "Kepler DaemonSet not found"
        fi
        
        # Check Kepler service
        if kubectl get service kepler-exporter -n "$namespace" >/dev/null 2>&1; then
            success "Kepler service exists"
        else
            error "Kepler service not found"
        fi
    else
        error "Namespace $namespace does not exist"
    fi
}

verify_qos() {
    local cluster_type=$1
    log "Verifying QoS Scheduler components for $cluster_type cluster..."
    
    namespace="he-codeco-swm"
    
    if kubectl get namespace "$namespace" >/dev/null 2>&1; then
        success "Namespace $namespace exists"
        
        if [[ "$cluster_type" == "hub" ]]; then
            # Check CRDs on hub
            crds=("applications.swm.siem.com" "assignmentplans.swm.siem.com" "networktopologies.swm.siem.com")
            
            for crd in "${crds[@]}"; do
                if kubectl get crd "$crd" >/dev/null 2>&1; then
                    success "CRD $crd exists"
                else
                    error "CRD $crd not found"
                fi
            done
        else
            # Check QoS components on managed clusters
            expected_pods=("qos-scheduler" "qos-controller" "qos-nodedaemon")
            
            for pod_pattern in "${expected_pods[@]}"; do
                if kubectl get pods -n "$namespace" | grep -q "$pod_pattern.*Running"; then
                    success "Pod $pod_pattern is running in $namespace"
                else
                    error "Pod $pod_pattern not found or not running in $namespace"
                fi
            done
        fi
    else
        error "Namespace $namespace does not exist"
    fi
}

verify_pdlc() {
    local cluster_type=$1
    log "Verifying PDLC components for $cluster_type cluster..."
    
    # PDLC is only deployed on managed clusters
    if [[ "$cluster_type" == "hub" ]]; then
        log "PDLC not expected on hub cluster, skipping..."
        return 0
    fi
    
    namespace="he-codeco-pdlc"
    
    if kubectl get namespace "$namespace" >/dev/null 2>&1; then
        success "Namespace $namespace exists"
        
        expected_pods=("pdlc-dp" "pdlc-ca" "gnn-controller" "gnn-inference" "rl-model")
        
        for pod_pattern in "${expected_pods[@]}"; do
            if kubectl get pods -n "$namespace" | grep -q "$pod_pattern.*Running"; then
                success "Pod $pod_pattern is running in $namespace"
            else
                error "Pod $pod_pattern not found or not running in $namespace"
            fi
        done
    else
        error "Namespace $namespace does not exist"
    fi
}

verify_prometheus() {
    local cluster_type=$1
    log "Verifying Prometheus components for $cluster_type cluster..."
    
    if [[ "$cluster_type" == "hub" ]]; then
        # Check hub Prometheus components
        namespace="he-codeco-acm"
        
        if kubectl get namespace "$namespace" >/dev/null 2>&1; then
            success "Namespace $namespace exists"
            
            expected_pods=("thanos-query" "thanos-receive" "prometheus-operator")
            
            for pod_pattern in "${expected_pods[@]}"; do
                if kubectl get pods -n "$namespace" | grep -q "$pod_pattern.*Running"; then
                    success "Pod $pod_pattern is running in $namespace"
                else
                    error "Pod $pod_pattern not found or not running in $namespace"
                fi
            done
        else
            error "Namespace $namespace does not exist"
        fi
    else
        # Check managed cluster Prometheus agent
        namespace="monitoring"
        
        if kubectl get namespace "$namespace" >/dev/null 2>&1; then
            success "Namespace $namespace exists"
            
            if kubectl get deployment prometheus-agent -n "$namespace" >/dev/null 2>&1; then
                success "Prometheus agent deployment exists"
                
                # Check if deployment is ready
                ready=$(kubectl get deployment prometheus-agent -n "$namespace" -o jsonpath='{.status.readyReplicas}')
                desired=$(kubectl get deployment prometheus-agent -n "$namespace" -o jsonpath='{.spec.replicas}')
                
                if [[ "$ready" == "$desired" ]] && [[ "$ready" -gt 0 ]]; then
                    success "Prometheus agent is ready ($ready/$desired replicas)"
                else
                    error "Prometheus agent not ready ($ready/$desired replicas)"
                fi
            else
                error "Prometheus agent deployment not found"
            fi
        else
            error "Namespace $namespace does not exist"
        fi
    fi
}

verify_policies() {
    local cluster_type=$1
    log "Verifying OCM policies for $cluster_type cluster..."
    
    if [[ "$cluster_type" == "hub" ]]; then
        # Check if policies exist on hub
        if kubectl get policies -A >/dev/null 2>&1; then
            policy_count=$(kubectl get policies -A --no-headers | wc -l)
            if [[ "$policy_count" -gt 0 ]]; then
                success "Found $policy_count OCM policies"
                
                # Check policy compliance
                compliant=$(kubectl get policies -A -o jsonpath='{.items[*].status.compliant}' | grep -o "Compliant" | wc -l)
                total=$(kubectl get policies -A --no-headers | wc -l)
                
                log "Policy compliance: $compliant/$total policies compliant"
                
                if [[ "$compliant" == "$total" ]]; then
                    success "All policies are compliant"
                else
                    error "Some policies are not compliant"
                    kubectl get policies -A | grep -v "Compliant" || true
                fi
            else
                error "No OCM policies found"
            fi
        else
            error "Unable to check OCM policies (OCM may not be installed)"
        fi
    fi
}

verify_connectivity() {
    local cluster_type=$1
    log "Verifying connectivity for $cluster_type cluster..."
    
    if [[ "$cluster_type" == "managed" ]]; then
        # Test connectivity to hub services
        log "Testing connectivity to hub services..."
        
        # Test Thanos receiver connectivity
        if kubectl run connectivity-test --image=curlimages/curl --rm -it --restart=Never -- \
           curl -s -o /dev/null -w "%{http_code}" http://thanos-receive-router.he-codeco-acm.svc.cluster.local:19291/api/v1/receive 2>/dev/null; then
            success "Connectivity to Thanos receiver successful"
        else
            error "Cannot connect to Thanos receiver"
        fi
        
        # Test MDM API connectivity
        if kubectl run connectivity-test --image=curlimages/curl --rm -it --restart=Never -- \
           curl -s -o /dev/null -w "%{http_code}" http://mdm-api.he-codeco-mdm.svc.cluster.local:8090/health 2>/dev/null; then
            success "Connectivity to MDM API successful"
        else
            error "Cannot connect to MDM API"
        fi
    fi
}

# Main verification function
main() {
    log "Starting verification for $CLUSTER_TYPE cluster with components: $COMPONENTS"
    
    # Get current cluster context
    current_context=$(kubectl config current-context)
    log "Current cluster context: $current_context"
    
    # Parse components and verify each one
    IFS=',' read -ra COMPONENT_ARRAY <<< "$COMPONENTS"
    
    for component in "${COMPONENT_ARRAY[@]}"; do
        component=$(echo "$component" | xargs) # trim whitespace
        case "$component" in
            "mdm")
                verify_mdm "$CLUSTER_TYPE"
                ;;
            "kepler")
                verify_kepler "$CLUSTER_TYPE"
                ;;
            "qos")
                verify_qos "$CLUSTER_TYPE"
                ;;
            "pdlc")
                verify_pdlc "$CLUSTER_TYPE"
                ;;
            "prometheus")
                verify_prometheus "$CLUSTER_TYPE"
                ;;
            *)
                error "Unknown component: $component"
                ;;
        esac
    done
    
    # Additional verifications
    verify_policies "$CLUSTER_TYPE"
    verify_connectivity "$CLUSTER_TYPE"
    
    log "✅ Verification completed for $CLUSTER_TYPE cluster"
}

# Execute main function
main "$@"
