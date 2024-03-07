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
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

type CodecoQosClass string

const (
	Gold       CodecoQosClass = "Gold"
	Silver     CodecoQosClass = "Silver"
	BestEffort CodecoQosClass = "BestEffort"
)

type CodecoComplianceClass string

const (
	Compliant    CodecoComplianceClass = "Compliant"
	NonCompliant CodecoComplianceClass = "Non-Compliant"
)

type CocdcoSecurityClass string

const (
	High   CocdcoSecurityClass = "High"
	Medium CocdcoSecurityClass = "Medium"
	Dev    CocdcoSecurityClass = "Dev"
)

type CodecoStatus string

const (
	OK      CodecoStatus = "OK"
	Warning CodecoStatus = "Warning"
	Error   CodecoStatus = "Error"
)

// EDIT THIS FILE!  THIS IS SCAFFOLDING FOR YOU TO OWN!
// NOTE: json tags are required.  Any new fields you add must have json tags for the fields to be serialized.

// CodecoAppResource defines the resource consumption of CodecoApp
type CodecoAppResource struct {
	//+kubebuilder:validation:default=100
	CpuUsagePct string `json:"cpu,omitempty"`

	//+kubebuilder:validation:default=8
	MemUsageGB string `json:"mem,omitempty"`

	//+kubebuilder:validation:default=25
	NWBandwidthMbs string `json:"nwbandwidth,omitempty"`

	//+kubebuilder:validation:default=10
	NWLatencyMs string `json:"nwlatency,omitempty"`
}

// CodecoAppMSSpec defines the desired state of CodecoApp micro service
type CodecoAppMSSpec struct {
	// INSERT ADDITIONAL SPEC FIELDS - desired state of cluster
	// Important: Run "make" to regenerate code after modifying this file

	// Name is an used to identify the CODECO micro service. Edit codecoapp_types.go to remove/update
	Name string `json:"name"`

	// A reference to the PodSpec of the microservice. Edit codecoapp_types.go to remove/update
	PodSpecName string `json:"podspecname"`

	// RequiredResources is used to identify the CODECO micro service required resources. Edit codecoapp_types.go to remove/update
	RequiredResources CodecoAppResource `json:"required-resources,omitempty"`
}

// CodecoAppSpec defines the desired state of CodecoApp
type CodecoAppSpec struct {
	// INSERT ADDITIONAL SPEC FIELDS - desired state of cluster
	// Important: Run "make" to regenerate code after modifying this file

	// Name is an used to identify the CODECO application. Edit codecoapp_types.go to remove/update
	Name string `json:"name,omitempty"`

	//+kubebuilder:validation:Enum=High;Medium;Dev

	// QosClass is used to identify the CODECO application QoS. Edit codecoapp_types.go to remove/update
	QosClass CodecoQosClass `json:"qosclass,omitempty"`

	//+kubebuilder:validation:MinItems=1
	// MCSpecs is used to identify the CODECO micro services which compose the application. Edit codecoapp_types.go to remove/update
	MCSpecs []CodecoAppMSSpec `json:"codecoapp-msspec,omitempty"`

	//+kubebuilder:validation:Enum=Gold;Silver;BestEffort

	// SecurityClass is used to identify the CODECO application security class. Edit codecoapp_types.go to remove/update
	SecurityClass    CocdcoSecurityClass   `json:"securityclass,omitempty"`
	ComplianceClass  CodecoComplianceClass `json:"complianceclass,omitempty"`
	AppEnergyLimit   string                `json:"appenergylimit,omitempty"`
	FailureTolerance string                `json:"appfailuretolerance,omitempty"`
}

// CodecoAppStatusMetrics defines the observed metrics of CodecoApp
type CodecoAppStatusMetrics struct {
	Numpods        int    `json:"numpods,omitempty"`
	AvgLoad        uint64 `json:"avgload,omitempty"`
	NetworkAvgLoad uint64 `json:"networkavgload,omitempty"`
}

// Observed and Aggregated metrics from Codeco App Nodes
type CodecoAppNodeStatusMetrics struct {
	NodeName                 string `json:"node_name,omitempty"`
	AvgCpuUsage              string `json:"node_cpu,omitempty"`
	AvgMemoryUsage           string `json:"node_memory,omitempty"`
	AvgNodeFailureTelerance  string `json:"node_failure,omitempty"`
	AvgNodeEnergyExpenditure string `json:"node_energy,omitempty"`
	AvgNodeSecurity          string `json:"node_security,omitempty"`
}

// CodecoAppStatus defines the observed state of CodecoApp
type CodecoAppStatus struct {
	// INSERT ADDITIONAL STATUS FIELD - define observed state of cluster
	// Important: Run "make" to regenerate code after modifying this file

	//+kubebuilder:validation:Enum=OK;Warning;Error

	// Status expresses the CODECO application status by the CODECO framework. Edit codecoapp_types.go to remove/update
	Status CodecoStatus `json:"status,omitempty"`
	// ErrorMsg describes the CODECO application error. Edit codecoapp_types.go to remove/update
	ErrorMsg string `json:"errormsg,omitempty"`
	//Observed and Aggregated metrics from Codeco App Nodes
	NodeMetrics CodecoAppNodeStatusMetrics `json:"nodemetrics"`

	AppMetrics CodecoAppStatusMetrics `json:"appmetrics"`
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
