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
# 
# Contributors:
#     [name] - [contribution]

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
clone_if_not_exists "https://gitlab.eclipse.org/eclipse-research-labs/codeco-project/network-management-and-adaptation-netma/network-exposure.git" "network-exposure"

clone_if_not_exists "https://github.com/k8snetworkplumbingwg/multus-cni.git" "multus-cni"
# clone_if_not_exists "https://gitlab.eclipse.org/eclipse-research-labs/codeco-project/experimentation-framework-and-demonstrations/data-generators-and-datasets/synthetic-data-generator.git" "synthetic-data-generator"
clone_if_not_exists "https://github.com/prometheus-operator/kube-prometheus" "kube-prometheus"
clone_if_not_exists "https://github.com/sustainable-computing-io/kepler" "kepler"

##TODO(user): Add your dependencies here
