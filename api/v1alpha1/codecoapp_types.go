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

// CodecoAppSpec defines the desired state of CodecoApp
type CodecoAppSpec struct {
	// INSERT ADDITIONAL SPEC FIELDS - desired state of cluster
	// Important: Run "make" to regenerate code after modifying this file

	// Name is an used to identify the CODECO application. Edit codecoapp_types.go to remove/update
	Name string `json:"name,omitempty"`

	//+kubebuilder:validation:Enum=High;Medium;Dev

	// QosClass is used to identify the CODECO application QoS. Edit codecoapp_types.go to remove/update
	QosClass CodecoQosClass `json:"qosclass,omitempty"`

	//+kubebuilder:validation:Enum=Gold;Silver;BestEffort

	// SecurityClass is used to identify the CODECO application security class. Edit codecoapp_types.go to remove/update
	SecurityClass CocdcoSecurityClass `json:"securityclass,omitempty"`
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
