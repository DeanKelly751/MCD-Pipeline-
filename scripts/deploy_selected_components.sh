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
# Selective Component Deployment Script
# 
# This script installs and configures only the specified components:
# - MDM (Zookeeper, Kafka, Neo4j, Controller, API)
# - Kepler
# - Kustomize
# - Thanos
# - QoS Scheduler
##############################################################################

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/deployment.log"
ERROR_LOG="${SCRIPT_DIR}/deployment_errors.log"

# Component flags - set to true to install
INSTALL_MDM=${INSTALL_MDM:-true}
INSTALL_KEPLER=${INSTALL_KEPLER:-true}
INSTALL_KUSTOMIZE=${INSTALL_KUSTOMIZE:-true}
INSTALL_THANOS=${INSTALL_THANOS:-true}
INSTALL_QOS_SCHEDULER=${INSTALL_QOS_SCHEDULER:-true}

# Configuration variables
MDM_NAMESPACE="he-codeco-mdm"
THANOS_NAMESPACE="he-codeco-acm"
QOS_NAMESPACE="he-codeco-swm"
PROMETHEUS_URL="http://prometheus-k8s.monitoring.svc.cluster.local"
PROMETHEUS_PORT="9090"

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
    local timeout=${2:-30m}
    
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
    else
        log "Namespace $namespace already exists"
    fi
}

##############################################################################
# Prerequisites and Cluster Information
##############################################################################

gather_cluster_info() {
    log "Gathering cluster information..."
    
    # Detect control plane node
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
    
    log "Control plane node: ${CONTROL_PLANE_NODE:-'Not detected'}"
    log "Worker nodes: ${WORKER_NODES[*]:-'None detected'}"
    log "Current context: $CURRENT_CONTEXT"
}

check_prerequisites() {
    log "Checking prerequisites..."
    
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

setup_storage() {
    log "Setting up storage..."
    
    # Check for existing storage classes
    STORAGE_CLASSES=($(kubectl get storageclass -o jsonpath='{.items[*].metadata.name}' 2>/dev/null))
    log "Available storage classes: ${STORAGE_CLASSES[*]}"
    
    # Select storage class
    if [[ ${#STORAGE_CLASSES[@]} -gt 0 ]]; then
        export STORAGECLASSNAME="${STORAGE_CLASSES[0]}"
    else
        log "No storage classes found, installing local-path provisioner..."
        kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
        export STORAGECLASSNAME="local-path"
        wait_for_pods "local-path-storage"
    fi
    
    log "Using storage class: $STORAGECLASSNAME"
}

##############################################################################
# Kustomize Installation
##############################################################################

install_kustomize() {
    if [[ "$INSTALL_KUSTOMIZE" != "true" ]]; then
        log "Skipping Kustomize installation"
        return 0
    fi
    
    log "Installing Kustomize..."
    
    if command -v kustomize &> /dev/null; then
        log "Kustomize already installed: $(kustomize version --short)"
        return 0
    fi
    
    curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
    sudo mv kustomize /usr/local/bin/ || {
        error "Failed to install Kustomize"
        return 1
    }
    
    log "Kustomize installation completed"
}

##############################################################################
# MDM Components Installation
##############################################################################

install_mdm_components() {
    if [[ "$INSTALL_MDM" != "true" ]]; then
        log "Skipping MDM components installation"
        return 0
    fi
    
    log "Installing MDM components..."
    
    # Create namespace
    create_namespace "$MDM_NAMESPACE"
    
    # Add Helm repositories
    log "Adding Helm repositories for MDM..."
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo add neo4j https://helm.neo4j.com/neo4j
    helm repo update
    
    # Set environment variables for MDM
    export MDM_CONTEXT="$CURRENT_CONTEXT"
    
    # Navigate to mdm-api directory (assuming it exists based on pre_deploy.sh)
    if [[ ! -d "../../mdm-api" ]]; then
        error "MDM API directory not found. Please ensure repositories are cloned."
        return 1
    fi
    
    pushd "../../mdm-api" >/dev/null
    
    # Update storage class in deployment files
    if [[ -f "./deployment/zookeeper-helm.yaml" ]]; then
        $SED_CMD -i "s/<storageclassName>/$STORAGECLASSNAME/g" "./deployment/zookeeper-helm.yaml"
    fi
    if [[ -f "./deployment/neo4j-helm.yaml" ]]; then
        $SED_CMD -i "s/<storageclassName>/$STORAGECLASSNAME/g" "./deployment/neo4j-helm.yaml"
    fi
    if [[ -f "./deployment/kafka-helm.yaml" ]]; then
        $SED_CMD -i "s/<storageclassName>/$STORAGECLASSNAME/g" "./deployment/kafka-helm.yaml"
        
        # Fix deprecated bitnami-shell image
        yq eval '.volumePermissions.image = {
          "registry": "docker.io",
          "repository": "bitnami/os-shell",
          "tag": "11-debian-11-r90"
        }' -i ./deployment/kafka-helm.yaml
    fi
    
    # Install MDM Zookeeper
    log "Installing MDM Zookeeper..."
    helm --kube-context="$MDM_CONTEXT" install mdm-zookeeper -n "$MDM_NAMESPACE" \
        bitnami/zookeeper -f ./deployment/zookeeper-helm.yaml
    
    # Install MDM Kafka
    log "Installing MDM Kafka..."
    helm --kube-context="$MDM_CONTEXT" install mdm-kafka -n "$MDM_NAMESPACE" \
        bitnami/kafka --version 21.1.1 -f ./deployment/kafka-helm.yaml
    
    # Install MDM Neo4j
    log "Installing MDM Neo4j..."
    helm --kube-context="$MDM_CONTEXT" install mdm-neo4j -n "$MDM_NAMESPACE" \
        neo4j/neo4j-standalone -f ./deployment/neo4j-helm.yaml
    
    # Wait for basic components to be ready
    wait_for_pods "$MDM_NAMESPACE" "10m"
    
    # Create Kafka topic
    log "Creating Kafka topic..."
    kubectl --context="$MDM_CONTEXT" -n "$MDM_NAMESPACE" exec -i mdm-kafka-0 -- \
        /opt/bitnami/kafka/bin/kafka-topics.sh \
        --bootstrap-server mdm-kafka-0:9093 \
        --create --topic json-events \
        --config cleanup.policy=compact
    
    # Install MDM Controller
    log "Installing MDM Controller..."
    if [[ -d "./controller/src/helm" ]]; then
        helm --kube-context="$MDM_CONTEXT" -n "$MDM_NAMESPACE" install mdm-controller \
            ./controller/src/helm -f ./controller/src/helm/values.yaml
    else
        error "MDM Controller helm chart not found"
        popd >/dev/null
        return 1
    fi
    
    # Install MDM API
    log "Installing MDM API..."
    if [[ -d "./mdm-api/src/helm" ]]; then
        helm --kube-context="$MDM_CONTEXT" -n "$MDM_NAMESPACE" install mdm-api \
            ./mdm-api/src/helm -f ./mdm-api/src/helm/values.yaml
    else
        error "MDM API helm chart not found"
        popd >/dev/null
        return 1
    fi
    
    popd >/dev/null
    
    # Install MDM Connectors
    if [[ -d "../../mdm-connectors" ]]; then
        log "Installing MDM Connectors..."
        pushd "../../mdm-connectors" >/dev/null
        
        # Update connector configurations
        $SED_CMD -i "s/<namespace>/$MDM_NAMESPACE/g" ./connectors/k8s/src/main/helm/values.yaml
        $SED_CMD -i "s/<clustername>/$MDM_CONTEXT/g" ./connectors/k8s/src/main/helm/values.yaml
        $SED_CMD -i "s/<namespace>/$MDM_NAMESPACE/g" ./connectors/kubescape/src/main/helm/values.yaml
        $SED_CMD -i "s/<clustername>/$MDM_CONTEXT/g" ./connectors/kubescape/src/main/helm/values.yaml
        $SED_CMD -i "s/<namespace>/$MDM_NAMESPACE/g" ./connectors/prometheus/src/main/helm/values.yaml
        $SED_CMD -i "s/<clustername>/$MDM_CONTEXT/g" ./connectors/prometheus/src/main/helm/values.yaml
        
        # Update Prometheus configuration
        $SED_CMD -i "s|http://prometheus-service.monitoring.svc.cluster.local|$PROMETHEUS_URL|g" \
            ./connectors/prometheus/src/main/helm/values.yaml
        $SED_CMD -i "s/9090/$PROMETHEUS_PORT/g" ./connectors/prometheus/src/main/helm/values.yaml
        
        # Install connectors
        helm --kube-context="$MDM_CONTEXT" -n "$MDM_NAMESPACE" install k8s-connector \
            ./connectors/k8s/src/main/helm -f ./connectors/k8s/src/main/helm/values.yaml
        helm --kube-context="$MDM_CONTEXT" -n "$MDM_NAMESPACE" install kubescape-connector \
            ./connectors/kubescape/src/main/helm -f ./connectors/kubescape/src/main/helm/values.yaml
        helm --kube-context="$MDM_CONTEXT" -n "$MDM_NAMESPACE" install freshness-connector \
            ./connectors/prometheus/src/main/helm -f ./connectors/prometheus/src/main/helm/values.yaml
        
        popd >/dev/null
    fi
    
    wait_for_pods "$MDM_NAMESPACE"
    log "MDM components installation completed"
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
    wait_for_pods "kepler"
    log "Kepler installation completed"
}

##############################################################################
# Thanos Installation
##############################################################################

install_thanos() {
    if [[ "$INSTALL_THANOS" != "true" ]]; then
        log "Skipping Thanos installation"
        return 0
    fi
    
    log "Installing Thanos..."
    
    # Create namespace
    create_namespace "$THANOS_NAMESPACE"
    
    # Check if monitoring architecture exists
    if [[ ! -d "../monitoring-architecture/thanos-receiver" ]]; then
        error "Thanos manifests not found in monitoring-architecture"
        return 1
    fi
    
    # Deploy Thanos receiver components
    log "Deploying Thanos receiver..."
    kubectl apply -f ../monitoring-architecture/thanos-receiver/ || {
        error "Failed to deploy Thanos receiver"
        return 1
    }
    
    # Deploy Thanos query if available
    if [[ -f "../monitoring-architecture/thanos-receiver/thanos-query-deployment.yaml" ]]; then
        log "Deploying Thanos query..."
        kubectl apply -f ../monitoring-architecture/thanos-receiver/thanos-query-deployment.yaml
    fi
    
    # Deploy Prometheus agent for Thanos integration
    if [[ -d "../monitoring-architecture/prometheus-agent" ]]; then
        log "Deploying Prometheus agent for Thanos..."
        kubectl apply -f ../monitoring-architecture/prometheus-agent/
    fi
    
    wait_for_pods "$THANOS_NAMESPACE"
    log "Thanos installation completed"
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
        eval "$(docker run --rm "${REGISTRY_PREFIX}chart-dh:${VERSION}" install --release=qos)" || {
            error "Failed to install QoS Scheduler using registry approach"
            popd >/dev/null
            return 1
        }
    else
        # Fallback to Helm chart approach
        log "Installing QoS Scheduler using Helm chart..."
        
        if [[ -d "./helm/qos-scheduler" ]]; then
            # Update values for multus-cni
            if [[ -f "./helm/qos-scheduler/values.yaml" ]]; then
                yq eval '.multus-cni.enabled = false' -i ./helm/qos-scheduler/values.yaml
            fi
            
            # Install using Helm
            helm install qos-scheduler --namespace="$QOS_NAMESPACE" --create-namespace \
                --set multus-cni.enabled=false ./helm/qos-scheduler || {
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
    
    wait_for_pods "$QOS_NAMESPACE"
    log "QoS Scheduler installation completed"
}

##############################################################################
# Main Installation Flow
##############################################################################

main() {
    log "Starting selective component deployment..."
    log "Components to install:"
    log "  - MDM Components: $INSTALL_MDM"
    log "  - Kepler: $INSTALL_KEPLER" 
    log "  - Kustomize: $INSTALL_KUSTOMIZE"
    log "  - Thanos: $INSTALL_THANOS"
    log "  - QoS Scheduler: $INSTALL_QOS_SCHEDULER"
    
    # Prerequisites
    check_prerequisites
    gather_cluster_info
    setup_storage
    
    # Install components in order
    install_kustomize
    install_mdm_components
    install_kepler
    install_thanos
    install_qos_scheduler
    
    # Final verification
    log "Performing final verification..."
    wait_for_pods "" "30m"
    
    log "Deployment Summary:"
    if [[ "$INSTALL_MDM" == "true" ]]; then
        log "  - MDM components deployed in namespace: $MDM_NAMESPACE"
        kubectl get pods -n "$MDM_NAMESPACE" 2>/dev/null || true
    fi
    if [[ "$INSTALL_KEPLER" == "true" ]]; then
        log "  - Kepler deployed in namespace: kepler"
        kubectl get pods -n kepler 2>/dev/null || true
    fi
    if [[ "$INSTALL_THANOS" == "true" ]]; then
        log "  - Thanos deployed in namespace: $THANOS_NAMESPACE"
        kubectl get pods -n "$THANOS_NAMESPACE" 2>/dev/null || true
    fi
    if [[ "$INSTALL_QOS_SCHEDULER" == "true" ]]; then
        log "  - QoS Scheduler deployed in namespace: $QOS_NAMESPACE"
        kubectl get pods -n "$QOS_NAMESPACE" 2>/dev/null || true
    fi
    
    log "Selective component deployment completed successfully!"
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
