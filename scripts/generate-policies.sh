#!/bin/bash

# Generate OCM policies from extracted YAML manifests
# Usage: ./generate-policies.sh "mdm,kepler,qos,pdlc,prometheus"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="${SCRIPT_DIR}/../manifests"
EXTRACTED_DIR="${MANIFESTS_DIR}/extracted-yaml"
POLICIES_DIR="${MANIFESTS_DIR}/policies"

# Component list from input
COMPONENTS=${1:-"mdm,kepler,qos,pdlc,prometheus"}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[ERROR] [$(date '+%Y-%m-%d %H:%M:%S')] $1" >&2
}

# Create output directories
mkdir -p "$POLICIES_DIR"/{hub,managed}

create_policy_generator_config() {
    local component=$1
    local target=$2  # hub or managed
    local yaml_file=$3
    
    cat > "${POLICIES_DIR}/${target}/policy-generator-${component}.yaml" << EOF
apiVersion: policy.open-cluster-management.io/v1
kind: PolicyGenerator
metadata:
  name: ${component}-${target}-policy-generator
placementBindingDefaults:
  name: ${component}-${target}-placement-binding
policyDefaults:
  categories:
    - CM Configuration Management
  controls:
    - CM-2 Baseline Configuration
  namespace: open-cluster-management-global-set
  policySets:
    - sxm-${target}-components
  remediationAction: enforce
  severity: medium
  standards:
    - NIST SP 800-53
policies:
- name: ${component}-${target}-policy
  manifests:
  - path: ../../extracted-yaml/${target}/${component}.yaml
EOF
}

create_placement_rule() {
    local target=$1
    
    if [[ "$target" == "hub" ]]; then
        cat > "${POLICIES_DIR}/hub/hub-placement.yaml" << 'EOF'
apiVersion: cluster.open-cluster-management.io/v1beta1
kind: Placement
metadata:
  name: hub-placement
  namespace: open-cluster-management-global-set
spec:
  predicates:
  - requiredClusterSelector:
      labelSelector:
        matchLabels:
          local-cluster: "true"
---
apiVersion: policy.open-cluster-management.io/v1
kind: PlacementBinding
metadata:
  name: hub-components-placement-binding
  namespace: open-cluster-management-global-set
placementRef:
  name: hub-placement
  kind: Placement
  apiGroup: cluster.open-cluster-management.io
subjects:
- name: sxm-hub-components
  kind: PolicySet
  apiGroup: policy.open-cluster-management.io
EOF
    else
        cat > "${POLICIES_DIR}/managed/managed-placement.yaml" << 'EOF'
apiVersion: cluster.open-cluster-management.io/v1beta1
kind: Placement
metadata:
  name: managed-clusters-placement
  namespace: open-cluster-management-global-set
spec:
  predicates:
  - requiredClusterSelector:
      labelSelector:
        matchExpressions:
        - key: local-cluster
          operator: NotIn
          values: ["true"]
---
apiVersion: policy.open-cluster-management.io/v1
kind: PlacementBinding
metadata:
  name: managed-components-placement-binding
  namespace: open-cluster-management-global-set
placementRef:
  name: managed-clusters-placement
  kind: Placement
  apiGroup: cluster.open-cluster-management.io
subjects:
- name: sxm-managed-components
  kind: PolicySet
  apiGroup: policy.open-cluster-management.io
EOF
    fi
}

create_policy_set() {
    local target=$1
    local components_list=$2
    
    cat > "${POLICIES_DIR}/${target}/policy-set-${target}.yaml" << EOF
apiVersion: policy.open-cluster-management.io/v1beta1
kind: PolicySet
metadata:
  name: sxm-${target}-components
  namespace: open-cluster-management-global-set
spec:
  description: SxM components for ${target} clusters
  policies:
EOF
    
    # Add each component policy to the set
    IFS=',' read -ra COMPONENT_ARRAY <<< "$components_list"
    for component in "${COMPONENT_ARRAY[@]}"; do
        component=$(echo "$component" | xargs)
        
        # Check if YAML file exists for this target
        yaml_file="${EXTRACTED_DIR}/${target}/${component}.yaml"
        if [[ -f "$yaml_file" ]] || [[ -f "${EXTRACTED_DIR}/${target}/${component}-"*.yaml ]]; then
            echo "  - ${component}-${target}-policy" >> "${POLICIES_DIR}/${target}/policy-set-${target}.yaml"
        fi
    done
}

generate_individual_policies() {
    local target=$1
    local components_list=$2
    
    log "Generating individual policies for ${target} components..."
    
    IFS=',' read -ra COMPONENT_ARRAY <<< "$components_list"
    for component in "${COMPONENT_ARRAY[@]}"; do
        component=$(echo "$component" | xargs)
        
        # Find YAML files for this component and target
        yaml_files=($(find "${EXTRACTED_DIR}/${target}" -name "${component}*.yaml" 2>/dev/null || true))
        
        if [[ ${#yaml_files[@]} -eq 0 ]]; then
            log "No YAML files found for ${component} in ${target}, skipping..."
            continue
        fi
        
        log "Creating policy for ${component} (${target})"
        
        # Use the first matching file
        yaml_file="${yaml_files[0]}"
        relative_path="../../extracted-yaml/${target}/$(basename "$yaml_file")"
        
        # Create policy using policy generator config
        cat > "${POLICIES_DIR}/${target}/${component}-policy.yaml" << EOF
apiVersion: policy.open-cluster-management.io/v1
kind: Policy
metadata:
  name: ${component}-${target}-policy
  namespace: open-cluster-management-global-set
  annotations:
    policy.open-cluster-management.io/standards: NIST SP 800-53
    policy.open-cluster-management.io/categories: CM Configuration Management
    policy.open-cluster-management.io/controls: CM-2 Baseline Configuration
spec:
  remediationAction: enforce
  disabled: false
  policy-templates:
  - objectDefinition:
      apiVersion: policy.open-cluster-management.io/v1
      kind: ConfigurationPolicy
      metadata:
        name: ${component}-${target}-config
      spec:
        remediationAction: enforce
        severity: medium
        object-templates-raw: |
$(sed 's/^/          /' "$yaml_file")
EOF
    done
}

generate_namespace_policy() {
    local target=$1
    
    # Create namespace policy for each target
    cat > "${POLICIES_DIR}/${target}/namespace-policy.yaml" << EOF
apiVersion: policy.open-cluster-management.io/v1
kind: Policy
metadata:
  name: sxm-namespaces-${target}-policy
  namespace: open-cluster-management-global-set
  annotations:
    policy.open-cluster-management.io/standards: NIST SP 800-53
    policy.open-cluster-management.io/categories: CM Configuration Management
    policy.open-cluster-management.io/controls: CM-2 Baseline Configuration
spec:
  remediationAction: enforce
  disabled: false
  policy-templates:
  - objectDefinition:
      apiVersion: policy.open-cluster-management.io/v1
      kind: ConfigurationPolicy
      metadata:
        name: sxm-namespaces-${target}-config
      spec:
        remediationAction: enforce
        severity: low
        object-templates:
        - complianceType: musthave
          objectDefinition:
            apiVersion: v1
            kind: Namespace
            metadata:
              name: he-codeco-mdm
              labels:
                name: he-codeco-mdm
        - complianceType: musthave
          objectDefinition:
            apiVersion: v1
            kind: Namespace
            metadata:
              name: he-codeco-acm
              labels:
                name: he-codeco-acm
        - complianceType: musthave
          objectDefinition:
            apiVersion: v1
            kind: Namespace
            metadata:
              name: he-codeco-swm
              labels:
                name: he-codeco-swm
        - complianceType: musthave
          objectDefinition:
            apiVersion: v1
            kind: Namespace
            metadata:
              name: he-codeco-pdlc
              labels:
                name: he-codeco-pdlc
        - complianceType: musthave
          objectDefinition:
            apiVersion: v1
            kind: Namespace
            metadata:
              name: monitoring
              labels:
                name: monitoring
        - complianceType: musthave
          objectDefinition:
            apiVersion: v1
            kind: Namespace
            metadata:
              name: kepler
              labels:
                name: kepler
EOF
}

# Main execution
main() {
    log "Starting OCM policy generation for components: $COMPONENTS"
    
    # Check if extracted YAML exists
    if [[ ! -d "$EXTRACTED_DIR" ]]; then
        error "Extracted YAML directory not found: $EXTRACTED_DIR"
        error "Please run extract-helm-yaml.sh first"
        exit 1
    fi
    
    # Generate policies for hub components
    if [[ -d "${EXTRACTED_DIR}/hub" ]] && [[ -n "$(ls -A "${EXTRACTED_DIR}/hub" 2>/dev/null)" ]]; then
        log "Generating hub component policies..."
        
        # Get components that have hub YAML files
        hub_components=""
        IFS=',' read -ra COMPONENT_ARRAY <<< "$COMPONENTS"
        for component in "${COMPONENT_ARRAY[@]}"; do
            component=$(echo "$component" | xargs)
            if find "${EXTRACTED_DIR}/hub" -name "${component}*.yaml" -type f | grep -q .; then
                if [[ -n "$hub_components" ]]; then
                    hub_components="${hub_components},${component}"
                else
                    hub_components="$component"
                fi
            fi
        done
        
        if [[ -n "$hub_components" ]]; then
            generate_individual_policies "hub" "$hub_components"
            create_policy_set "hub" "$hub_components"
            create_placement_rule "hub"
            generate_namespace_policy "hub"
        fi
    fi
    
    # Generate policies for managed components
    if [[ -d "${EXTRACTED_DIR}/managed" ]] && [[ -n "$(ls -A "${EXTRACTED_DIR}/managed" 2>/dev/null)" ]]; then
        log "Generating managed component policies..."
        
        # Get components that have managed YAML files
        managed_components=""
        IFS=',' read -ra COMPONENT_ARRAY <<< "$COMPONENTS"
        for component in "${COMPONENT_ARRAY[@]}"; do
            component=$(echo "$component" | xargs)
            if find "${EXTRACTED_DIR}/managed" -name "${component}*.yaml" -type f | grep -q .; then
                if [[ -n "$managed_components" ]]; then
                    managed_components="${managed_components},${component}"
                else
                    managed_components="$component"
                fi
            fi
        done
        
        if [[ -n "$managed_components" ]]; then
            generate_individual_policies "managed" "$managed_components"
            create_policy_set "managed" "$managed_components"
            create_placement_rule "managed"
            generate_namespace_policy "managed"
        fi
    fi
    
    log "✅ OCM policy generation completed"
    log "Generated policies:"
    find "$POLICIES_DIR" -name "*.yaml" -type f | sort
}

# Execute main function
main "$@"
