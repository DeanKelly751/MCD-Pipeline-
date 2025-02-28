// SPDX-FileCopyrightText: 2023 Siemens AG
// SPDX-License-Identifier: Apache-2.0

module siemens.com/qos-scheduler

go 1.22

toolchain go1.22.1

require (
	github.com/go-logr/logr v1.4.1 // indirect
	google.golang.org/protobuf v1.31.0
	k8s.io/api v0.29.2
	k8s.io/apimachinery v0.29.2
	k8s.io/klog/v2 v2.110.1 // indirect
	sigs.k8s.io/controller-runtime v0.17.2
)

require google.golang.org/grpc v1.58.3

require (
	github.com/gogo/protobuf v1.3.2 // indirect
	github.com/golang/protobuf v1.5.3 // indirect
	github.com/google/gofuzz v1.2.0 // indirect
	github.com/google/pprof v0.0.0-20230323073829-e72429f035bd // indirect
	github.com/json-iterator/go v1.1.12 // indirect
	github.com/modern-go/concurrent v0.0.0-20180306012644-bacd9c7ef1dd // indirect
	github.com/modern-go/reflect2 v1.0.2 // indirect
	golang.org/x/net v0.19.0 // indirect
	golang.org/x/sys v0.16.0 // indirect
	golang.org/x/text v0.14.0 // indirect
	google.golang.org/genproto/googleapis/rpc v0.0.0-20230822172742-b8732ec3820d // indirect
	gopkg.in/inf.v0 v0.9.1 // indirect
	gopkg.in/yaml.v2 v2.4.0 // indirect
	k8s.io/utils v0.0.0-20230726121419-3b25d923346b // indirect
	sigs.k8s.io/json v0.0.0-20221116044647-bc3834ca7abd // indirect
	sigs.k8s.io/structured-merge-diff/v4 v4.4.1 // indirect
)

replace k8s.io/api => k8s.io/api v0.29.2

replace k8s.io/apiextensions-apiserver => k8s.io/apiextensions-apiserver v0.29.2

replace k8s.io/apimachinery => k8s.io/apimachinery v0.29.2

replace k8s.io/apiserver => k8s.io/apiserver v0.29.2

replace k8s.io/cli-runtime => k8s.io/cli-runtime v0.29.2

replace k8s.io/client-go => k8s.io/client-go v0.29.2

replace k8s.io/cloud-provider => k8s.io/cloud-provider v0.29.2

replace k8s.io/cluster-bootstrap => k8s.io/cluster-bootstrap v0.29.2

replace k8s.io/code-generator => k8s.io/code-generator v0.29.2

replace k8s.io/component-base => k8s.io/component-base v0.29.2

replace k8s.io/component-helpers => k8s.io/component-helpers v0.29.2

replace k8s.io/controller-manager => k8s.io/controller-manager v0.29.2

replace k8s.io/cri-api => k8s.io/cri-api v0.29.2

replace k8s.io/csi-translation-lib => k8s.io/csi-translation-lib v0.29.2

replace k8s.io/kube-aggregator => k8s.io/kube-aggregator v0.29.2

replace k8s.io/kube-controller-manager => k8s.io/kube-controller-manager v0.29.2

replace k8s.io/kube-proxy => k8s.io/kube-proxy v0.29.2

replace k8s.io/kube-scheduler => k8s.io/kube-scheduler v0.29.2

replace k8s.io/kubectl => k8s.io/kubectl v0.29.2

replace k8s.io/kubelet => k8s.io/kubelet v0.29.2

replace k8s.io/legacy-cloud-providers => k8s.io/legacy-cloud-providers v0.29.2

replace k8s.io/metrics => k8s.io/metrics v0.29.2

replace k8s.io/mount-utils => k8s.io/mount-utils v0.29.2

replace k8s.io/sample-apiserver => k8s.io/sample-apiserver v0.29.2

replace k8s.io/sample-cli-plugin => k8s.io/sample-cli-plugin v0.29.2

replace k8s.io/sample-controller => k8s.io/sample-controller v0.29.2

replace k8s.io/pod-security-admission => k8s.io/pod-security-admission v0.29.2

replace k8s.io/dynamic-resource-allocation => k8s.io/dynamic-resource-allocation v0.29.2

replace k8s.io/endpointslice => k8s.io/endpointslice v0.29.2
