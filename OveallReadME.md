# CODECO - Cognitive Decentralized Edge Cloud Orchestration

## Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Minimum Requirements](#minimum-requirements)
- [Installation and Setup](#installation-and-setup)
  - [Software Prerequisites](#software-prerequisites)
  - [Cluster Setup](#cluster-setup)
  - [Component Setup](#component-setup)
- [Monitoring and Logging](#monitoring-and-logging)
- [Usage](#usage)
- [Contributing](#contributing)
- [License](#license)
- [Contact](#contact)

## Overview
CODECO stands for Cognitive Decentralized Edge to Cloud Orchestration. It is an open-source software framework pluggable to Kubernetes. CODECO improves the energy efficiency and robustness of the Edge-Cloud infrastructure (compute, network, data) by improving application deployment and run-time.

CODECO’s vision is based on a cognitive and cross-layer orchestration. It considers as layers the data flow, computation, and network. Its focus is on creating a flexible and resource-efficient Edge-Cloud infrastructure.

## Architecture

**ACM** (Adaptive Configuration Manager) shall contemplate integration into embedded and small footprint nodes; the development of semantic interfaces/Kubernetes operators that extend the ACM operation towards the other CODECO components; automated configuration and user interfacing, supporting operations across multi-cluster (federated clusters) in a way that is transparent to the user. ACM will provide autoscaling and a descriptive, automated, intent-based setup for required software components and Edge interconnections, considering business/policy, application, and networking requirements. Security focus includes attack mitigation and detection across multi-cluster environments.

**Metadata Management (MDM)** aims to support real-time Edge applications and assist in more efficient Cloud-Edge operations. MDM integrates:
- A semantic data catalog for data compliance.
- Data discovery to enrich collected data with feedback from other CODECO components and insights from multi-cluster operations.
- Data orchestration to assist CODECO in determining where data should be stored and processed.

**Privacy Preserving Decentralized Learning and Context-awareness (PDLC)** integrates three sub-modules:
- Privacy preservation
- Decentralized learning
- Context-awareness 

The **Context-awareness agent (CA)** monitors application requirements, user behavior, and data aspects, interacting with ACM and MDM to optimize performance based on factors like greenness, QoS, privacy, and sovereignty needs.

**Scheduling and Workload Migration (SWM)** handles the initial deployment, monitoring, and potential migration of containerized workloads across single and multi-cluster environments. It optimizes placement of applications and containers across Edge and Cloud for efficiency (low latency, lower energy consumption, data sensitivity, QoE), derived from context-awareness indicators.

**Network Management and Adaptation (NetMA)** handles automated setup of interconnections for flexible Edge-Cloud operation. It supports various network technologies (wireless, cellular, fixed) and optimizes network traffic and performance through ALTO (RFC 7285). NetMA also manages:
- Network softwarization and FaaS support to the Edge
- Semantic interoperability (e.g., Gaia-X semantic network model)
- Secure data exchange with attestation and verification mechanisms
- Predictive behavior with AI/ML for network KPIs
- Integrated network capability exposure using ALTO and standard-based APIs

## Minimum Requirements

### Hardware:
- At least 1 cluster with a minimum of 3 nodes.

### Software:
- Golang: v1.21+
- Kind: latest stable
- Kubectl: v1.28.2+
- Helm: 3.15.4+
- Make
- Kubernetes: v1.20+
- Docker: v20.10+ 
- Prometheus: v2.27+ 
- Grafana: v8.0+ 
- Helm: v3.0+ 

### Networking:
- Ensure all nodes are reachable via internal networking (private IPs).
- Open the following ports:
  - Port 3000 (Grafana)
  - Port 9090 (Prometheus)
  - Any custom ports used by your services.

## Installation and Setup

### Software Prerequisites
- Golang
- Kind
- Kubectl
- Helm
- Make
- Kubernetes
- Docker
- Prometheus
- Grafana
- Helm

# Cluster Setup

## Local Testing - Kind

Assuming you have `kind` installed, create a cluster using this configuration file:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:5001"]
    endpoint = ["http://kind-registry:5000"]
networking:
  podSubnet: "10.100.0.0/16"
#    disableDefaultCNI: true
nodes:
- role: control-plane
  image: kindest/node:v1.26.6
  labels:
    siemens.com.qosscheduler.master: true
    dedicated: master # Add this line to assign the dedicated=master label
- role: worker
  image: kindest/node:v1.26.6
  extraMounts:
  - hostPath: /tmp/nwapidb
    containerPath: /nwapidb
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      name: "C1"
      kubeletExtraArgs:
        node-labels: "mac-address=5e0d.6660.a485,siemens.com.qosscheduler.c1=true"
- role: worker
  image: kindest/node:v1.26.6
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      name: "C2"
      kubeletExtraArgs:
        node-labels: "mac-address=da69.022b.c8fc,siemens.com.qosscheduler.c2=true"
```
## Cluster Setup

Once you have created this config file, reference it when creating your cluster:

```bash
kind create cluster --config <your-config-file-name>.yaml
```
To ensure your 3 node cluster has come up run:
```bash
kind get clusters
```
You should see your cluster named “kind” displayed.

## Deploying CODECO through ACM
The CODECO ACM operator is the main entry point to the CODECO platform. It serves
2 types of users, and provides 2 different CRDs, one per user.

Application developer (aka cluster user) - This is a user that deploys an
application on the CODECO platforme. The CRD for the application deployment is
CodecoApp.

Cluster admin - TBD

On deployment, a 3 node kind cluster will be configured and set up.
We will then use ACM to install the other 4 project components; SWM, MDM, PDLC & NetMA
Our post_deploy.sh script will then configure the cluster to suit the needs of not only ACM, but of all CODECO components.

Assuming your cluster is now set up, navigate to the Automated Configuration Management-ACM Repository.

Clone this repo using the command: 
```bash
git clone “https://gitlab.eclipse.org/eclipse-research-labs/codeco-project/acm.git”
```
Enter the ACM repo:
```
cd acm
```
Build and push your CODECO image:
```
make docker-build docker-push IMG=”<registry>/<username>/<image-name>:v0.0.1”
```

Deploy ACM to the cluster using the image you just built, and allow ACM to install all other components:

```
make deploy IMG=”<registry>/<username>/<image-name>:v0.0.1”
```

Once deployed, check all pods are running by using:

```
kubectl get po -A
```

Your CODECO instance should now be fully deployed.

## Deploying CODECO Components individually
Deploy MDM

Deploy NetMA

Deploy SWM

Deploy PDLC

Deploy Prometheus

Deploy Multus-cni

Deploy Kepler

## Using CAM to Deploy and Monitor Applications 

CAM has been developed in a customizable way, which allows user DEV to customise, deploy, and enhance its functionality within a K8s environment, considering different applications. Steps to adapt CAM to a new application are defined next. 

First, user DEV must have a running K8s cluster; afterwards, user DEV MUST define the application to deploy across Edge-Cloud via the CAM Yaml.There is a sample provided in the ACM repo.  

The sample application can then be deployed with the following command: 

```
kubectl apply -f ./config/samples/codeco_v1alpha1_codecoapp_ver3.yaml
```
## Monitoring and Logging
Prometheus is used to collect metrics from each component.
Access the Prometheus dashboard at http://<prometheus_url>:9090.

Grafana is used for visualising the collected data.
Access the Grafana dashboard at http://<grafana_url>:3000.

## Contributing
If you'd like to contribute, please follow the contributing guidelines to submit issues or create pull requests.

## Licence


## Contact
For any questions or support, please reach out to:
Project Lead: Rute Sofia 
Support Team: 
