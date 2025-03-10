// SPDX-FileCopyrightText: 2023 Siemens AG
// SPDX-License-Identifier: Apache-2.0

package v1alpha1

import meta "k8s.io/apimachinery/pkg/apis/meta/v1"

type NetworkPathSpec struct {
	// The linknode (should be a NetworkEndpoint) where this path starts.
	Start LinkNode `json:"start"`
	// The linknode (should be a NetworkEndpoint) where this path ends.
	End LinkNode `json:"end"`
	// The names of the NetworkLinks along this path spec.
	Links []string `json:"links"`
}

//+kubebuilder:object:root=true
//+kubebuilder:subresource:status
//+kubebuilder:resource:shortName:nwp
//+kubebuilder:printcolumn:name="start",type="string",JSONPath=".spec.start.name",description="start"
//+kubebuilder:printcolumn:name="end",type="string",JSONPath=".spec.end.name",description="end"
//+kubebuilder:printcolumn:name="Age",type="date",JSONPath=".metadata.creationTimestamp"

// NetworkPath is a list of NetworkLinks. It connects
// endpoints, which must be NetworkEndpoints.
type NetworkPath struct {
	meta.TypeMeta   `json:",inline"`
	meta.ObjectMeta `json:"metadata,omitempty"`

	Spec NetworkPathSpec `json:"spec,omitempty"`
}

//+kubebuilder:object:root=true

// NetworkPathList is a list of NetworkPaths.
type NetworkPathList struct {
	meta.TypeMeta `json:",inline"`
	meta.ListMeta `json:"metadata,omitempty"`
	Items         []NetworkPath `json:"items"`
}

func init() {
	SchemeBuilder.Register(&NetworkPath{}, &NetworkPathList{})
}
