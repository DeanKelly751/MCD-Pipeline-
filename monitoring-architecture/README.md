<!--
  ~ Copyright (c) 2024 Red Hat, Inc
  ~ 
  ~ Licensed under the Apache License, Version 2.0 (the "License");
  ~ you may not use this file except in compliance with the License.
  ~ You may obtain a copy of the License at
  ~ 
  ~     http://www.apache.org/licenses/LICENSE-2.0
  ~ 
  ~ Unless required by applicable law or agreed to in writing, software
  ~ distributed under the License is distributed on an "AS IS" BASIS,
  ~ WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  ~ See the License for the specific language governing permissions and
  ~ limitations under the License.
  ~ 
  ~ SPDX-License-Identifier: Apache-2.0
  ~ 
  ~ Contributors:
  ~     [name] - [contribution]
-->

# CODECO

## Prerequisites
To test locally, kubernetes in docker is required. From release binaries:

```sh
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.17.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

Helm is required to install kepler:

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

## Prometheus Operator
First prometheus operator must be installed:

```bash
kubectl apply -f prometheus-operator/namespace.yaml
kubectl apply --server-side -f prometheus-operator/crds
kubectl apply -f prometheus-operator/rbac
kubectl apply -f prometheus-operator/deployment
```

### Deploying thanos
Thanos will receive metrics from prometheus agents, deploy it using:
```bash
kubectl apply -f thanos-receiver/
```

### Deploying prometheus agent
Prometheus agents scrape metrics from different endpoints exposed by service monitors and remote-write the data to the prometheus server, deploy it using:
```bash
kubectl apply -f prometheus-agent
```

In order to make the prometheus server available to the outside, portf-forwarding can be used:
```bash
k port-forward svc/prometheus-operated -n monitoring 9090:9090
```

## Kube-state-metrics
Kube-state-metrics listens to the Kubernetes API server and generates metrics about the state of the object. To deploy it:
```bash
kubectl apply -f kube-state-metrics/
```

## Kepler

To deploy kepler, add the repo to helm

```bash
helm repo add kepler https://sustainable-computing-io.github.io/kepler-helm-chart
helm search repo kepler
```
After that, run the following command to deploy the kepler chart

```bash
helm install kepler kepler/kepler --namespace monitoring 
```

Apply the service monitor to expose the metrics to prometheus:

```bash
kubectl apply -f kepler/
```

## Removal

```bash
kubectl delete -f prometheus-operator/
kubectl delete -f prometheus-server/
kubectl delete -f prometheus-agent/
kubectl delete -f kube-state-metrics/
kubectl delete -f kepler/
```


