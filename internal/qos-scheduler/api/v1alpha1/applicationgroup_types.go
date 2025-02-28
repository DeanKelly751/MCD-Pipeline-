// SPDX-FileCopyrightText: 2023 Siemens AG
// SPDX-License-Identifier: Apache-2.0

package v1alpha1

import meta "k8s.io/apimachinery/pkg/apis/meta/v1"

// ApplicationGroupSpec describes an application group.
// Members of an application group are identified by having a label
// application-group with value equal to this group's name.
type ApplicationGroupSpec struct {

	// MinMember says how many applications matching the label query
	// need to be either running or waiting in order for scheduling
	// to begin. The default is 1.
	// +optional
	// +kubebuilder:default:=1
	MinMember int32 `json:"minMember,omitempty"`
}

// ApplicationGroupStatus defines the observed state of ApplicationGroup
type ApplicationGroupStatus struct {
	Phase ApplicationGroupPhase `json:"phase,omitempty" protobuf:"bytes,1,opt,name=phase,casttype=ApplicationGroupPhase"`

	LastUpdateTime meta.Time `json:"lastUpdateTime,omitempty" protobuf:"bytes,3,opt,name=lastUpdateTime"`

	SolverAttemptCount int `json:"solverAttemptCount"`
}

type ApplicationGroupPhase string

const (
	// The application group is waiting for there to be enough applications so
	// scheduling can begin.
	ApplicationGroupWaiting ApplicationGroupPhase = "Waiting"

	// The application group is waiting for Solve’s callback
	// to continue scheduling.
	ApplicationGroupPlacing ApplicationGroupPhase = "Placing"

	// The application group has received an assignment plan and
	// triggered scheduling. It will go back to Waiting once the applications
	// are running.
	ApplicationGroupScheduling ApplicationGroupPhase = "Scheduling"

	// Permanent failure, for example due to Solver returning non-retryable errors.
	ApplicationGroupFailed ApplicationGroupPhase = "Failed"
)

//+kubebuilder:object:root=true
//+kubebuilder:subresource:status
//+kubebuilder:resource:shortName=ag
//+kubebuilder:printcolumn:name="Status",type="string",JSONPath=".status.phase",description="Application group status"

// ApplicationGroup is a collection of Applications that should be
// scheduled together.
type ApplicationGroup struct {
	meta.TypeMeta `json:",inline"`

	meta.ObjectMeta `json:"metadata,omitempty"`

	Spec   ApplicationGroupSpec   `json:"spec,omitempty"`
	Status ApplicationGroupStatus `json:"status,omitempty"`
}

//+kubebuilder:object:root=true

// ApplicationGroupList contains a list of ApplicationGroup
type ApplicationGroupList struct {
	meta.TypeMeta `json:",inline"`
	meta.ListMeta `json:"metadata,omitempty"`
	Items         []ApplicationGroup `json:"items"`
}

func init() {
	SchemeBuilder.Register(&ApplicationGroup{}, &ApplicationGroupList{})
}
