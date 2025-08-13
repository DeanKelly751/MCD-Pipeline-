#!/bin/bash

# Extract YAML from Helm charts for policy generation
# Usage: ./extract-helm-yaml.sh "mdm,kepler,qos,pdlc,prometheus"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="${SCRIPT_DIR}/../manifests"
EXTRACTED_DIR="${MANIFESTS_DIR}/extracted-yaml"

# Component list from input
COMPONENTS=${1:-"mdm,kepler,qos,pdlc,prometheus"}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[ERROR] [$(date '+%Y-%m-%d %H:%M:%S')] $1" >&2
}

# Create output directories
mkdir -p "$EXTRACTED_DIR"/{hub,managed}

extract_mdm_yaml() {
    log "Extracting MDM component YAML..."
    
    if [[ ! -d "../../mdm-api" ]]; then
        error "MDM API directory not found"
        return 1
    fi
    
    pushd "../../mdm-api" >/dev/null
    
    # Extract MDM API Helm chart
    if [[ -d "mdm-api/src/helm" ]]; then
        helm template mdm-api ./mdm-api/src/helm \
            --set image.tag=latest \
            --set service.type=ClusterIP \
            --namespace he-codeco-mdm > "${EXTRACTED_DIR}/hub/mdm-api.yaml"
    fi
    
    # Extract MDM Controller Helm chart  
    if [[ -d "controller/src/helm" ]]; then
        helm template mdm-controller ./controller/src/helm \
            --set image.tag=latest \
            --namespace he-codeco-mdm > "${EXTRACTED_DIR}/hub/mdm-controller.yaml"
    fi
    
    popd >/dev/null
    
    # Extract MDM Connectors for managed clusters
    if [[ -d "../../mdm-connectors" ]]; then
        pushd "../../mdm-connectors" >/dev/null
        
        # K8s Connector
        if [[ -d "connectors/k8s/src/main/helm" ]]; then
            helm template mdm-k8s-connector ./connectors/k8s/src/main/helm \
                --set image.tag=latest \
                --namespace he-codeco-mdm > "${EXTRACTED_DIR}/managed/mdm-k8s-connector.yaml"
        fi
        
        # Prometheus Connector
        if [[ -d "connectors/prometheus/src/main/helm" ]]; then
            helm template mdm-prometheus-connector ./connectors/prometheus/src/main/helm \
                --set image.tag=latest \
                --namespace he-codeco-mdm > "${EXTRACTED_DIR}/managed/mdm-prometheus-connector.yaml"
        fi
        
        # Kubescape Connector
        if [[ -d "connectors/kubescape/src/main/helm" ]]; then
            helm template mdm-kubescape-connector ./connectors/kubescape/src/main/helm \
                --set image.tag=latest \
                --namespace he-codeco-mdm > "${EXTRACTED_DIR}/managed/mdm-kubescape-connector.yaml"
        fi
        
        popd >/dev/null
    fi
    
    log "✅ MDM YAML extraction completed"
}

extract_qos_yaml() {
    log "Extracting QoS Scheduler YAML..."
    
    if [[ ! -d "../../qos-scheduler" ]]; then
        error "QoS Scheduler directory not found"
        return 1
    fi
    
    pushd "../../qos-scheduler" >/dev/null
    
    # Extract QoS Scheduler Helm chart for hub (policies only)
    if [[ -d "helm/qos-scheduler" ]]; then
        # Hub components (CRDs and policies)
        helm template qos-scheduler-hub ./helm/qos-scheduler \
            --set scheduler.enabled=false \
            --set controller.enabled=false \
            --set qos-crds.enabled=true \
            --set l2sm-crds.enabled=true \
            --set monc-crds.enabled=true \
            --namespace he-codeco-swm > "${EXTRACTED_DIR}/hub/qos-scheduler-crds.yaml"
            
        # Managed cluster components
        helm template qos-scheduler-managed ./helm/qos-scheduler \
            --set scheduler.enabled=true \
            --set controller.enabled=true \
            --set nodedaemon.enabled=true \
            --set network.enabled=true \
            --set qos-crds.enabled=false \
            --set l2sm-crds.enabled=false \
            --set monc-crds.enabled=false \
            --namespace he-codeco-swm > "${EXTRACTED_DIR}/managed/qos-scheduler.yaml"
    fi
    
    popd >/dev/null
    
    log "✅ QoS Scheduler YAML extraction completed"
}

extract_kepler_yaml() {
    log "Extracting Kepler YAML..."
    
    if [[ ! -d "../../kepler" ]]; then
        error "Kepler directory not found"
        return 1
    fi
    
    pushd "../../kepler" >/dev/null
    
    # Checkout specific version
    git checkout release-0.7.8 2>/dev/null || log "Already on release-0.7.8"
    
    # Build Kepler manifest
    make build-manifest OPTS="PROMETHEUS_DEPLOY" || {
        error "Failed to build Kepler manifest"
        popd >/dev/null
        return 1
    }
    
    # Copy generated manifest
    if [[ -f "_output/generated-manifest/deployment.yaml" ]]; then
        cp "_output/generated-manifest/deployment.yaml" "${EXTRACTED_DIR}/managed/kepler.yaml"
    fi
    
    popd >/dev/null
    
    log "✅ Kepler YAML extraction completed"
}

extract_pdlc_yaml() {
    log "Extracting PDLC YAML..."
    
    if [[ ! -d "../../pdlc-integration" ]]; then
        error "PDLC integration directory not found"
        return 1
    fi
    
    pushd "../../pdlc-integration" >/dev/null
    
    # Combine all PDLC YAML files
    cat > "${EXTRACTED_DIR}/managed/pdlc.yaml" << 'EOF'
# PDLC Components - Combined YAML
EOF
    
    # Add each component
    for component in data_preprocessing context_awareness gnn_model rl_model volume; do
        if [[ -d "$component" ]]; then
            echo "---" >> "${EXTRACTED_DIR}/managed/pdlc.yaml"
            echo "# $component components" >> "${EXTRACTED_DIR}/managed/pdlc.yaml"
            find "$component" -name "*.yaml" -exec cat {} \; >> "${EXTRACTED_DIR}/managed/pdlc.yaml"
            echo "" >> "${EXTRACTED_DIR}/managed/pdlc.yaml"
        fi
    done
    
    popd >/dev/null
    
    log "✅ PDLC YAML extraction completed"
}

extract_prometheus_yaml() {
    log "Extracting Prometheus YAML..."
    
    if [[ ! -d "../../kube-prometheus" ]]; then
        error "Kube-prometheus directory not found"
        return 1
    fi
    
    pushd "../../kube-prometheus" >/dev/null
    
    # Build kube-prometheus manifests
    make generate || {
        error "Failed to generate kube-prometheus manifests"
        popd >/dev/null
        return 1
    }
    
    # Hub components (full Prometheus stack)
    if [[ -d "manifests" ]]; then
        # Combine relevant hub manifests
        cat manifests/prometheus-*.yaml > "${EXTRACTED_DIR}/hub/prometheus-hub.yaml" 2>/dev/null || true
        cat manifests/alertmanager-*.yaml >> "${EXTRACTED_DIR}/hub/prometheus-hub.yaml" 2>/dev/null || true
        cat manifests/grafana-*.yaml >> "${EXTRACTED_DIR}/hub/prometheus-hub.yaml" 2>/dev/null || true
    fi
    
    # Managed cluster components (Prometheus agent)
    cat > "${EXTRACTED_DIR}/managed/prometheus-agent.yaml" << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-agent-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
      external_labels:
        cluster: 'managed-cluster'
    
    remote_write:
    - url: "http://thanos-receive-router.he-codeco-acm.svc.cluster.local:19291/api/v1/receive"
      queue_config:
        max_samples_per_send: 1000
        max_shards: 200
        capacity: 2500
    
    scrape_configs:
    - job_name: 'kubernetes-apiservers'
      kubernetes_sd_configs:
      - role: endpoints
      scheme: https
      tls_config:
        ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
      bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
      relabel_configs:
      - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
        action: keep
        regex: default;kubernetes;https
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus-agent
  namespace: monitoring
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
      containers:
      - name: prometheus
        image: prom/prometheus:v2.45.0
        args:
        - '--config.file=/etc/prometheus/prometheus.yml'
        - '--storage.tsdb.path=/prometheus/'
        - '--web.console.libraries=/etc/prometheus/console_libraries'
        - '--web.console.templates=/etc/prometheus/consoles'
        - '--web.enable-lifecycle'
        - '--enable-feature=agent'
        ports:
        - containerPort: 9090
        volumeMounts:
        - name: prometheus-config-volume
          mountPath: /etc/prometheus/
        - name: prometheus-storage-volume
          mountPath: /prometheus/
      volumes:
      - name: prometheus-config-volume
        configMap:
          defaultMode: 420
          name: prometheus-agent-config
      - name: prometheus-storage-volume
        emptyDir: {}
EOF
    
    popd >/dev/null
    
    log "✅ Prometheus YAML extraction completed"
}

# Main execution
main() {
    log "Starting Helm YAML extraction for components: $COMPONENTS"
    
    # Parse components
    IFS=',' read -ra COMPONENT_ARRAY <<< "$COMPONENTS"
    
    for component in "${COMPONENT_ARRAY[@]}"; do
        component=$(echo "$component" | xargs) # trim whitespace
        case "$component" in
            "mdm")
                extract_mdm_yaml
                ;;
            "qos")
                extract_qos_yaml
                ;;
            "kepler")
                extract_kepler_yaml
                ;;
            "pdlc")
                extract_pdlc_yaml
                ;;
            "prometheus")
                extract_prometheus_yaml
                ;;
            *)
                error "Unknown component: $component"
                ;;
        esac
    done
    
    log "✅ All YAML extraction completed"
    log "Extracted files:"
    find "$EXTRACTED_DIR" -name "*.yaml" -type f | sort
}

# Execute main function
main "$@"
