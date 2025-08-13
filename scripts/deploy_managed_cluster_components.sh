#!/bin/bash

# Copyright (c) 2024 Red Hat, Inc
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# 
# SPDX-License-Identifier: Apache-2.0

##############################################################################
# OCM Managed Cluster Component Deployment Script
# 
# This script deploys components specifically to OCM managed clusters:
# - Prometheus (monitoring agent for managed clusters)
# - MDM Connectors (data collection agents)  
# - PDLC (Privacy-preserving Decentralised Learning components)
# - QoS Scheduler (workload scheduler)
# - Kepler (power monitoring)
##############################################################################

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/managed_cluster_deployment.log"
ERROR_LOG="${SCRIPT_DIR}/managed_cluster_deployment_errors.log"

# Component flags - set to true to install
INSTALL_PROMETHEUS=${INSTALL_PROMETHEUS:-true}
INSTALL_MDM_CONNECTORS=${INSTALL_MDM_CONNECTORS:-true}
INSTALL_PDLC=${INSTALL_PDLC:-true}
INSTALL_QOS_SCHEDULER=${INSTALL_QOS_SCHEDULER:-true}
INSTALL_KEPLER=${INSTALL_KEPLER:-true}

# Configuration variables for managed clusters
PROMETHEUS_NAMESPACE="open-cluster-management-observability"
MDM_CONNECTORS_NAMESPACE="he-codeco-mdm-agent"
PDLC_NAMESPACE="he-codeco-pdlc"
QOS_NAMESPACE="he-codeco-swm"
KEPLER_NAMESPACE="kepler"

# OCM specific configurations
OCM_CLUSTER_NAME=${OCM_CLUSTER_NAME:-$(kubectl get managedcluster -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "local-cluster")}
HUB_PROMETHEUS_URL=${HUB_PROMETHEUS_URL:-""}
MDM_HUB_API_URL=${MDM_HUB_API_URL:-""}

##############################################################################
# Utility Functions
##############################################################################

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error() {
    echo "[ERROR] [$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$ERROR_LOG" >&2
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        error "$1 is not installed or not in PATH"
        return 1
    fi
}

wait_for_pods() {
    local namespace=${1:-}
    local timeout=${2:-20m}
    
    if [[ -n "$namespace" ]]; then
        log "Waiting for pods in namespace $namespace to be ready..."
        kubectl wait --for=condition=Ready pod --all -n "$namespace" --timeout="$timeout" || {
            error "Timeout waiting for pods in namespace $namespace"
            return 1
        }
    else
        log "Waiting for all pods to be ready..."
        kubectl wait --for=condition=Ready pod --all -A --timeout="$timeout" || {
            error "Timeout waiting for all pods"
            return 1
        }
    fi
}

create_namespace() {
    local namespace=$1
    if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
        log "Creating namespace: $namespace"
        kubectl create namespace "$namespace"
        kubectl label namespace "$namespace" "namespace=$namespace" --overwrite
        
        # Add OCM specific labels for managed clusters
        kubectl label namespace "$namespace" "cluster.open-cluster-management.io/managedCluster=$OCM_CLUSTER_NAME" --overwrite
    else
        log "Namespace $namespace already exists"
    fi
}

##############################################################################
# OCM and Cluster Information
##############################################################################

gather_cluster_info() {
    log "Gathering OCM managed cluster information..."
    
    # Detect if this is an OCM managed cluster
    if kubectl get managedcluster 2>/dev/null | grep -q "$OCM_CLUSTER_NAME"; then
        log "Detected OCM managed cluster: $OCM_CLUSTER_NAME"
        export IS_OCM_MANAGED_CLUSTER=true
    else
        log "Not detected as OCM managed cluster, proceeding as standalone"
        export IS_OCM_MANAGED_CLUSTER=false
    fi
    
    # Detect control plane node (for scheduling considerations)
    control_plane_labels=(
        "node-role.kubernetes.io/master"
        "node-role.kubernetes.io/control-plane"
        "node.kubernetes.io/role=master"
        "node.kubernetes.io/microk8s-controlplane"
    )
    
    CONTROL_PLANE_NODE=""
    for label in "${control_plane_labels[@]}"; do
        CONTROL_PLANE_NODE=$(kubectl get nodes -o custom-columns=NAME:.metadata.name --no-headers -l "$label" 2>/dev/null | head -1)
        if [[ -n "$CONTROL_PLANE_NODE" ]]; then
            WORKER_NODES=($(kubectl get nodes -o custom-columns=NAME:.metadata.name --no-headers -l '!'$label 2>/dev/null))
            kubectl get nodes -l "$label" -o name | xargs -r -I{} kubectl label {} dedicated=control-plane --overwrite
            break
        fi
    done
    
    if [[ -z "$CONTROL_PLANE_NODE" ]]; then
        log "WARNING: No control plane node detected"
        WORKER_NODES=($(kubectl get nodes -o custom-columns=NAME:.metadata.name --no-headers))
    fi
    
    # Get current context
    CURRENT_CONTEXT=$(kubectl config current-context)
    
    # Add node labels for QoS scheduler
    export NODE_LABEL_PREFIX=siemens.com.qosscheduler
    for node in $(kubectl get nodes -o jsonpath="{.items[*].metadata.name}"); do
        kubectl label --overwrite nodes "${node}" "${NODE_LABEL_PREFIX}.${node}="
    done
    
    # Ensure control plane is properly labeled
    if [[ -n "$CONTROL_PLANE_NODE" ]]; then
        kubectl label nodes "$CONTROL_PLANE_NODE" node-role.kubernetes.io/control-plane="" --overwrite
    fi
    
    log "OCM Cluster: $OCM_CLUSTER_NAME"
    log "Control plane node: ${CONTROL_PLANE_NODE:-'Not detected'}"
    log "Worker nodes: ${WORKER_NODES[*]:-'None detected'}"
    log "Current context: $CURRENT_CONTEXT"
}

check_prerequisites() {
    log "Checking prerequisites for managed cluster deployment..."
    
    # Check required commands
    local required_commands=("kubectl" "helm" "curl" "git")
    for cmd in "${required_commands[@]}"; do
        check_command "$cmd" || exit 1
    done
    
    # Check kubectl connectivity
    if ! kubectl cluster-info >/dev/null 2>&1; then
        error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Setup sed command for cross-platform compatibility
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS - check if GNU sed is available, otherwise install it
        if command -v gsed &> /dev/null; then
            SED_CMD="gsed"
            log "Using GNU sed (gsed) for compatibility"
        elif command -v brew &> /dev/null; then
            log "Installing GNU sed via Homebrew for Linux compatibility..."
            brew install gnu-sed
            SED_CMD="gsed"
        else
            log "Warning: Using BSD sed on macOS. Some commands may fail."
            log "For best compatibility, install GNU sed: brew install gnu-sed"
            SED_CMD="sed"
        fi
    else
        # Linux or other systems
        SED_CMD="sed"
    fi
    export SED_CMD
    
    # Install yq if not present
    if ! command -v yq &> /dev/null; then
        log "Installing yq..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            curl -L "https://github.com/mikefarah/yq/releases/latest/download/yq_darwin_amd64" -o /tmp/yq
        else
            curl -L "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64" -o /tmp/yq
        fi
        chmod +x /tmp/yq
        sudo mv /tmp/yq /usr/local/bin/yq || {
            error "Failed to install yq. Please install manually."
            exit 1
        }
    fi
    
    log "Prerequisites check completed"
}

##############################################################################
# Prometheus Agent Installation (for OCM Observability)
##############################################################################

install_prometheus_agent() {
    if [[ "$INSTALL_PROMETHEUS" != "true" ]]; then
        log "Skipping Prometheus agent installation"
        return 0
    fi
    
    log "Installing Prometheus agent for managed cluster..."
    
    # Create namespace if it doesn't exist
    create_namespace "$PROMETHEUS_NAMESPACE"
    
    # For OCM managed clusters, we typically use prometheus agent mode
    # that forwards metrics to the hub cluster
    if [[ "$IS_OCM_MANAGED_CLUSTER" == "true" ]]; then
        log "Configuring Prometheus agent for OCM managed cluster..."
        
        # Deploy prometheus agent configuration
        cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-agent-config
  namespace: $PROMETHEUS_NAMESPACE
data:
  prometheus.yml: |
    global:
      scrape_interval: 30s
      evaluation_interval: 30s
      external_labels:
        cluster: '$OCM_CLUSTER_NAME'
        region: 'managed-cluster'
    
    scrape_configs:
    - job_name: 'kubernetes-pods'
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: \$1:\$2
        target_label: __address__
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      - source_labels: [__meta_kubernetes_namespace]
        action: replace
        target_label: kubernetes_namespace
      - source_labels: [__meta_kubernetes_pod_name]
        action: replace
        target_label: kubernetes_pod_name
    
    - job_name: 'kubernetes-nodes'
      kubernetes_sd_configs:
      - role: node
      relabel_configs:
      - action: labelmap
        regex: __meta_kubernetes_node_label_(.+)
    
    - job_name: 'kepler'
      kubernetes_sd_configs:
      - role: pod
        namespaces:
          names:
          - kepler
      relabel_configs:
      - source_labels: [__meta_kubernetes_pod_label_app_kubernetes_io_name]
        action: keep
        regex: kepler
      - source_labels: [__meta_kubernetes_pod_container_port_name]
        action: keep
        regex: http
        
    remote_write:
    - url: '${HUB_PROMETHEUS_URL}/api/v1/receive'
      queue_config:
        max_samples_per_send: 10000
        max_shards: 200
        capacity: 2500
EOF

        # Deploy prometheus agent
        cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus-agent
  namespace: $PROMETHEUS_NAMESPACE
  labels:
    app: prometheus-agent
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus-agent
  template:
    metadata:
      labels:
        app: prometheus-agent
    spec:
      serviceAccountName: prometheus-agent
      containers:
      - name: prometheus
        image: quay.io/prometheus/prometheus:v2.47.0
        args:
        - '--config.file=/etc/prometheus/prometheus.yml'
        - '--storage.agent.path=/prometheus'
        - '--enable-feature=agent'
        - '--web.enable-lifecycle'
        - '--web.listen-address=0.0.0.0:9090'
        ports:
        - containerPort: 9090
          name: http
        volumeMounts:
        - name: config
          mountPath: /etc/prometheus
        - name: storage
          mountPath: /prometheus
        resources:
          requests:
            memory: 400Mi
            cpu: 100m
          limits:
            memory: 800Mi
            cpu: 200m
      volumes:
      - name: config
        configMap:
          name: prometheus-agent-config
      - name: storage
        emptyDir: {}
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus-agent
  namespace: $PROMETHEUS_NAMESPACE
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus-agent
rules:
- apiGroups: [""]
  resources:
  - nodes
  - nodes/proxy
  - services
  - endpoints
  - pods
  verbs: ["get", "list", "watch"]
- apiGroups:
  - extensions
  resources:
  - ingresses
  verbs: ["get", "list", "watch"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus-agent
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus-agent
subjects:
- kind: ServiceAccount
  name: prometheus-agent
  namespace: $PROMETHEUS_NAMESPACE
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus-agent
  namespace: $PROMETHEUS_NAMESPACE
  labels:
    app: prometheus-agent
spec:
  ports:
  - port: 9090
    targetPort: 9090
    name: http
  selector:
    app: prometheus-agent
EOF
    else
        # For standalone clusters, use standard prometheus deployment
        log "Deploying standard Prometheus for standalone cluster..."
        if [[ -d "../monitoring-architecture/prometheus-agent" ]]; then
            kubectl apply -f ../monitoring-architecture/prometheus-agent/
        fi
    fi
    
    wait_for_pods "$PROMETHEUS_NAMESPACE" "10m"
    log "Prometheus agent installation completed"
}

##############################################################################
# MDM Connectors Installation
##############################################################################

install_mdm_connectors() {
    if [[ "$INSTALL_MDM_CONNECTORS" != "true" ]]; then
        log "Skipping MDM connectors installation"
        return 0
    fi
    
    log "Installing MDM connectors for managed cluster..."
    
    # Create namespace
    create_namespace "$MDM_CONNECTORS_NAMESPACE"
    
    # Check if MDM connectors repository exists
    if [[ ! -d "../../mdm-connectors" ]]; then
        error "MDM connectors directory not found. Please ensure repositories are cloned."
        return 1
    fi
    
    pushd "../../mdm-connectors" >/dev/null
    
    # Update connector configurations for managed cluster
    $SED_CMD -i "s/<namespace>/$MDM_CONNECTORS_NAMESPACE/g" ./connectors/k8s/src/main/helm/values.yaml
    $SED_CMD -i "s/<clustername>/$OCM_CLUSTER_NAME/g" ./connectors/k8s/src/main/helm/values.yaml
    $SED_CMD -i "s/<namespace>/$MDM_CONNECTORS_NAMESPACE/g" ./connectors/kubescape/src/main/helm/values.yaml
    $SED_CMD -i "s/<clustername>/$OCM_CLUSTER_NAME/g" ./connectors/kubescape/src/main/helm/values.yaml
    $SED_CMD -i "s/<namespace>/$MDM_CONNECTORS_NAMESPACE/g" ./connectors/prometheus/src/main/helm/values.yaml
    $SED_CMD -i "s/<clustername>/$OCM_CLUSTER_NAME/g" ./connectors/prometheus/src/main/helm/values.yaml
    
    # Update MDM API URL to point to hub cluster
    if [[ -n "$MDM_HUB_API_URL" ]]; then
        $SED_CMD -i "s|http://mdm-api.he-codeco-mdm.svc.cluster.local:8090|$MDM_HUB_API_URL|g" \
            ./connectors/k8s/src/main/helm/values.yaml
        $SED_CMD -i "s|http://mdm-api.he-codeco-mdm.svc.cluster.local:8090|$MDM_HUB_API_URL|g" \
            ./connectors/kubescape/src/main/helm/values.yaml
    fi
    
    # Update Prometheus configuration
    $SED_CMD -i "s|http://prometheus-service.monitoring.svc.cluster.local|http://prometheus-agent.$PROMETHEUS_NAMESPACE.svc.cluster.local|g" \
        ./connectors/prometheus/src/main/helm/values.yaml
    $SED_CMD -i "s/9090/9090/g" ./connectors/prometheus/src/main/helm/values.yaml
    
    # Install connectors
    log "Installing K8s connector..."
    helm install k8s-connector -n "$MDM_CONNECTORS_NAMESPACE" --create-namespace \
        ./connectors/k8s/src/main/helm -f ./connectors/k8s/src/main/helm/values.yaml
    
    log "Installing Kubescape connector..."
    helm install kubescape-connector -n "$MDM_CONNECTORS_NAMESPACE" \
        ./connectors/kubescape/src/main/helm -f ./connectors/kubescape/src/main/helm/values.yaml
    
    log "Installing Prometheus connector..."
    helm install prometheus-connector -n "$MDM_CONNECTORS_NAMESPACE" \
        ./connectors/prometheus/src/main/helm -f ./connectors/prometheus/src/main/helm/values.yaml
    
    popd >/dev/null
    
    wait_for_pods "$MDM_CONNECTORS_NAMESPACE" "10m"
    log "MDM connectors installation completed"
}

##############################################################################
# PDLC Installation
##############################################################################

install_pdlc() {
    if [[ "$INSTALL_PDLC" != "true" ]]; then
        log "Skipping PDLC installation"
        return 0
    fi
    
    log "Installing PDLC components..."
    
    # Create namespace
    create_namespace "$PDLC_NAMESPACE"
    
    # Check if PDLC repository exists
    if [[ ! -d "../../pdlc-integration" ]]; then
        error "PDLC integration directory not found. Please ensure repositories are cloned."
        return 1
    fi
    
    pushd "../../pdlc-integration" >/dev/null
    
    # Update configurations for managed cluster
    if [[ ${#WORKER_NODES[@]} -gt 0 ]]; then
        WORKER_NODE_1=${WORKER_NODES[0]}
    else
        WORKER_NODE_1=${CONTROL_PLANE_NODE:-"master"}
    fi
    
    log "Selected worker node for PDLC: $WORKER_NODE_1"
    
    # Update deployment configurations
    $SED_CMD -i "s/sonem-worker/$WORKER_NODE_1/" data_preprocessing/pdlc-dp-deployment.yaml
    $SED_CMD -i "s/test-namespace/$PDLC_NAMESPACE/" data_preprocessing/pdlc-dp-deployment.yaml
    $SED_CMD -i "s/sonem-worker/$WORKER_NODE_1/" context_awareness/pdlc-ca-deployment.yaml
    $SED_CMD -i "s/sonem-worker/$WORKER_NODE_1/" gnn_model/gnn_controller.yaml
    $SED_CMD -i "s/sonem-worker/$WORKER_NODE_1/" gnn_model/gnn_inference.yaml
    $SED_CMD -i "s/sonem-worker/$WORKER_NODE_1/" rl_model/rl-model-deployment.yaml
    $SED_CMD -i "s/sonem/$OCM_CLUSTER_NAME/" data_preprocessing/pdlc-dp-deployment.yaml
    
    # Update MDM API endpoint to point to hub if provided
    if [[ -n "$MDM_HUB_API_URL" ]]; then
        $SED_CMD -i "s|\"http://mdm-controller-service.he-codeco-mdm.svc.cluster.local:5080\"|\"$MDM_HUB_API_URL\"|" \
            data_preprocessing/pdlc-dp-deployment.yaml
    fi
    
    # Apply PDLC configurations
    log "Applying PDLC configurations..."
    chmod +x apply_yamls.sh
    ./apply_yamls.sh
    
    popd >/dev/null
    
    wait_for_pods "$PDLC_NAMESPACE" "15m"
    log "PDLC installation completed"
}

##############################################################################
# QoS Scheduler Installation
##############################################################################

install_qos_scheduler() {
    if [[ "$INSTALL_QOS_SCHEDULER" != "true" ]]; then
        log "Skipping QoS Scheduler installation"
        return 0
    fi
    
    log "Installing QoS Scheduler..."
    
    if [[ ! -d "../../qos-scheduler" ]]; then
        error "QoS Scheduler directory not found. Please ensure repositories are cloned."
        return 1
    fi
    
    pushd "../../qos-scheduler" >/dev/null
    
    # Create namespace
    create_namespace "$QOS_NAMESPACE"
    
    # Check if VERSION file exists for registry approach
    if [[ -f "VERSION" ]]; then
        REGISTRY_PREFIX="hecodeco/swm-"
        VERSION=$(cat VERSION)
        
        log "Installing QoS Scheduler using registry approach (version: $VERSION)..."
        eval "$(docker run --rm "${REGISTRY_PREFIX}chart-dh:${VERSION}" install --release=qos-scheduler-managed)" || {
            error "Failed to install QoS Scheduler using registry approach"
            popd >/dev/null
            return 1
        }
    else
        # Fallback to Helm chart approach
        log "Installing QoS Scheduler using Helm chart..."
        
        if [[ -d "./helm/qos-scheduler" ]]; then
            # Update values for managed cluster
            if [[ -f "./helm/qos-scheduler/values.yaml" ]]; then
                # Disable multus-cni on managed clusters (usually handled by hub)
                yq eval '.multus-cni.enabled = false' -i ./helm/qos-scheduler/values.yaml
                # Set cluster-specific namespace
                yq eval ".global.qosNamespace = \"$QOS_NAMESPACE\"" -i ./helm/qos-scheduler/values.yaml
            fi
            
            # Install using Helm
            helm install qos-scheduler-managed --namespace="$QOS_NAMESPACE" --create-namespace \
                --set multus-cni.enabled=false \
                --set global.qosNamespace="$QOS_NAMESPACE" \
                ./helm/qos-scheduler || {
                error "Failed to install QoS Scheduler using Helm"
                popd >/dev/null
                return 1
            }
        else
            error "QoS Scheduler Helm chart not found"
            popd >/dev/null
            return 1
        fi
    fi
    
    popd >/dev/null
    
    wait_for_pods "$QOS_NAMESPACE" "10m"
    log "QoS Scheduler installation completed"
}

##############################################################################
# Kepler Installation
##############################################################################

install_kepler() {
    if [[ "$INSTALL_KEPLER" != "true" ]]; then
        log "Skipping Kepler installation"
        return 0
    fi
    
    log "Installing Kepler..."
    
    if [[ ! -d "../../kepler" ]]; then
        error "Kepler directory not found. Please ensure repositories are cloned."
        return 1
    fi
    
    pushd "../../kepler" >/dev/null
    
    # Checkout specific version
    git checkout release-0.7.8 2>/dev/null || log "Already on release-0.7.8 or checkout failed"
    
    # Update Makefile for specific image tag
    $SED_CMD -i 's/IMAGE_TAG          ?= latest/export IMAGE_TAG   ?= release-0.7.8/g' Makefile
    
    # Build manifest with Prometheus support
    log "Building Kepler manifest..."
    make build-manifest OPTS="PROMETHEUS_DEPLOY" || {
        error "Failed to build Kepler manifest"
        popd >/dev/null
        return 1
    }
    
    # Deploy Kepler
    log "Deploying Kepler..."
    kubectl create -f _output/generated-manifest/deployment.yaml || {
        error "Failed to deploy Kepler"
        popd >/dev/null
        return 1
    }
    
    popd >/dev/null
    
    # Wait for Kepler to be ready
    wait_for_pods "$KEPLER_NAMESPACE" "10m"
    log "Kepler installation completed"
}

##############################################################################
# Main Installation Flow
##############################################################################

main() {
    log "Starting OCM managed cluster component deployment..."
    log "Target cluster: $OCM_CLUSTER_NAME"
    log "Components to install:"
    log "  - Prometheus Agent: $INSTALL_PROMETHEUS"
    log "  - MDM Connectors: $INSTALL_MDM_CONNECTORS"
    log "  - PDLC: $INSTALL_PDLC"
    log "  - QoS Scheduler: $INSTALL_QOS_SCHEDULER"
    log "  - Kepler: $INSTALL_KEPLER"
    
    # Prerequisites
    check_prerequisites
    gather_cluster_info
    
    # Install components in order
    install_prometheus_agent
    install_mdm_connectors
    install_pdlc
    install_qos_scheduler
    install_kepler
    
    # Final verification
    log "Performing final verification..."
    wait_for_pods "" "30m"
    
    log "Managed Cluster Deployment Summary:"
    log "Cluster: $OCM_CLUSTER_NAME"
    
    if [[ "$INSTALL_PROMETHEUS" == "true" ]]; then
        log "  - Prometheus Agent deployed in namespace: $PROMETHEUS_NAMESPACE"
        kubectl get pods -n "$PROMETHEUS_NAMESPACE" 2>/dev/null || true
    fi
    if [[ "$INSTALL_MDM_CONNECTORS" == "true" ]]; then
        log "  - MDM Connectors deployed in namespace: $MDM_CONNECTORS_NAMESPACE"
        kubectl get pods -n "$MDM_CONNECTORS_NAMESPACE" 2>/dev/null || true
    fi
    if [[ "$INSTALL_PDLC" == "true" ]]; then
        log "  - PDLC deployed in namespace: $PDLC_NAMESPACE"
        kubectl get pods -n "$PDLC_NAMESPACE" 2>/dev/null || true
    fi
    if [[ "$INSTALL_QOS_SCHEDULER" == "true" ]]; then
        log "  - QoS Scheduler deployed in namespace: $QOS_NAMESPACE"
        kubectl get pods -n "$QOS_NAMESPACE" 2>/dev/null || true
    fi
    if [[ "$INSTALL_KEPLER" == "true" ]]; then
        log "  - Kepler deployed in namespace: $KEPLER_NAMESPACE"
        kubectl get pods -n "$KEPLER_NAMESPACE" 2>/dev/null || true
    fi
    
    log "OCM managed cluster component deployment completed successfully!"
}

##############################################################################
# Script Entry Point
##############################################################################

# Create log files
touch "$LOG_FILE" "$ERROR_LOG"

# Trap to cleanup on exit
trap 'log "Script interrupted or completed"' EXIT

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
