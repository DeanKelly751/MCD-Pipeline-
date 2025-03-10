// SPDX-FileCopyrightText: 2023 Siemens AG
// SPDX-License-Identifier: Apache-2.0

package v1alpha1

import (
	meta "k8s.io/apimachinery/pkg/apis/meta/v1"
	solverG "siemens.com/qos-scheduler/solver/grpc"
)

type AssignmentPlanSpec struct {
	// +optional
	QoSModel solverG.Model `protobuf:"bytes,1,opt,name=qoSModel,proto3" json:"qoSModel,omitempty"`
}

type ActionCode int8

const (
	ActionCreatePod ActionCode = iota
	ActionDeletePod
	ActionCreateChannel
	ActionDeleteChannel
	ActionCreateEndpoint
	ActionDeleteEndpoint
	ActionReconfigureEndpoint
	ActionNone
)

type AssignmentAction struct {
	// what is to be done
	Action ActionCode `json:"action"`
	// name of target object
	Object string `json:"object"`
	// what object is the base of the base new object
	// +optional
	Proto string `json:"proto,omitempty"`
	// name of parameter object
	// +optional
	Param string `json:"param,omitempty"`
}

type AssignmentPlanActionInfo struct {
	// is the corresponding action done?
	Done bool `json:"done"`
	// if not empty indicates that there was an error
	// +optional
	Error string `json:"error,omitempty"`
}

type AssignmentPlanObjectInfo struct {
	// Name of pod or channel in cluster
	Name string `json:"name"`
	// Location of pod or channels (node or path)
	Location string `json:"location"`
}

// AssignmentPlanStatus describes the current state of an assignment plan.
type AssignmentPlanStatus struct {
	// map workload or channel to name of pod or channel in cluster
	// +optional
	ObjectTable map[string]AssignmentPlanObjectInfo `json:"clusterNames,omitempty"`
	// list of actions for assignment
	// +optional
	Actions []AssignmentAction `json:"actions,omitempty"`
	// list of actions results
	// +optional
	ActionInfos []AssignmentPlanActionInfo `json:"actionInfo,omitempty"`
	// hash of model fields relevant to scheduling as Solver saw it
	// +optional
	SolveHash string `json:"solveHash,omitempty"`
	// hash of model fields after model was updated with assignment
	// +optional
	ModelHash string `json:"modelHash,omitempty"`
	// Solver’s reply for assignment plan
	// +optional
	Reply *solverG.Reply `json:"reply,omitempty"`
	// One of {"Idle", "Placing", "Scheduling"}.  Indicates whether the plan
	// waits for Solver to finish (Placing) or implements the plan in the
	// cluster (Scheduling).
	// +optional
	Phase AssignmentPlanPhase `json:"phase,omitempty"`
	// SolverCalled contains the time Solver was called.
	// +optional
	SolverCalled meta.Time `json:"solverCalled,omitempty"`
}

type AssignmentPlanPhase string

const (
	// There is no scheduling activity at the moment.
	AssignmentPlanPhaseIdle AssignmentPlanPhase = "Idle"

	// The application can create pods. When an application enters this phase,
	// it expands its workload specs and creates pods, which go to the
	// scheduler. Once that is done, the application enters phase Pending.
	AssignmentPlanPhasePlacing AssignmentPlanPhase = "Placing"

	// The application has created pods and at least one of those pods is
	// still waiting to be scheduled (the others may be running already).
	AssignmentPlanPhaseScheduling AssignmentPlanPhase = "Scheduling"
)

//+kubebuilder:object:root=true
//+kubebuilder:subresource:status
//+kubebuilder:resource:shortName=ap
//+kubebuilder:printcolumn:name="PodStatus",type="string",JSONPath=".status.podStatus",description="Status of pods"

// AssignmentPlan describes the placement of the workloads and channels of an ApplicationGroup
// on the cluster nodes.
type AssignmentPlan struct {
	meta.TypeMeta   `json:",inline"`
	meta.ObjectMeta `json:"metadata,omitempty"`

	Spec   AssignmentPlanSpec   `json:"spec"`
	Status AssignmentPlanStatus `json:"status,omitempty"`
}

//+kubebuilder:object:root=true

// AssignmentPlanList contains a list of AssignmentPlan
type AssignmentPlanList struct {
	meta.TypeMeta `json:",inline"`
	meta.ListMeta `json:"metadata,omitempty"`

	Items []AssignmentPlan `json:"items"`
}

func init() {
	SchemeBuilder.Register(&AssignmentPlan{}, &AssignmentPlanList{})
}
