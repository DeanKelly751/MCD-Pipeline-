// SPDX-FileCopyrightText: 2023 Siemens AG
// SPDX-License-Identifier: Apache-2.0

package v1alpha1

import meta "k8s.io/apimachinery/pkg/apis/meta/v1"

const (
	// The name of the label storing the network implementation
	// for a channel.
	// The value for this label is chosen at runtime based on the
	// channel's ServiceClass.
	NetworkLabel string = "network-implementation"

	// The name of the label storing the physical network that the
	// channel will run on. This has to be the physical network
	// underlying the network implementation named in *NetworkLabel*.
	// The value for this label is chosen at runtime based on the
	// value of the *NetworkLabel* label.
	PhysicalNetworkLabel string = "physical-network-implementation"

	// The label storing the name of the source application.
	SourceAppLabel string = "application"

	// The label storing the name of the target application.
	TargetAppLabel string = "to-application"

	// The label storing the name of the owning application group.
	AppGroupLabel string = "application-group"
)

// ChannelSpec is a channel that the scheduler requests on behalf of an application.
// The ChannelSpec is computed from the NetworkInterfaces in the application's workloads,
// together with scheduling information that says which workload will run on which node.
type ChannelSpec struct {

	// ChannelFrom identifies the compute node where the channel originates.
	// The endpoints of a channel are always compute nodes (as opposed to network nodes).
	ChannelFrom string `json:"channelFrom"`
	ChannelTo   string `json:"channelTo"`

	// ChannelPath is the list of network links to use for
	// implementing the route from ChannelFrom to ChannelTo.
	//+optional
	ChannelPath ChannelPathRef `json:"channelPath,omitempty"`

	// SourceWorkload and TargetWorkload identify the workloads (pods) that
	// this channel connects. The values are pod names.
	SourceWorkload string `json:"sourceWorkload"`
	TargetWorkload string `json:"targetWorkload"`

	// TargetPort is the port where the target workload listens for channel traffic.
	// If you want to specify a name and a protocol as well, they need to be added
	// here and in the channel spec and in the service generation code.
	TargetPort int32 `json:"targetPort"`

	// These parameters all come from a Channel on an application workload.

	// Bandwidth (in bit/s)
	MinBandwidthBits int64 `json:"bandwidthBits,omitempty"`
	// This is the maximum latency, in nanoseconds.
	MaxDelayNanos int64 `json:"maxDelayNanos,omitempty"`
	// Framesize (in Bytes)
	Framesize int32 `json:"framesize,omitempty"`
	// Interval (in nanoseconds)
	SendInterval int32 `json:"sendInterval,omitempty"`

	// The quality of service requested for this channel.
	// The network implementation class (network type) will be determined from this
	// and stored in the "network-implementation" label.
	//+optional
	ServiceClass NetworkServiceClass `json:"serviceClass,omitempty"`
}

// A ChannelPathRef identifies a path that packets sent through
// a channel should take.
type ChannelPathRef struct {
	// The name of the path.
	Name string `json:"name"`
	// The namespace of the path.
	Namespace string `json:"namespace"`
}

// ChannelCniMetadata contains the information necessary for filling
// out a Multus network attachment definition, in particular
// the cni args.
type ChannelCniMetadata struct {
	// The Ip address range associated with this channel.
	// The network operator has to request a range containing this
	// ip range from the global ipam controller.
	//+optional
	IpRange string `json:"ipRange,omitempty"`

	// The Ip address assigned to the source Pod
	//+optional
	SourceIp string `json:"sourceip,omitempty"`

	// The Ip address assigned to the target Pod
	//+optional
	TargetIp string `json:"targetip,omitempty"`

	// The Node ip range for this channel.
	// This is for channels that wish to assign a custom IP to both the
	// nodes and the pods.
	//+optional
	NodeIpRange string `json:"nodeIpRange,omitempty"`

	// The path to take from source to target.
	//+optional
	ChannelPath ChannelPathRef `json:"channelPath,omitempty"`

	// The name of the network attachment definition resource to use, if any.
	//+optional
	NetworkAttachmentName string `json:"networkAttachmentName,omitempty"`

	// The VLAN ID to use for setup of virtual overlay network with sub interface on k8s nodes
	//+optional
	VlanId int `json:"vlanId,omitempty"`

	// The ID of the container network interface.
	//+optional
	ContainerInterfaceId int `json:"containerInterfaceId,omitempty"`

	// The QoS Egress priority to attach to packets traversing this
	// channel.
	//+optional
	QoSPriority int `json:"qosPriority,omitempty"`

	// Name of the L2S-M Vlink that is associated with the channel
	//+optional
	VlinkName string `json:"vlinkName,omitempty"`
}

// ChannelStatus defines the state of a channel.
type ChannelStatus struct {

	// Status of the channel inside the cluster.
	Status ChannelStatusCode `json:"status"`

	// Framesize (in bytes)
	FrameSize int32 `json:"frameSize,omitempty"`

	// Interval (in nanoseconds)
	Interval int32 `json:"interval,omitempty"`

	// Latency (in nanoseconds)
	Latency int64 `json:"latency,omitempty"`

	// Earliest Transmission Offset (in nanoseconds)
	EarliestTransmissionOffset int32 `json:"earliestTransmissionOffset,omitempty"`

	// Latest Transmission Offset (in nanoseconds)
	LatestTransmissionOffset int32 `json:"latestTransmissionOffset,omitempty"`

	// Information about this channel for use in configuring cni plugins.
	CniMetadata ChannelCniMetadata `json:"cniMetadata"`
}

// ChannelStatusCode is the status of the channel.
type ChannelStatusCode string

const (
	// The initial status.
	ChannelRequested ChannelStatusCode = "REQUESTED"

	// The logical network operator for the channel's service class has
	// determined that this channel is implementable.
	ChannelReviewed ChannelStatusCode = "REVIEWED"

	// The physical network operator for the channel's service class
	// is working on implementing the channel.
	ChannelImplementing ChannelStatusCode = "IMPLEMENTING"

	// The physical network operator has implemented the channel and
	// updated cni metadata if necessary.
	ChannelImplemented ChannelStatusCode = "IMPLEMENTED"

	// The logical network operator has filled in the cni metadata for the
	// channel.
	ChannelAck ChannelStatusCode = "ACK"

	// The channel is ready to use.
	// This is the status that workloads need in order to run.
	ChannelRunning ChannelStatusCode = "RUNNING"

	// The logical or physical network operator were unable to
	// accommodate the channel, for example due to capacity constraints.
	ChannelRejected ChannelStatusCode = "REJECTED"

	// The channel has been canceled (usually because the workload that was one of its
	// endpoints was canceled, but could also happen if the channel goes into a failure
	// state for any other reason).
	ChannelCanceled ChannelStatusCode = "CANCELED"

	// This gets returned by some evaluation methods in the code.
	// Usually once a channel is in this state, it will be "CANCELED" or "NACK" soon after, or it will
	// "heal" itself and go to "ACK".
	ChannelOOQOS ChannelStatusCode = "OOQOS"

	// This is a soft-delete that signals it is now safe to re-request a channel
	// with this name because the applications that had requested the deleted
	// channel have failed and are being re-scheduled.
	ChannelDeleted ChannelStatusCode = "DELETED"
)

//+kubebuilder:object:root=true
//+kubebuilder:subresource:status
//+kubebuilder:printcolumn:name="Status",type="string",JSONPath=".status.status",description="Status"
//+kubebuilder:printcolumn:name="source",type="string",JSONPath=".spec.channelFrom",description="source node"
//+kubebuilder:printcolumn:name="target",type="string",JSONPath=".spec.channelTo",description="target node"
//+kubebuilder:printcolumn:name="Framesize",type="string",JSONPath=".spec.frameSize",description="(framesize in bytes)"
//+kubebuilder:printcolumn:name="Interval",type="string",JSONPath=".spec.interval",description="interval (nanos)"
//+kubebuilder:printcolumn:name="Latency",type="string",JSONPath=".spec.latency",description="latency (nanos)"
//+kubebuilder:printcolumn:name="OffsetFrom",type="string",JSONPath=".spec.earliestTransmissionOffset",description="Earliest Transmission Offset"
//+kubebuilder:printcolumn:name="OffsetTo",type="string",JSONPath=".spec.latestTransmissionOffset",description="Latest Transmission Offset"

// Channel is the Schema for the channels API
type Channel struct {
	meta.TypeMeta   `json:",inline"`
	meta.ObjectMeta `json:"metadata,omitempty"`

	Spec   ChannelSpec   `json:"spec,omitempty"`
	Status ChannelStatus `json:"status,omitempty"`
}

//+kubebuilder:object:root=true

// ChannelList contains a list of Channel
type ChannelList struct {
	meta.TypeMeta `json:",inline"`
	meta.ListMeta `json:"metadata,omitempty"`
	Items         []Channel `json:"items"`
}

func init() {
	SchemeBuilder.Register(&Channel{}, &ChannelList{})
}
