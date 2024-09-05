#!/bin/bash
## This script is executed after the CODECO operator deployment finishes. It is used to install additional
## components and to perform any other post-deployment tasks.
echo "Executing post deployment tasks..."
##TODO(user): Add your post deployment tasks here
echo "........................................Installing Primary CNI: Flannel..............................................."
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml 
sleep 20
cd ..
echo "........................................Installing NetMA..............................................."
cd secure-connectivity
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.3/cert-manager.yaml
kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset-thick.yml

kubectl taint nodes kind-control-plane node-role.kubernetes.io/control-plane:NoSchedule-
# kubectl taint nodes --all node-role.kubernetes.io/control-plane- node-role.kubernetes.io/master-
kubectl create namespace he-codeco-netma
kubectl get nodes

sleep 60
kubectl create -f ./deployments/l2sm-deployment.yaml -n=he-codeco-netma
cd ..
## kubectl apply -f network-exposure/kuberfiles/01_netma-topology-crd.yaml
## chmod 755 network-exposure/ejecutar_mon.sh
## This should be executed with sudo privileges
## ./network-exposure/ejecutar_mon.sh
## The next command is to check that the CR has been pushed correctly 
## kubectl get netma-topology netma-sample -o yaml -n he-codeco-netma
echo "........................................Finished installing NetMA..............................................."
echo ".....................Installing MDM....................................."
cd mdm-api
export MDM_NAMESPACE=he-codeco-mdm
export MDM_CONTEXT=kind-kind
kubectl --context=$MDM_CONTEXT create namespace $MDM_NAMESPACE
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add neo4j https://helm.neo4j.com/neo4j
sed -i "s/<storageclassName>/standard/g" "./deployment/zookeeper-helm.yaml"
sed -i "s/<storageclassName>/standard/g" "./deployment/neo4j-helm.yaml"
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

# Prometheus installation

cd kube-prometheus
kubectl apply --server-side -f manifests/setup
kubectl wait \
	--for condition=Established \
	--all CustomResourceDefinition \
	--namespace=monitoring
kubectl apply -f manifests/
cd ..

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
sed -i 's/sonem-worker/c1/' data_preprocessing/pdlc-dp-deployment.yaml
sed -i 's/sonem-worker/c1/' context_awareness/pdlc-ca-deployment.yaml
sed -i 's/sonem-worker/c1/' gnn_model/gnn_controller.yaml
sed -i 's/sonem-worker/c1/' gnn_model/gnn_inference.yaml
sed -i 's/sonem-worker/c1/' rl_model/rl-model-deployment.yaml
sed -i 's/sonem/kind/' data_preprocessing/pdlc-dp-deployment.yaml
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
make build-manifest OPTS="PROMETHEUS_DEPLOY"
kubectl create -f _output/generated-manifest/deployment.yaml
cd ..
echo "......................................Finished installing Kepler.................................."