// SPDX-FileCopyrightText: 2025 Siemens AG
// SPDX-License-Identifier: Apache-2.0

package controllers

import (
	"fmt"
	"strings"

	core "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/resource"
	meta "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/types"
	swm "siemens.com/qos-scheduler/api/v1alpha1"
)

var noGroup *swm.ApplicationGroup // constant

func Make(name types.NamespacedName, wlNames ...string) *swm.Application {
	app := &swm.Application{
		TypeMeta: meta.TypeMeta{
			Kind:       "Application",
			APIVersion: swm.GroupVersion.String()},
		ObjectMeta: meta.ObjectMeta{
			Name:      name.Name,
			Namespace: name.Namespace,
			Labels:    make(map[string]string)},
		Status: swm.ApplicationStatus{Phase: swm.ApplicationWaiting}}
	AddWorkloads(app, wlNames...)
	return app
}

func BelongsTo(app *swm.Application, group string) {
	app.Labels[swm.AppGroupLabel] = group
}

func AddWorkloads(app *swm.Application, wlNames ...string) {
	nodeAffinity := func(wl string) *core.NodeAffinity {
		key := fmt.Sprintf("test-key-%s-%s", app.Name, wl)
		reqs := []core.NodeSelectorRequirement{
			{Key: key, Operator: core.NodeSelectorOpExists}}
		return &core.NodeAffinity{
			RequiredDuringSchedulingIgnoredDuringExecution: &core.NodeSelector{
				NodeSelectorTerms: []core.NodeSelectorTerm{
					{MatchExpressions: reqs}}}}
	}
	container := func(wl, suf string, idx, mCpu, mb int) core.Container {
		name := fmt.Sprintf("%s-%d-%s", wl, idx, suf)
		cpu := *resource.NewMilliQuantity(int64(mCpu), resource.DecimalSI)
		ram := *resource.NewQuantity(int64(mb)*1024*1024, resource.BinarySI)
		return core.Container{
			Name:  name,
			Image: name,
			Resources: core.ResourceRequirements{
				Requests: core.ResourceList{
					"cpu":    cpu,
					"memory": ram}}}
	}
	workloads := make([]swm.ApplicationWorkloadSpec, len(wlNames))
	for idx, name := range wlNames {
		workloads[idx] = swm.ApplicationWorkloadSpec{
			Basename: name,
			Template: swm.QosPodTemplateSpec{
				Metadata: swm.QosMeta{
					Labels: map[string]string{
						"podId": fmt.Sprintf("pod-%d", idx)}},
				Spec: core.PodSpec{
					Affinity: &core.Affinity{
						NodeAffinity: nodeAffinity(name)},
					Containers: []core.Container{
						container(name, "container", idx, 500, 2048)},
					InitContainers: []core.Container{
						container(name, "init", idx, 10, 2)}}}}
	}
	app.Spec.Workloads = append(app.Spec.Workloads, workloads...)
}

func WorkloadByName(app *swm.Application, name string) int {
	for i := range app.Spec.Workloads {
		if app.Spec.Workloads[i].Basename == name {
			return i
		}
	}
	return -1
}

func SetRecomms(app *swm.Application, specs ...string) {
	for i := range app.Spec.Workloads {
		w := &app.Spec.Workloads[i]
		w.Costs, w.NodeRecommendations = nil, nil
	}
	for _, spec := range specs {
		if pcs := strings.Split(spec, ":"); len(pcs) == 2 {
			if i := WorkloadByName(app, pcs[0]); i >= 0 {
				wl, ns := &app.Spec.Workloads[i], strings.Split(pcs[1], ",")
				wl.NodeRecommendations = make(map[string]float64, len(ns))
				for i, n := range ns {
					value := 0.1
					if i == 0 {
						value = 0.9
					}
					wl.NodeRecommendations[n] = value
				}
			}
		}
	}
}

func makeApp(
	group *swm.ApplicationGroup, name string, workloads ...string,
) *swm.Application {
	qn := types.NamespacedName{Namespace: "default", Name: name}
	app := Make(qn, workloads...)
	if group != nil {
		app.Namespace = group.Namespace
		BelongsTo(app, group.Name)
	}
	return app
}
