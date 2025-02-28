// SPDX-FileCopyrightText: 2023 Siemens AG
// SPDX-License-Identifier: Apache-2.0

package v1alpha1

import (
	core "k8s.io/api/core/v1"
	meta "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// ApplicationSpec defines the desired state of an Application.
// An Application contains one or more ApplicationWorkloads
// (or Workloads for short) that can be explicitly connected
// via Channels with other Workloads.
type ApplicationSpec struct {
	// An Application specifies a number of Workloads.
	Workloads []ApplicationWorkloadSpec `json:"workloads" patchStrategy:"merge,retainKeys" patchMergeKey:"name" protobuf:"bytes,1,rep,name=workloads"`
}

// ApplicationStatus defines the observed state of Application
type ApplicationStatus struct {
	Phase ApplicationPhase `json:"phase,omitempty" protobuf:"bytes,1,opt,name=phase,casttype=ApplicationPhase"`

	Conditions []ApplicationCondition `json:"conditions,omitempty" patchStrategy:"merge" patchMergeKey:"entity" protobuf:"bytes,2,rep,name=conditions"`
}

type ApplicationPhase string

const (
	// The application has been created and is waiting for its application
	// group to signal that it can create pods.
	ApplicationWaiting ApplicationPhase = "Waiting"

	// The application can create pods. When an application enters this phase,
	// it expands its workload specs and creates pods, which go to the
	// scheduler. Once that is done, the application enters phase Pending.
	ApplicationScheduling ApplicationPhase = "Scheduling"

	// The application has created pods and at least one of those pods is
	// still waiting to be scheduled (the others may be running already).
	ApplicationPending ApplicationPhase = "Pending"

	// All the application's pods are either Running or Succeeded.
	ApplicationRunning ApplicationPhase = "Running"

	// At least one of the application's pods is in phase Failed.
	ApplicationFailing ApplicationPhase = "Failing"
)

// ApplicationCondition is the reason why an application may have entered
// a failing state. The type is a failure type (channel down vs. pod failed etc).
// The Entity is the name of the object that failed, such as a connection or a pod.
// The Reason field can be used for additional information for logging or display.
type ApplicationCondition struct {
	Type           ApplicationConditionType `json:"type" protobuf:"bytes,1,opt,name=type,casttype=ApplicationConditionType"`
	LastUpdateTime meta.Time                `json:"lastUpdateTime,omitempty" protobuf:"bytes,2,opt,name=lastUpdateTime"`
	Entity         string                   `json:"entity,omitempty" protobuf:"bytes,3,opt,name=entity"`
	Reason         string                   `json:"reason,omitempty" protobuf:"bytes,4,opt,name=reason"`
	Status         core.ConditionStatus     `json:"status,omitempty" protobuf:"bytes,5,opt,name=status"`
}

type ApplicationConditionType string

const (
	ApplicationChannelNack      ApplicationConditionType = "ChannelNack"
	ApplicationChannelQoS       ApplicationConditionType = "ChannelQoS"
	ApplicationChannelCanceled  ApplicationConditionType = "ChannelCanceled"
	ApplicationPodUnschedulable ApplicationConditionType = "PodUnschedulable"
	ApplicationNotRunning       ApplicationConditionType = "NotRunning"
	ApplicationPodFailed        ApplicationConditionType = "PodFailed"
	ApplicationOk               ApplicationConditionType = "Ok"
)

//+kubebuilder:object:root=true
//+kubebuilder:subresource:status
//+kubebuilder:resource:shortName=app
//+kubebuilder:printcolumn:name="Status",type="string",JSONPath=".status.phase",description="Application status"

const (
	AnnotationNewChannels = "qos-scheduler.siemens.com/new-channels"
	AnnotationPlanTrigger = "qos-scheduler.siemens.com/plan-trigger"
)

// Application is the Schema for the applications API
type Application struct {
	meta.TypeMeta   `json:",inline"`
	meta.ObjectMeta `json:"metadata,omitempty"`

	Spec   ApplicationSpec   `json:"spec,omitempty"`
	Status ApplicationStatus `json:"status,omitempty"`
}

//+kubebuilder:object:root=true

// ApplicationList contains a list of Application
type ApplicationList struct {
	meta.TypeMeta `json:",inline"`
	meta.ListMeta `json:"metadata,omitempty"`
	Items         []Application `json:"items"`
}

func init() {
	SchemeBuilder.Register(&Application{}, &ApplicationList{})
}
