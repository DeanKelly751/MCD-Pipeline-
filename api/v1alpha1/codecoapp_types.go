/*
Copyright 2023.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package v1alpha1

import (
	v1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

type CodecoQosClass string

const (
	Gold       CodecoQosClass = "Gold"
	Silver     CodecoQosClass = "Silver"
	BestEffort CodecoQosClass = "BestEffort"
)

type CodecoFailureTolerance string

const (
	HighFailure CodecoFailureTolerance = "High"
	MedFailure  CodecoFailureTolerance = "Medium"
	LowFailure  CodecoFailureTolerance = "Low"
)

type CodecoComplianceClass string

const (
	HighComliance CodecoComplianceClass = "High"
	MedCompliance CodecoComplianceClass = "Medium"
	LowCompliance CodecoComplianceClass = "Low"
)

type CocdcoSecurityClass string

const (
	High   CocdcoSecurityClass = "High"
	Good   CocdcoSecurityClass = "Good"
	Medium CocdcoSecurityClass = "Medium"
	Low    CocdcoSecurityClass = "Low"
	None   CocdcoSecurityClass = "None"
)

type CodecoStatus string

const (
	OK      CodecoStatus = "OK"
	Warning CodecoStatus = "Warning"
	Error   CodecoStatus = "Error"
)

type NetworkServiceClass string

const (
	ServiceClassBestEffort = "BESTEFFORT"
	ServiceClassAssured    = "ASSURED"
)

// CodecoAppMSSpec defines the desired state of CodecoApp micro service
type CodecoAppMSSpec struct {
	// INSERT ADDITIONAL SPEC FIELDS - desired state of cluster
	// Important: Run "make" to regenerate code after modifying this file

	// Name is an used to identify the CODECO micro service. Edit codecoapp_types.go to remove/update
	BaseName string `json:"serviceName"`

	// service channels
	// +optional
	Channels []CodecoChannels `json:"serviceChannels"`

	// A reference to the PodSpec of the microservice. Edit codecoapp_types.go to remove/update
	Template v1.PodSpec `json:"podspec,omitempty"`

	//+kubebuilder:validation:default=25
	NWBandwidthMbs string `json:"nwbandwidth,omitempty"`

	//+kubebuilder:validation:default=10
	NWLatencyMs string `json:"nwlatency,omitempty"`
}

// ServiceId is a combination of a service name and an application name.

type ServiceId struct {
	// +kubebuilder:validation:Pattern=^[a-z]+([-a-z0-9]+)$
	BaseName        string `json:"serviceName,omitempty"`
	ApplicationName string `json:"appName,omitempty"`

	// The port where the application listens for Channel data.
	// This has to be the same as the containerPort on the relevant container.
	Port int `json:"port,omitempty"`
}

type ChannelSettings struct {
	// All NetworkChannel requirements can be specified like a Kubernetes
	// resource.Quantity. This means you can specify a bandwidth of 10MBit/s by
	// writing "10M".

	// Bandwidth specifies the traffic requirements for the Channel.
	// It is specified in bit/s, e.g. 5M means 5Mbit/s.
	// If you specify only the bandwidth but leave framesize and sendinterval
	// blank, the system will request a default framesize of 500 byte for you.
	// If that is not what you want, you need to request the framesize explicitly.
	// +optional
	// +kubebuilder:validation:Pattern:=^(\+|-)?(([0-9]+(\.[0-9]*)?)|(\.[0-9]+))(([KMGTPE]i)|[numkMGTPE]|([eE](\+|-)?(([0-9]+(\.[0-9]*)?)|(\.[0-9]+))))?$
	MinBandwidth string `json:"minBandwidth,omitempty"`

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
	Framesize string `json:"frameSize,omitempty"`

	// The SendInterval specifies the interval between two consecutive frames sent over this channel, in sedonds.
	// "10e-6" means "10 microseconds".
	// This value should not exceed 10e-3 aka 10ms. The code will cap it at 10ms if you specify a larger value.
	// +optional
	// +kubebuilder:validation:Pattern:=^(\+|-)?(([0-9]+(\.[0-9]*)?)|(\.[0-9]+))(([KMGTPE]i)|[numkMGTPE]|([eE](\+|-)?(([0-9]+(\.[0-9]*)?)|(\.[0-9]+))))?$
	SendInterval string `json:"sendInterval,omitempty"`
}

type CodecoChannels struct {
	BaseName string `json:"channelName,omitempty"`

	// OtherWorkload identifies the target workload of the connection
	// via its application name and workload basename.
	OtherWorkload ServiceId `json:"otherService"`

	// A communication service Class for this channel.
	// Currently, two service classes are supported, 'BESTEFFORT' and 'ASSURED'.
	// Service classes are mapped to network infrastructure type by the QoS Scheduler.
	// +optional
	ServiceClass NetworkServiceClass `json:"serviceClass,omitempty"`

	// +optional
	AdvancedChannelSettings ChannelSettings `json:"advancedChannelSettings,omitempty"`
}

// CodecoAppSpec defines the desired state of CodecoApp
type CodecoAppSpec struct {
	// INSERT ADDITIONAL SPEC FIELDS - desired state of cluster
	// Important: Run "make" to regenerate code after modifying this file

	// Name is an used to identify the CODECO application. Edit codecoapp_types.go to remove/update
	AppName string `json:"appName,omitempty"`

	//+kubebuilder:validation:Enum=Gold;Silver;BestEffort
	// QosClass is used to identify the CODECO application QoS. Edit codecoapp_types.go to remove/update
	QosClass CodecoQosClass `json:"qosClass,omitempty"`

	//+kubebuilder:validation:MinItems=1
	// MCSpecs is used to identify the CODECO micro services which compose the application. Edit codecoapp_types.go to remove/update
	Workloads []CodecoAppMSSpec `json:"codecoapp-msspec,omitempty"`

	//+kubebuilder:validation:Enum=High;Good;Medium;Low; None
	// SecurityClass is used to identify the CODECO application security class. Edit codecoapp_types.go to remove/update
	SecurityClass CocdcoSecurityClass `json:"securityClass,omitempty"`
	//expected level of compliance, based on a scale
	ComplianceClass CodecoComplianceClass `json:"complianceClass,omitempty"`
	// Maximum desired level of energy expenditure for the overall k8s infrastructure associated with an application (percent)
	AppEnergyLimit string `json:"appEnergyLimit,omitempty"`
	//Desired tolerance to infrastructure failures, percentage
	FailureTolerance CodecoFailureTolerance `json:"appFailureTolerance,omitempty"`
}

// ServiceStatusMetrics defines the observed metrics of CODECO micro services
type ServiceStatusMetrics struct {
	// Service name, user assigned in the app model, non unique (can have multiple instances of the same service)
	ServiceName string `json:"serviceName,omitempty"`
	// Node name (unique, assigned by K8s)
	NodeName string `json:"nodeName,omitempty"`
	// Pod name (unique, assigned by K8s)
	PodName string `json:"podName,omitempty"`
	// Cluster name (unique, assigned by K8s)
	ClusterName string `json:"clusterName,omitempty"`
	// Average CPU usage per micro service pod
	AvgServiceCpuUsage string `json:"avgServiceCpu,omitempty"`
	// Average memory usage per micro service pod
	AvgServiceMemoryUsage string `json:"avgServiceMemory,omitempty"`
}

// CodecoAppStatusMetrics defines the observed metrics of CodecoApp
type CodecoAppStatusMetrics struct {
	// The number of the pods instantiated for the application
	Numpods int `json:"numPods,omitempty"`
	// Aggregation of the CPU usage of all the services in the app (in vCPU units)
	AvgAppCpuUsage string `json:"avgAppCpu,omitempty"`
	// Aggregation of the memory usage of all the services in the app
	AvgAppMemoryUsage string `json:"avgAppMemory,omitempty"`
	// ServiceStatusMetrics defines the observed metrics of CODECO micro services
	ServiceMetrics []ServiceStatusMetrics `json:"serviceMetrics,omitempty"`
}

// Observed and Aggregated metrics from Codeco App Nodes
type CodecoAppNodeStatusMetrics struct {
	// Node name (unique, assigned by K8s)
	NodeName string `json:"nodeName,omitempty"`
	// Avg CPU consumption of the application on this node (aggregation of service CPU over the node)
	AvgCpuUsage string `json:"avgNodeCpu,omitempty"`
	// Avg memory consumption of the application on this node (aggregation of service memory over the node)
	AvgMemoryUsage string `json:"avgNodeMemory,omitempty"`
	// Node failures averaged over a specific time window (Exponential moving average)
	AvgNodeFailureTolerance string `json:"avgNodeFailure,omitempty"`
	// Avg energy consumption of the node
	AvgNodeEnergyExpenditure string `json:"avgNodeEnergy,omitempty"`
}

// CodecoAppStatus defines the observed state of CodecoApp
type CodecoAppStatus struct {
	// INSERT ADDITIONAL STATUS FIELD - define observed state of cluster
	// Important: Run "make" to regenerate code after modifying this file

	//+kubebuilder:validation:Enum=OK;Warning;Error

	// Status expresses the CODECO application status by the CODECO framework. Edit codecoapp_types.go to remove/update
	Status CodecoStatus `json:"status,omitempty"`
	// ErrorMsg describes the CODECO application error. Edit codecoapp_types.go to remove/update
	ErrorMsg string `json:"errorMsg,omitempty"`
	// Observed and Aggregated metrics from Codeco App Nodes
	NodeMetrics []CodecoAppNodeStatusMetrics `json:"nodeMetrics,omitempty"`
	// CodecoAppStatusMetrics defines the observed metrics of CodecoApp
	AppMetrics CodecoAppStatusMetrics `json:"appMetrics,omitempty"`
}

//+kubebuilder:object:root=true
//+kubebuilder:subresource:status

// CodecoApp is the Schema for the codecoapps API
type CodecoApp struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   CodecoAppSpec   `json:"spec,omitempty"`
	Status CodecoAppStatus `json:"status,omitempty"`
}

//+kubebuilder:object:root=true

// CodecoAppList contains a list of CodecoApp
type CodecoAppList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []CodecoApp `json:"items"`
}

func init() {
	SchemeBuilder.Register(&CodecoApp{}, &CodecoAppList{})
}
