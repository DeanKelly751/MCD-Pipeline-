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
## This script is executed after the CODECO operator deployment finishes. It is used to install additional
## components and to perform any other post-deployment tasks.
echo "Executing post deployment tasks..."
##TODO(user): Add your post deployment tasks here
echo "........................................ GETTING CLUSTER INFORMATION ..............................................."
# This will get node names to avoid hardcoding variables 

# Different Kubernetes platforms use different labes to indicate the master node. Here are some:
control_plane_labels=(
    "node-role.kubernetes.io/master"
    "node-role.kubernetes.io/control-plane"
    "node.kubernetes.io/role=master"
    "node.kubernetes.io/microk8s-controlplane"
)

# Get the Master node and a list with the Worker nodes of the cluster
for label in "${control_plane_labels[@]}"; do
    CONTROL_PLANE_NODE=$(kubectl get nodes -o custom-columns=NAME:.metadata.name --no-headers -l "$label")
    if [ -n "$CONTROL_PLANE_NODE" ]; then
        WORKER_NODES=($(kubectl get nodes -o custom-columns=NAME:.metadata.name --no-headers -l "!$label"))
        break
    fi
done

if [ -z "$CONTROL_PLANE_NODE" ]; then
    echo "WARNING: No Master Node detected"
    WORKER_NODES=($(kubectl get nodes -o custom-columns=NAME:.metadata.name --no-headers))
fi

# Kubectl context is used by the MDM component
CURRENT_CONTEXT=$(kubectl config current-context)

# Adding node labels - used by SWM
export NODE_LABEL_PREFIX=siemens.com.qosscheduler
for n in $(kubectl get no -o jsonpath="{.items[*].metadata.name}")
do
  kubectl label --overwrite nodes "${n}" "${NODE_LABEL_PREFIX}.${n}="
done

echo "........................................Kustomize Installing..............................................."

curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash

echo "........................................Kustomize Install Finished..............................................."

echo "........................................Prometheus Installing..............................................."
cd ..
cd kube-prometheus
kubectl apply --server-side -f manifests/setup
kubectl wait \
	--for condition=Established \
	--all CustomResourceDefinition \
	--namespace=monitoring
kubectl apply -f manifests/
cd ..
echo "........................................Prometheus Installed..............................................."
echo "........................................Installing Primary CNI: Flannel..............................................."

## Following bundle of commands should be required only for KinD - to be verified
# Download binaries for CNI Plugins
mkdir -p plugins/bin
wget https://github.com/containernetworking/plugins/releases/download/v1.6.0/cni-plugins-linux-amd64-v1.6.0.tgz
tar -xf cni-plugins-linux-amd64-v1.6.0.tgz -C ./plugins/bin
# copy necessary plugins into all nodes
docker cp ./plugins/bin/. kind-control-plane:/opt/cni/bin
docker cp ./plugins/bin/. kind-worker:/opt/cni/bin
docker cp ./plugins/bin/. kind-worker2:/opt/cni/bin
# fix by Alex UC3M
docker exec -it kind-control-plane modprobe br_netfilter
docker exec -it kind-worker modprobe br_netfilter
docker exec -it kind-worker2 modprobe br_netfilter
# fix
docker exec -it kind-control-plane sysctl -p /etc/sysctl.conf
docker exec -it kind-worker sysctl -p /etc/sysctl.conf
docker exec -it kind-worker2 sysctl -p /etc/sysctl.conf
# File limit workaround
docker exec -it kind-control-plane bash -c "sysctl -w fs.inotify.max_user_watches=2099999999; sysctl -w fs.inotify.max_user_instances=2099999999; sysctl -w fs.inotify.max_queued_events=2099999999"
docker exec -it kind-worker bash -c "sysctl -w fs.inotify.max_user_watches=2099999999; sysctl -w fs.inotify.max_user_instances=2099999999; sysctl -w fs.inotify.max_queued_events=2099999999"
docker exec -it kind-worker2 bash -c "sysctl -w fs.inotify.max_user_watches=2099999999; sysctl -w fs.inotify.max_user_instances=2099999999; sysctl -w fs.inotify.max_queued_events=2099999999"
sysctl -w fs.inotify.max_user_watches=2099999999
sysctl -w fs.inotify.max_user_instances=2099999999
sysctl -w fs.inotify.max_queued_events=2099999999


kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml 
sleep 20

echo "........................................Installing NetMA..............................................."
cd secure-connectivity
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.3/cert-manager.yaml
kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset-thick.yml
# Just in case the previous Prometheus instalation does not include the coreos monitoring CRDs.
# helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
# helm repo update
# helm install prometheus-operator prometheus-community/kube-prometheus-stack -n he-codeco-netma

kubectl taint nodes $CONTROL_PLANE_NODE node-role.kubernetes.io/control-plane:NoSchedule-
# kubectl taint nodes --all node-role.kubernetes.io/control-plane- node-role.kubernetes.io/master-
# kubectl create namespace he-codeco-netma
# kubectl get nodes

kubectl wait --for=condition=Ready pod --all -A --timeout=20m # wait until everything is running before we continue
kubectl create -f ./deployments/l2sm-deployment.yaml -n=he-codeco-netma

# Fix by Alejandro de Cock Buning for proper l2sm function
kubectl wait --for=condition=Ready pod --all -A --timeout=20m
kubectl apply -f ../network-exposure/kuberfiles/00_namespace.yaml
chmod +x ../acm/scripts/after_netma_deployment.sh
../acm/scripts/after_netma_deployment.sh

cd ..

cd network-exposure/
kubectl apply -f kuberfiles/00_namespace.yaml
kubectl wait --for=condition=Ready pod --all -A --timeout=20m
kubectl apply -f kuberfiles/01_netma-topology-crd.yaml
cd ..

cd network-state-management/netma-nsm-mon/k8s-netperf
kubectl apply -f k8s-netperf.yaml
cd ../../..

kubectl apply -f network-exposure/kuberfiles/02_nemesys-deployment.yaml

kubectl wait --for=condition=Ready pod --all -n he-codeco-netma --timeout=20m

## The next command is to check that the CR has been pushed correctly 
## kubectl get netma-topology netma-sample -o yaml -n he-codeco-netma
echo "........................................Finished installing NetMA..............................................."
echo ".....................Installing MDM....................................."
cd mdm-api
export STORAGECLASSNAME=standard
export MDM_NAMESPACE=he-codeco-mdm
export MDM_CONTEXT=$CURRENT_CONTEXT
export PROMETHEUS_URL="http://prometheus-k8s.monitoring.svc.cluster.local"
export PROMETHEUS_PORT="9090"
kubectl --context=$MDM_CONTEXT create namespace $MDM_NAMESPACE
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add neo4j https://helm.neo4j.com/neo4j
sed -i "s/<storageclassName>/$STORAGECLASSNAME/g" "./deployment/zookeeper-helm.yaml"
sed -i "s/<storageclassName>/$STORAGECLASSNAME/g" "./deployment/neo4j-helm.yaml"
sed -i "s/<storageclassName>/$STORAGECLASSNAME/g" "./deployment/kafka-helm.yaml"
helm --kube-context=$MDM_CONTEXT install mdm-zookeeper -n $MDM_NAMESPACE  bitnami/zookeeper  -f ./deployment/zookeeper-helm.yaml
helm --kube-context=$MDM_CONTEXT install mdm-kafka -n $MDM_NAMESPACE bitnami/kafka --version 21.1.1 -f ./deployment/kafka-helm.yaml
helm --kube-context=$MDM_CONTEXT install mdm-neo4j -n $MDM_NAMESPACE neo4j/neo4j-standalone -f ./deployment/neo4j-helm.yaml
kubectl --context=$MDM_CONTEXT -n $MDM_NAMESPACE exec -i mdm-kafka-0 -- /opt/bitnami/kafka/bin/kafka-topics.sh --bootstrap-server mdm-kafka-0:9093 --create --topic json-events --config cleanup.policy=compact
helm --kube-context=$MDM_CONTEXT -n $MDM_NAMESPACE install mdm-controller ./controller/src/helm -f ./controller/src/helm/values.yaml
helm --kube-context=$MDM_CONTEXT -n $MDM_NAMESPACE install mdm-api ./mdm-api/src/helm -f ./mdm-api/src/helm/values.yaml
# MDM update
cd ..
cd mdm-connectors
sed -i "s/<namespace>/$MDM_NAMESPACE/g" ./connectors/k8s/src/main/helm/values.yaml
sed -i "s/<clustername>/$MDM_CONTEXT/g" ./connectors/k8s/src/main/helm/values.yaml
sed -i "s/<namespace>/$MDM_NAMESPACE/g" ./connectors/kubescape/src/main/helm/values.yaml
sed -i "s/<clustername>/$MDM_CONTEXT/g" ./connectors/kubescape/src/main/helm/values.yaml
sed -i "s/<namespace>/$MDM_NAMESPACE/g" ./connectors/prometheus/src/main/helm/values.yaml
sed -i "s/<clustername>/$MDM_CONTEXT/g" ./connectors/prometheus/src/main/helm/values.yaml
# Prometheus config set the Prometheus url to $PROMETHEUS_URL
# Prometheus config set the Prometheus port to $PROMETHEUS_PORT
sed -i "s|http://prometheus-service.monitoring.svc.cluster.local|$PROMETHEUS_URL|g" ./connectors/prometheus/src/main/helm/values.yaml
sed -i "s/9090/$PROMETHEUS_PORT/g" ./connectors/prometheus/src/main/helm/values.yaml
helm --kube-context=$MDM_CONTEXT -n $MDM_NAMESPACE install k8s-connector ./connectors/k8s/src/main/helm -f ./connectors/k8s/src/main/helm/values.yaml 
helm --kube-context=$MDM_CONTEXT -n $MDM_NAMESPACE install kubescape-connector ./connectors/kubescape/src/main/helm -f ./connectors/kubescape/src/main/helm/values.yaml 
helm --kube-context=$MDM_CONTEXT -n $MDM_NAMESPACE install freshness-connector ./connectors/prometheus/src/main/helm -f ./connectors/prometheus/src/main/helm/values.yaml

kubectl wait --for=condition=Ready pod --all -A --timeout=20m
cd ..
echo "........................................Finished installing MDM..............................................."
# export POD_NAME=$(sudo kubectl get pods --namespace mdm -l "app.kubernetes.io/name=mdm-api,app.kubernetes.io/instance=mdm-api" -o jsonpath="{.items[0].metadata.name}")
# export CONTAINER_PORT=$(sudo kubectl get pod --namespace mdm $POD_NAME -o jsonpath="{.spec.containers[0].ports[0].containerPort}")
# sudo kubectl get all -n codecoapp-operator-system
# sudo kubectl get nodes
# sudo kubectl get networklinks -A
# sudo kubectl get networkpaths -A
# sudo kubectl --namespace mdm port-forward $POD_NAME 9092:$CONTAINER_PORT
echo ".....................Installing PDLC....................................."

#Data generator
# cd synthetic-data-generator
# # git checkout main-hotfixed   # remove
# sed -i 's/node1,node2,node3/c1,c2,kind-control-plane/' netma-controller/netma-controller-deployment.yaml
# sed -i 's/node1,node2,node3/c1,c2,kind-control-plane/' acm-controller/acm-controller-deployment.yaml
# chmod -R 777 apply-controllers.sh
# ./apply-controllers.sh
# # dummy CRs
# chmod -R 777 ./apply-dummy.sh
# ./apply-dummy.sh
# cd ..
#PDLC

cd pdlc-integration
sed -i "s/sonem-worker/$WORKER_NODE_1/" data_preprocessing/pdlc-dp-deployment.yaml
sed -i "s/test-namespace/he-codeco-acm/" data_preprocessing/pdlc-dp-deployment.yaml
sed -i "s/sonem-worker/$WORKER_NODE_1/" context_awareness/pdlc-ca-deployment.yaml
sed -i "s/sonem-worker/$WORKER_NODE_1/" gnn_model/gnn_controller.yaml
sed -i "s/sonem-worker/$WORKER_NODE_1/" gnn_model/gnn_inference.yaml
sed -i "s/sonem-worker/$WORKER_NODE_1/" rl_model/rl-model-deployment.yaml
sed -i "s/sonem/$CURRENT_CONTEXT/" data_preprocessing/pdlc-dp-deployment.yaml
#sed -i 's/"http://mdm-controller-service.he-codeco-mdm.svc.cluster.local:5080"/"http://mdm-api.he-codeco-mdm.svc.cluster.local:8090"/' data_preprocessing/pdlc-dp-deployment.yaml
sed -i 's|"http://mdm-controller-service.he-codeco-mdm.svc.cluster.local:5080"|"http://mdm-api.he-codeco-mdm.svc.cluster.local:8090"|' data_preprocessing/pdlc-dp-deployment.yaml
chmod -R 777 apply_yamls.sh
./apply_yamls.sh
cd ..
echo "........................................Finished installing PDLC..............................................."
echo ".....................Installing SWM....................................."
cd qos-scheduler
sed -i '59s/enabled: true/enabled: false/' ./helm/qos-scheduler/values.yaml
make chart
helm install qostest --namespace=he-codeco-swm --create-namespace tmp/helm
cd ..
echo "......................................Finished installing SWM.................................."

echo ".....................Installing Kepler....................................."
cd kepler
sed -i 's/IMAGE_TAG          ?= latest/export IMAGE_TAG   ?= release-0.7.8/g' Makefile
make build-manifest OPTS="PROMETHEUS_DEPLOY"
kubectl create -f _output/generated-manifest/deployment.yaml
cd ..
echo "......................................Finished installing Kepler.................................."