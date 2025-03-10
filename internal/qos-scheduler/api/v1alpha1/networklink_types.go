// SPDX-FileCopyrightText: 2023 Siemens AG
// SPDX-License-Identifier: Apache-2.0

package v1alpha1

import meta "k8s.io/apimachinery/pkg/apis/meta/v1"

type NodeType string

// The kinds of nodes that can show up in a topology.
const (
	COMPUTE_NODE NodeType = "COMPUTE"
	NETWORK_NODE NodeType = "NETWORK"
)

// A LinkNode is a node that is being considered for its network
// properties. It can be either a ComputeNode or a NetworkNode.
// A NetworkNode is usually a switch. A ComputeNode usually has
// computation capabilities.
// Kubernetes nodes may be ComputeNodes. A Kubernetes node is never a
// NetworkNode.
// All ComputeNodes will be represented by a NetworkEndpoint CRD object.
type LinkNode struct {

	// The node's name. Must not be empty.
	// For ComputeNodes, this should be the same as the NodeName
	// on the corresponding NetworkEndpoint object.
	// For NetworkNodes, the name is not evaluated by our code, but it
	// makes sense to use a unique device id.
	Name string `json:"name"`

	// Values are COMPUTE or NETWORK.
	// +kubebuilder:default:=COMPUTE
	Type NodeType `json:"type,omitempty" protobuf:"bytes,1,opt,name=type,casttype=NodeType"`
}

type NetworkEndpointNetworkInterface struct {

	// The name of a network interface, such as eth0
	Name string `json:"name"`

	// The mac address associated with this network interface.
	MacAddress string `json:"macAddress,omitempty"`

	// The ip v4 address associated with this network interface.
	// Only interfaces with an ip address are relevant to us, so
	// this field is mandatory.
	IPv4Address string `json:"ipv4Address"`

	// If the network interface has other addresses, record them here.
	// This is relevant for node network interfaces that have multiple
	// addresses.
	// +optional
	AlternateAddresses []string `json:"alternateAddresses"`
}

// NetworkEndpointSpec is additional information about a ComputeNode.
type NetworkEndpointSpec struct {

	// NodeName is the name of the corresponding Kubernetes node, if such a node exists.
	// Otherwise, a unique name.
	NodeName string `json:"nodeName"`

	// NetworkInterfaces are all the network interfaces on the endpoint.
	// For Kubernetes nodes, this list is populated by the node daemon set.
	NetworkInterfaces []NetworkEndpointNetworkInterface `json:"networkInterfaces"`

	// MappedNetworkInterfaces map network implementation (network type) labels to network interface names.
	// There needs to be an entry in this map for every physical network that
	// this endpoint participates in.
	// For Kubernetes nodes, the network operators for physical networks are responsible
	// for inserting an entry for their network in this mapping.
	// +optional
	MappedNetworkInterfaces map[string]string `json:"mappedNetworkInterfaces"`
}

// NetworkLinkSpec represents a link between two nodes. These can be
// k8s compute nodes or network nodes, for instance those that represent
// network routers or switches.
type NetworkLinkSpec struct {
	// The 'from' node of the link.
	LinkFrom LinkNode `json:"linkFrom"`

	// The 'to' node of the link.
	LinkTo LinkNode `json:"linkTo"`

	// Bandwidth capacity in bit/s on the link from LinkFrom to LinkTo.
	// This is the total capacity, regardless of how much is
	// in use.
	BandWidthBits int64 `json:"bandWidthBits,omitempty"`

	// Worst-case delay in nanoseconds.
	LatencyNanos int64 `json:"latencyNanos,omitempty"`

	// If set, the name of the physical network that this is built on.
	// If this value is set, then this link is a logical link.
	// If this value is empty, then this link is a physical link.
	// +optional
	PhysicalBase string `json:"physicalBase,omitempty"`
}

// NetworkLinkStatus defines the observed state of NetworkLink
type NetworkLinkStatus struct {

	// Average latency on the link from node1 to node2 in nanoseconds.
	LatencyNanos int64 `json:"latencyNanos,omitempty"`

	// How much of the spec bandwidth is currently available.
	// Like the bandwidth, this is in bits per second.
	BandWidthAvailable int64 `json:"bandWidthAvailable,omitempty"`

	// The ids of channels that traverse this link.
	EmbeddedChannels []string `json:"embeddedChannels,omitempty"`
}

//+kubebuilder:object:root=true
//+kubebuilder:subresource:status
//+kubebuilder:resource:shortName=nwl
//+kubebuilder:printcolumn:name="BWspec",type="integer",JSONPath=".spec.bandWidthBits",description="bandwidth"
//+kubebuilder:printcolumn:name="BWAvail",type="integer",JSONPath=".status.bandWidthAvailable",description="Available bandwidth"
//+kubebuilder:printcolumn:name="Latency Spec",type="integer",JSONPath=".spec.latencyNanos",description="Latency"
//+kubebuilder:printcolumn:name="Latency",type="integer",JSONPath=".status.latencyNanos",description="Current Latency"
//+kubebuilder:printcolumn:name="Age",type="date",JSONPath=".metadata.creationTimestamp"

// NetworkLink is the Schema for the networklinks API
type NetworkLink struct {
	meta.TypeMeta   `json:",inline"`
	meta.ObjectMeta `json:"metadata,omitempty"`

	Spec   NetworkLinkSpec   `json:"spec,omitempty"`
	Status NetworkLinkStatus `json:"status,omitempty"`
}

//+kubebuilder:object:root=true

// NetworkLinkList contains a list of NetworkLink
type NetworkLinkList struct {
	meta.TypeMeta `json:",inline"`
	meta.ListMeta `json:"metadata,omitempty"`
	Items         []NetworkLink `json:"items"`
}

//+kubebuilder:object:root=true
//+kubebuilder:subresource:status
//+kubebuilder:resource:shortName=nep
//+kubebuilder:resource:scope=Cluster

// NetworkEndpoint is the schema for NetworkEndpoints.
type NetworkEndpoint struct {
	meta.TypeMeta   `json:",inline"`
	meta.ObjectMeta `json:"metadata,omitempty"`
	Spec            NetworkEndpointSpec `json:"spec,omitempty"`
}

//+kubebuilder:object:root=true

// NetworkEndpointList contains a list of NetworkEndpoints.
type NetworkEndpointList struct {
	meta.TypeMeta `json:",inline"`
	meta.ListMeta `json:"metadata,omitempty"`
	Items         []NetworkEndpoint `json:"items"`
}

func init() {
	SchemeBuilder.Register(&NetworkLink{}, &NetworkLinkList{})
	SchemeBuilder.Register(&NetworkEndpoint{}, &NetworkEndpointList{})
}
