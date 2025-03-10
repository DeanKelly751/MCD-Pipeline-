// SPDX-FileCopyrightText: 2023 Siemens AG
// SPDX-License-Identifier: Apache-2.0

package v1alpha1

import core "k8s.io/api/core/v1"

// ApplicationWorkloadSpec defines the desired state of an ApplicationWorkload
// (or Workload for short).
// Workloads are based on ReplicaSets with a few extra features.
// The main extra feature is the Channel spec, which states the desired
// explicit connectivity with specified QoS attributes to other Workloads.
// Currently a Workload is not embedded as an actual ReplicaSpec, but results
// in a single Pod. Otherwise this would result in several Channels between
// replicas of Workloads.
type ApplicationWorkloadSpec struct {

	// Basename will be used to name the Pod generated from this workload spec.
	// The Pod name will be composed of the application's basename and this string.
	// +optional
	// +kubebuilder:validation:Pattern=^[a-z]+([-a-z0-9]+)$
	Basename string `json:"basename,omitempty"`

	// Template describes the pod that will be created.
	// This does not use corev1.PodTemplateSpec because the generated CRD will not have
	// the metadata field.
	// See also: https://github.com/kubernetes-sigs/controller-tools/issues/385
	// This comes from code in Kubernetes that overrides some types in CRDs. One of those
	// types is ObjectMeta.
	Template QosPodTemplateSpec `json:"template,omitempty" protobuf:"bytes,3,opt,name=template"`

	// Channels describe the explicit connectivity requirements with defined QoS attributes
	// for channels from this workload to another workload.
	// The target workload is identified by the name of the application
	// it belongs to and the workload basename.
	// +optional
	Channels []NetworkChannel `json:"channels" protobuf:"bytes,2,opt,name=channels"`

	// Costs provide the possibility to define a cost vector for every workload and node
	// This is forwarded to the scheduler to factor it into the scheduling decision.
	// +optional
	Costs map[string]float64 `json:"costs" protobuf:"bytes,4,opt,name=costs"`

	// NodeRecommendations provide the possibility to define a recommendation vector for every node for this workload
	// +optional
	NodeRecommendations map[string]float64 `json:"nodeRecommendations" protobuf:"bytes,5,opt,name=nodeRecommendations"`
}

type QosPodTemplateSpec struct {
	Metadata QosMeta      `json:"metadata,omitempty" protobuf:"bytes,1,opt,name=metadata"`
	Spec     core.PodSpec `json:"spec,omitempty" protobuf:"bytes,2,opt,name=spec"`
}

type QosMeta struct {
	Labels map[string]string `json:"labels,omitempty" protobuf:"bytes,1,opt,name=labels"`
}

// WorkloadId is a combination of a workload basename and an application name.
// All workloads that communicate with each other via Channels must be in the
// same namespace.
type WorkloadId struct {
	// +kubebuilder:validation:Pattern=^[a-z]+([-a-z0-9]+)$
	Basename        string `json:"basename,omitempty"`
	ApplicationName string `json:"applicationName,omitempty"`

	// The port where the application listens for Channel data.
	// This has to be the same as the containerPort on the relevant container.
	Port int `json:"port,omitempty"`
}

type NetworkServiceClass string

const (
	ServiceClassBestEffort NetworkServiceClass = "BESTEFFORT"
	ServiceClassAssured    NetworkServiceClass = "ASSURED"
)

// NetworkChannel declares the connectivity to other workloads with explicit QoS attributes,
// like bandwidth or latency.
// QoS attributes are unidirectional (in the direction from this workload to another workload).
type NetworkChannel struct {

	// Basename will be used as the name for the channel resource.
	// If you do not set this, a name will be created for you from the applications
	// and workloads that this channel connects.
	// Channel names have to be unique within the whole namespace, so it is best not
	// to specify this yourself.
	// +kubebuilder:validation:Pattern=^[a-z]+([-a-z0-9]+)$
	Basename string `json:"basename,omitempty"`

	// OtherWorkload identifies the target workload of the connection
	// via its application name and workload basename.
	OtherWorkload WorkloadId `json:"otherWorkload" protobuf:"bytes,1,name=otherWorkload"`

	// A communication service Class for this channel.
	// Currently, two service classes are supported, 'BESTEFFORT' and 'ASSURED'.
	// Service classes are mapped to network infrastructure type by the QoS Scheduler.
	// +optional
	ServiceClass NetworkServiceClass `json:"serviceClass,omitempty"`

	// All NetworkChannel requirements can be specified like a Kubernetes
	// resource.Quantity. This means you can specify a bandwidth of 10MBit/s by
	// writing "10M".

	// Bandwidth specifies the traffic requirements for the Channel.
	// It is specified in bit/s, e.g. 5M means 5Mbit/s.
	// If you specify only the bandwidth but leave framesize and sendInterval
	// blank, the system will request a default framesize of 500 byte for you.
	// If that is not what you want, you need to request the framesize explicitly.
	// +optional
	// +kubebuilder:validation:Pattern:=^(\+|-)?(([0-9]+(\.[0-9]*)?)|(\.[0-9]+))(([KMGTPE]i)|[numkMGTPE]|([eE](\+|-)?(([0-9]+(\.[0-9]*)?)|(\.[0-9]+))))?$
	MinBandwidth string `json:"bandwidth,omitempty"`

	// The maximum tolerated latency (end to end) on this channel in seconds.
	// "1" means "one second", "10e-3" means "10 milliseconds".
	// +optional
	// +kubebuilder:validation:Pattern:=^(\+|-)?(([0-9]+(\.[0-9]*)?)|(\.[0-9]+))(([KMGTPE]i)|[numkMGTPE]|([eE](\+|-)?(([0-9]+(\.[0-9]*)?)|(\.[0-9]+))))?$
	MaxDelay string `json:"maxDelay,omitempty"`

	// Framesize specifies the number of bytes that are sent in one go.
	// As an example, specifying a Framesize of 1K and a SendInterval of 10e-3 (i.e. 10ms),
	// the effective bandwidth is 100kByte/s or 800kbit/s.
	// +optional
	// +kubebuilder:validation:Pattern:=^(\+|-)?(([0-9]+(\.[0-9]*)?)|(\.[0-9]+))(([KMGTPE]i)|[numkMGTPE]|([eE](\+|-)?(([0-9]+(\.[0-9]*)?)|(\.[0-9]+))))?$
	Framesize string `json:"framesize,omitempty"`

	// The SendInterval specifies the interval between two consecutive frames sent over this channel, in seconds.
	// "10e-6" means "10 microseconds".
	// This value should not exceed 10e-3 aka 10ms. The code will cap it at 10ms if you specify a larger value.
	// +optional
	// +kubebuilder:validation:Pattern:=^(\+|-)?(([0-9]+(\.[0-9]*)?)|(\.[0-9]+))(([KMGTPE]i)|[numkMGTPE]|([eE](\+|-)?(([0-9]+(\.[0-9]*)?)|(\.[0-9]+))))?$
	SendInterval string `json:"sendInterval,omitempty"`
}
