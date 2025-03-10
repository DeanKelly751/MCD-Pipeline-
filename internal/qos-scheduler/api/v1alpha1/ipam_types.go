// SPDX-FileCopyrightText: 2023 Siemens AG
// SPDX-License-Identifier: Apache-2.0

package v1alpha1

import meta "k8s.io/apimachinery/pkg/apis/meta/v1"

// An IpamSpec describes an IP address allocation.
// You can create an IpamSpec with just the number of addresses
// filled in. A controller will then reserve a CIDR for you and
// add it to the spec, if possible.
// If no CIDR can be reserved, the Ipam's status will be updated
// to "unfulfillable".
type IpamSpec struct {
	// NumberOfAddresses is the minimum number of addresses this ipam spec should cover.
	NumberOfAddresses int `json:"numberOfAddresses"`

	// Purpose is a text field for your own use, in case you have multiple IPAMs and
	// want to tell them apart, and encoding the purpose in the name does not work for you.
	// +optional
	Purpose string `json:"purpose"`
}

type IpamStatusCode string

const (
	// The status of an Ipam that has been created but no CIDR has
	// been allocated to it yet.
	IpamRequested IpamStatusCode = "REQUESTED"

	// The status of an Ipam for which a CIDR has been allocated.
	IpamReserved IpamStatusCode = "RESERVED"

	// The status of an Ipam for which no CIDR could be allocated.
	IpamUnfulfillable IpamStatusCode = "UNFULFILLABLE"
)

type IpamStatus struct {
	// The current status code of the ipam.
	// +kubebuilder:default:=REQUESTED
	StatusCode IpamStatusCode `json:"code"`

	// An Ipv4 CIDR range with at least numberOfAddresses addresses.
	// +optional
	IPv4Cidr string `json:"ipv4Cidr"`

	// An error message for an unsuccessful ipam reservation attempt.
	// This should only be set when the status code is Unfulfillable.
	// +optional
	Error string `json:"error"`
}

//+kubebuilder:object:root=true
//+kubebuilder:subresource:status
//+kubebuilder:resource:shortName=ipam

// Ipam describes an IP Address range reservation.
type Ipam struct {
	meta.TypeMeta   `json:",inline"`
	meta.ObjectMeta `json:"metadata,omitempty"`
	Spec            IpamSpec   `json:"spec,omitempty"`
	Status          IpamStatus `json:"status,omitempty"`
}

//+kubebuilder:object:root=true

// IpamList contains a list of Ipams.
type IpamList struct {
	meta.TypeMeta `json:",inline"`
	meta.ListMeta `json:"metadata,omitempty"`
	Items         []Ipam `json:"items"`
}

func init() {
	SchemeBuilder.Register(&Ipam{}, &IpamList{})
}
