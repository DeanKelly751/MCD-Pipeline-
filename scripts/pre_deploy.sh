#!/bin/bash

## This script is executed before the CODECO operator deployment starts. It is used to install dependencies or
## other components' dependencies

# Function to clone repository if not already present
clone_if_not_exists() {
    local repo_url=$1
    local target_dir=$2

    if [ ! -d "$target_dir" ]; then
        git clone "$repo_url" "$target_dir"
    else
        echo "Directory $target_dir already exists. Skipping cloning."
    fi
}

# Create Kubernetes cluster
# kind create cluster --config ./config/cluster/kind-config.yaml

cd ..

# Clone repositories if not already present
clone_if_not_exists "https://gitlab.eclipse.org/eclipse-research-labs/codeco-project/scheduling-and-workload-migration-swm/qos-scheduler.git" "qos-scheduler"
clone_if_not_exists "https://gitlab.eclipse.org/eclipse-research-labs/codeco-project/metadata-manager-mdm/mdm-api.git" "mdm-api"
clone_if_not_exists "https://gitlab.eclipse.org/eclipse-research-labs/codeco-project/metadata-manager-mdm/connectors.git" "mdm-connectors"
clone_if_not_exists "https://gitlab.eclipse.org/eclipse-research-labs/codeco-project/privacy-preserving-decentralised-learning-and-context-awareness-pdlc/pdlc-integration.git" "pdlc-integration"
clone_if_not_exists "https://gitlab.eclipse.org/eclipse-research-labs/codeco-project/network-management-and-adaptation-netma/secure-connectivity.git" "secure-connectivity"
# clone_if_not_exists "https://gitlab.eclipse.org/eclipse-research-labs/codeco-project/network-management-and-adaptation-netma/network-exposure.git" "network-exposure"

clone_if_not_exists "https://github.com/k8snetworkplumbingwg/multus-cni.git" "multus-cni"
# clone_if_not_exists "https://gitlab.eclipse.org/eclipse-research-labs/codeco-project/experimentation-framework-and-demonstrations/data-generators-and-datasets/synthetic-data-generator.git" "synthetic-data-generator"
clone_if_not_exists "https://github.com/prometheus-operator/kube-prometheus" "kube-prometheus"
clone_if_not_exists "https://github.com/sustainable-computing-io/kepler" "kepler"

##TODO(user): Add your dependencies here
