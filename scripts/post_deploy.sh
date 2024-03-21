#!/bin/bash
## This script is executed after the CODECO operator deployment finishes. It is used to install additional
## components and to perform any other post-deployment tasks.
echo "Executing post deployment tasks..."
##TODO(user): Add your post deployment tasks here
cd ..
echo ".....................Installing SWM....................................."
cd qos-scheduler
make chart
helm install qostest --namespace=codeco-swm-controllers --create-namespace tmp/helm
cd ..
echo "......................................Finished installing SWM.................................."
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
cd pdlc-pp
# chmod -R 777 .
# sudo ./apply-controller.sh
# cd crd\ data\ extraction/
# sudo pip3 install -r requirements_e.txt
# sudo python3 ca_crd_extractor.py
cd ..
echo "........................................Finished installing PDLC..............................................."
echo "........................................Installing NetMA..............................................."
cd secure-connectivity
kubectl taint nodes kind-control-plane node-role.kubernetes.io/control-plane:NoSchedule-
kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset-thick.yml
cat ../multus-cni/deployments/multus-daemonset-thick.yml | kubectl apply -f -
kubectl create -f ./deployments/l2sm-deployment.yaml
cd ..
echo "........................................Finished installing NetMA..............................................."


