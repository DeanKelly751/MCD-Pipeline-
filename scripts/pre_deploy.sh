#!/bin/bash
## This script is executed before the CODECO operator deployment starts. It is used to install dependencies or
## other components' dependencies
sudo kind create cluster --config kind-config.yaml
git clone https://gitlab.eclipse.org/eclipse-research-labs/codeco-project/scheduling-and-workload-migration-swm/qos-scheduler.git
git clone https://gitlab.eclipse.org/eclipse-research-labs/codeco-project/metadata-manager-mdm/mdm-api.git
git clone https://gitlab.eclipse.org/eclipse-research-labs/codeco-project/privacy-preserving-decentralised-learning-and-context-awareness-pdlc/context-awareness/pdlc-pp.git
git clone https://gitlab.eclipse.org/eclipse-research-labs/codeco-project/network-management-and-adaptation-netma/secure-connectivity.git
git clone https://github.com/k8snetworkplumbingwg/multus-cni.git
##TODO(user): Add your dependencies here
