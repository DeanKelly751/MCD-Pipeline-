// Copyright (c) 2024 Red Hat, Inc
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// 
// SPDX-License-Identifier: Apache-2.0
// 
// Contributors:
//     [name] - [contribution]

package controllers

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"fmt"
	dc "github.com/fluidtruck/deepcopy"
	// "github.com/tidwall/pretty"
	"encoding/json"
	monitoringv1 "github.com/prometheus-operator/prometheus-operator/pkg/apis/monitoring/v1"
	"github.com/prometheus/client_golang/api"
	v1 "github.com/prometheus/client_golang/api/prometheus/v1"
	"github.com/prometheus/common/model"
	codecov1alpha1 "gitlab.eclipse.org/eclipse-research-labs/codeco-project/acm/api/v1alpha1"
	swmv1alpha1 "gitlab.eclipse.org/rcarrollred/qos-scheduler/scheduler/api/v1alpha1"
	"k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/log"
	"sigs.k8s.io/yaml"
	"time"
)

// CodecoAppReconciler reconciles a CodecoApp object
type CodecoAppReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

func readPrometheusRulesFromDir(dir string) ([]monitoringv1.PrometheusRule, error) {
	var rules []monitoringv1.PrometheusRule

	files, err := os.ReadDir(dir)
	if err != nil {
		fmt.Println("Error reading directory:", err)
		return nil, err
	}

	for _, file := range files {
		if strings.HasSuffix(file.Name(), ".yml") || strings.HasSuffix(file.Name(), ".yaml") {
			path := filepath.Join(dir, file.Name())
			data, err := os.ReadFile(path)
			if err != nil {
				return nil, err
			}

			var rule monitoringv1.PrometheusRule
			if err := yaml.Unmarshal(data, &rule); err != nil {
				return nil, err
			}

			rules = append(rules, rule)
		}
	}

	return rules, nil
}

func applyPrometheusRules(r *CodecoAppReconciler, rules []monitoringv1.PrometheusRule) error {
	for _, rule := range rules {
		existingRule := &monitoringv1.PrometheusRule{}

		err := r.Get(context.TODO(), client.ObjectKey{Namespace: "monitoring", Name: "prometheus-example-rules"}, existingRule)
		if err != nil {
			if errors.IsNotFound(err) {
				fmt.Println("Creating new prometheus rule")
				if err := r.Create(context.TODO(), &rule); err != nil {
					fmt.Println("Error creating rule")
					return err
				}
			} else {
				fmt.Println("Error fetching existing rule")
				return err
			}
		} else {
			// Update rules if already exists
			fmt.Println("Already exists: Updating rule")
			existingRule.Spec = rule.Spec
			err = r.Update(context.TODO(), existingRule)

			if err != nil {
				fmt.Print("Error updating rule")
				return err
			}
		}

	}

	return nil
}

func InitializePrometheusRules(r *CodecoAppReconciler) error {
	// Read the rules from the specified directory
	rules, err := readPrometheusRulesFromDir("/prom_rules")
	if err != nil {
		return err
	}

	// Apply the rules to the cluster
	return applyPrometheusRules(r, rules)
}

// Function to query Prometheus with a given query
func queryPrometheus(v1api v1.API, query string) model.Value {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	result, warnings, err := v1api.Query(ctx, query, time.Now())
	if err != nil {
		fmt.Printf("Error querying Prometheus: %v\n", err)
		return nil
	}
	if len(warnings) > 0 {
		fmt.Printf("Warnings: %v\n", warnings)
	}
	// fmt.Printf("Query:\n%v\n", query)
	// fmt.Printf("Result:\n%v\n", result)
	// fmt.Printf("Result Type:%v\n", result.Type())

	return result
}

func getPodInfo(acmApp *codecov1alpha1.CodecoApp, v1api v1.API) {
	query := "pod:pod_info:current{created_by_name='acm-swm-app'}"
	result := queryPrometheus(v1api, query)

	if result.Type() == model.ValVector {
		vector := result.(model.Vector)

		for i, obj := range vector {
			// Extract metadata labels
			labels := obj.Metric
			podName := labels["pod"]
			nodeName := labels["node"]

			// Print metadata labels
			fmt.Printf("Pod: %s, Node: %s\n", podName, nodeName)

			acmApp.Status.AppMetrics.ServiceMetrics[i].PodName = string(podName)
			acmApp.Status.AppMetrics.ServiceMetrics[i].NodeName = string(nodeName)
			acmApp.Status.AppMetrics.ServiceMetrics[i].ClusterName = "codeco-cluster-1" // Statically fixed for now, OCM in future
		}
	} else {
		fmt.Print("Invalid result type")
	}
}

func getServiceMetricsFromPrometheus(acmApp *codecov1alpha1.CodecoApp, v1api v1.API) {

	fmt.Println(time.Now().Format(time.UnixDate), "---------------------- Get service level metrics -----------------------")

	// Ensure ServiceMetrics is properly sized
	if len(acmApp.Status.AppMetrics.ServiceMetrics) < len(acmApp.Spec.Workloads) {
		acmApp.Status.AppMetrics.ServiceMetrics = make([]codecov1alpha1.ServiceStatusMetrics, len(acmApp.Spec.Workloads))
	}

	getPodInfo(acmApp, v1api)

	queries := map[string]string{
		"AvgCpuUsage":    `pod:container_cpu:rate1m{pod="%s"}`,
		"AvgMemoryUsage": `pod:container_memory:avg1m{pod="%s"}`,
	}

	for i, service := range acmApp.Spec.Workloads {

		acmApp.Status.AppMetrics.ServiceMetrics[i].ServiceName = service.BaseName

		for metric, query := range queries {

			query := fmt.Sprintf(query, acmApp.Status.AppMetrics.ServiceMetrics[i].PodName)
			result := queryPrometheus(v1api, query)

			if result.Type() == model.ValVector {
				vector := result.(model.Vector)

				for _, obj := range vector {
					stringValue := fmt.Sprintf("%f", obj.Value)
					switch metric {
					case "AvgCpuUsage":
						acmApp.Status.AppMetrics.ServiceMetrics[i].AvgServiceCpuUsage = stringValue
					case "AvgMemoryUsage":
						acmApp.Status.AppMetrics.ServiceMetrics[i].AvgServiceMemoryUsage = stringValue
					}
				}
			} else {
				fmt.Print("Invalid result type")
			}
		}
	}
}

func getAppMetricsFromPrometheus(acmApp *codecov1alpha1.CodecoApp, v1api v1.API) {

	fmt.Println(time.Now().Format(time.UnixDate), "---------------------- Get app level metrics -----------------------")

	queries := map[string]string{
		"AvgCpuUsage":    `app:container_cpu:rate1m{pod=~"acm-swm-app-.*"}`,
		"AvgMemoryUsage": `app:container_memory:avg1m{pod=~"acm-swm-app-.*"}`,
		"Numpods":        `count(pod:pod_info:current{created_by_name="acm-swm-app"})`,
	}

	for metric, query := range queries {
		result := queryPrometheus(v1api, query)

		if result.Type() == model.ValVector {
			vector := result.(model.Vector)

			for _, obj := range vector {
				stringValue := fmt.Sprintf("%f", obj.Value)
				switch metric {
				case "AvgCpuUsage":
					acmApp.Status.AppMetrics.AvgAppCpuUsage = stringValue
				case "AvgMemoryUsage":
					acmApp.Status.AppMetrics.AvgAppMemoryUsage = stringValue
				case "Numpods":
					acmApp.Status.AppMetrics.Numpods = int(obj.Value)
				}
			}
		} else {
			fmt.Print("Invalid result type")
		}

	}
	getServiceMetricsFromPrometheus(acmApp, v1api)
}

func getNodeInfo(acmApp *codecov1alpha1.CodecoApp, v1api v1.API) {

	query := "instance:node_info:current"
	result := queryPrometheus(v1api, query)

	if result.Type() == model.ValVector {
		vector := result.(model.Vector)
		acmApp.Status.NodeMetrics = make([]codecov1alpha1.CodecoAppNodeStatusMetrics, len(vector))
		for i, obj := range vector {
			// Extract metadata labels
			nodeName := obj.Metric["node"]
			// Print metadata labels
			fmt.Printf("Node: %s\n", nodeName)
			acmApp.Status.NodeMetrics[i].NodeName = string(nodeName)
		}
	} else {
		fmt.Print("Invalid result type")
	}

}

func getNodeMetricsFromPrometheus(acmApp *codecov1alpha1.CodecoApp, v1api v1.API) {

	fmt.Println(time.Now().Format(time.UnixDate), "---------------------- Get node level metrics -----------------------")

	getNodeInfo(acmApp, v1api)

	queries := map[string]string{
		"AvgCpuUsage":              "instance:node_cpu:rate1m",
		"AvgMemoryUsage":           "instance:node_memory:avg1m",
		"AvgNodeEnergyExpenditure": "instance:node_energy:irate1m",
		"AvgNodeFailureTolerance":  "instance:node_status:avg1m",
	}

	for metric, query := range queries {
		result := queryPrometheus(v1api, query)

		if result.Type() == model.ValVector {
			vector := result.(model.Vector)

			// Create a map for quick lookup of metric values for each node
			lookup := make(map[string]string)
			for _, obj := range vector {
				lookup[string(obj.Metric["instance"])] = fmt.Sprintf("%f", obj.Value)
			}
			for i := range acmApp.Status.NodeMetrics {
				if val, found := lookup[acmApp.Status.NodeMetrics[i].NodeName]; found {
					switch metric {
					case "AvgCpuUsage":
						acmApp.Status.NodeMetrics[i].AvgCpuUsage = val
					case "AvgMemoryUsage":
						acmApp.Status.NodeMetrics[i].AvgMemoryUsage = val
					case "AvgNodeEnergyExpenditure":
						acmApp.Status.NodeMetrics[i].AvgNodeEnergyExpenditure = val
					case "AvgNodeFailureTolerance":
						acmApp.Status.NodeMetrics[i].AvgNodeFailureTolerance = val
					}
				}
			}
		} else {
			fmt.Print("Invalid result type")
		}
	}
}

func getMetricsFromPrometheus(acmApp *codecov1alpha1.CodecoApp) {

	client, err := api.NewClient(api.Config{
		Address: "http://prometheus-k8s.monitoring.svc.cluster.local:9090",
	})
	if err != nil {
		fmt.Printf("Error creating client: %v\n", err)
		return
	}

	v1api := v1.NewAPI(client)

	getNodeMetricsFromPrometheus(acmApp, v1api)
	getAppMetricsFromPrometheus(acmApp, v1api)

}

//+kubebuilder:rbac:groups=codeco.he-codeco.eu,resources=codecoapps,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=codeco.he-codeco.eu,resources=codecoapps/status,verbs=get;update;patch
//+kubebuilder:rbac:groups=codeco.he-codeco.eu,resources=codecoapps/finalizers,verbs=update

// Reconcile is part of the main kubernetes reconciliation loop which aims to
// move the current state of the cluster closer to the desired state.
// TODO(user): Modify the Reconcile function to compare the state specified by
// the CodecoApp object against the actual cluster state, and then
// perform operations to make the cluster state reflect the state specified by
// the user.
//
// For more details, check Reconcile and its Result here:
// - https://pkg.go.dev/sigs.k8s.io/controller-runtime@v0.14.1/pkg/reconcile
func (r *CodecoAppReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	_ = log.FromContext(ctx)

	fmt.Println(time.Now().Format(time.UnixDate), "---------------------- Starting Reconciliation Loop -----------------------")


	codecoAppCR := &codecov1alpha1.CodecoApp{}

	// GET Codeco Application
	fmt.Println(time.Now().Format(time.UnixDate), "---------------------- GET ACM App -----------------------")

	if err := r.Get(ctx, req.NamespacedName, codecoAppCR); err != nil {
		fmt.Printf("Error getting Codeco CR \n")
		if errors.IsNotFound(err) {
			// Request object not found, could have been deleted after reconcile request.
			return ctrl.Result{}, nil
		}
		return ctrl.Result{}, err
	}

	fmt.Println(time.Now().Format(time.UnixDate), "CodecoApp App :", codecoAppCR.Spec.AppName)
	fmt.Println(time.Now().Format(time.UnixDate), "CodecoApp QOS :", codecoAppCR.Spec.QosClass)

	qos_scheduler_app := &swmv1alpha1.Application{}
	qos_scheduler_new_app := &swmv1alpha1.Application{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "acm-swm-app",
			Namespace: codecoAppCR.Namespace,
			Labels: map[string]string{
				"application-group": "acm-applicationgroup",
			},
		},
	}
	qos_scheduler_new_application_group := &swmv1alpha1.ApplicationGroup{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "acm-applicationgroup",
			Namespace: codecoAppCR.Namespace,
		},
	}
	qos_scheduler_app_list := &swmv1alpha1.ApplicationList{}
	qos_scheduler_app2 := &swmv1alpha1.Application{}

	fmt.Println(time.Now().Format(time.UnixDate), "---------------------- List SWM Apps -----------------------")

	// GET SWM Application

	//Question: What is the correct value to find the SWM application list?
	if err := r.List(ctx, qos_scheduler_app_list, client.MatchingLabels{"application-group": "applicationgroup-demo"}); err != nil {
		fmt.Printf("Error getting SWM CR \n")
		if errors.IsNotFound(err) {
			// Request object not found, could have been deleted after reconcile request.
			return ctrl.Result{}, nil
		}
		return ctrl.Result{}, err
	}

	for _, s := range qos_scheduler_app_list.Items {
		if qos_scheduler_app != nil {
			//fmt.Printf("\n\nSWM App : %v\n\n", qos_scheduler_app)
			fmt.Println(time.Now().Format(time.UnixDate), "SWM App Name: ", s.Name)
			fmt.Println(time.Now().Format(time.UnixDate), "SWM App Phase: ", s.Status.Phase)
			fmt.Println(time.Now().Format(time.UnixDate), "SWM App 1 W1: ", s.Spec.Workloads[0].Basename)
			fmt.Println(time.Now().Format(time.UnixDate), "SWM App 1 W1 Service Class: ", s.Spec.Workloads[0].Channels[0].ServiceClass)
			fmt.Println(time.Now().Format(time.UnixDate), "SWM App 1 W2 Name: ", s.Spec.Workloads[1].Basename)
			fmt.Println(time.Now().Format(time.UnixDate), "SWM App 1 W2 Service Class: ", s.Spec.Workloads[1].Channels[0].ServiceClass)
		} else {
			fmt.Printf("SWM App - didn't get it \n")
		}
	}

	/*if err := r.Get(ctx, client.ObjectKey{Namespace: "default", Name: "app1"}, qos_scheduler_app); err != nil {
		fmt.Printf("Error getting SWM CR \n")
		if errors.IsNotFound(err) {
			// Request object not found, could have been deleted after reconcile request.
			return ctrl.Result{}, nil
		}
		return ctrl.Result{}, err
	}*/

	fmt.Println(time.Now().Format(time.UnixDate), " ------------------- CREATING SWM APPLICATION GROUP ------------------------- ")

	qos_scheduler_new_application_group.Spec = swmv1alpha1.ApplicationGroupSpec{}

	err := r.Get(ctx, client.ObjectKey{Namespace: codecoAppCR.Namespace, Name: "acm-applicationgroup"}, qos_scheduler_new_application_group)
	if err != nil {
		if errors.IsNotFound(err) {
			fmt.Println("Creating new SWM application group")
			if err := r.Create(ctx, qos_scheduler_new_application_group); err != nil {
				fmt.Println("Error creating SWM application group")
				return ctrl.Result{}, err
			}
		} else {
			return ctrl.Result{}, err
		}
	} else {
		fmt.Println("SWM application group already exists")
	}

	fmt.Println(time.Now().Format(time.UnixDate), " ------------------- CREATING SWM APP ------------------------- ")

	qos_scheduler_new_app.Spec = swmv1alpha1.ApplicationSpec{}
	qos_scheduler_new_app.Spec.Workloads = []swmv1alpha1.ApplicationWorkloadSpec{}

	// Map from Codeco Application Model to SWM Application Model
	MapToSWMApplicationModel(codecoAppCR, qos_scheduler_new_app)
	fmt.Println(time.Now().Format(time.UnixDate), " ------------------- SWM APP ------------------------- ")
	jsonswm, error := json.MarshalIndent(qos_scheduler_new_app, "", "   ")
	fmt.Println(string(jsonswm))
	if err != nil {
		fmt.Println(error)
	}
	err = r.Get(ctx, client.ObjectKey{Namespace: codecoAppCR.Namespace, Name: "acm-swm-app"}, qos_scheduler_new_app)
	if err != nil {
		fmt.Println("Creating new SWM app")
		if err := r.Create(ctx, qos_scheduler_new_app); err != nil {
			fmt.Println("Error creating SWM")
			return ctrl.Result{}, err
		}
	} else {
		// Update SWM Application if already exists
		fmt.Println("Already exists: Updating SWM app")
		err = r.Update(ctx, qos_scheduler_new_app)

		if err != nil {
			fmt.Print("Error updating swm")
			return ctrl.Result{}, err
		}
	}

	// WAIT 8secs just to ensure UPDATE has completed
	fmt.Println(time.Now().Format(time.UnixDate), "------ Waiting 8 seconds -------")
	time.Sleep(8 * time.Second)

	if err := r.Get(ctx, client.ObjectKey{Namespace: codecoAppCR.Namespace, Name: "acm-swm-app"}, qos_scheduler_app2); err != nil {
		fmt.Printf("\n\nError Returning SWM CRD: %v\n\n", err)
		if errors.IsNotFound(err) {
			// Request object not found, could have been deleted after reconcile request.
			return ctrl.Result{}, nil
		}
		return ctrl.Result{}, err
	}

	// fmt.Print("\n\n", qos_scheduler_new_app)
	// json_SWM, _ := json.Marshal(qos_scheduler_new_app)
	// fmt.Println("\n\nNew SWM app JSON:\n", string(pretty.Pretty(json_SWM)))

	fmt.Println(time.Now().Format(time.UnixDate), "SWM App :", qos_scheduler_app2.Name)
	fmt.Println(time.Now().Format(time.UnixDate), "SWM App Phase3 :", qos_scheduler_app2.Status.Phase)
	fmt.Println(time.Now().Format(time.UnixDate), "SWM App W1 Basename:", qos_scheduler_app2.Spec.Workloads[0].Basename)

	//if codecoAppCR.Status.Status == "" {
	//	codecoAppCR.Status.Status = codecov1alpha1.OK
	//} else {
	// intentionally do nothing
	//}

	//err := r.Status().Update(ctx, codecoAppCR)

	fmt.Println(time.Now().Format(time.UnixDate), "---------------------- Update ACM App status metrics -----------------------")

	getMetricsFromPrometheus(codecoAppCR)
	err = r.Status().Update(ctx, codecoAppCR)
	if err != nil {
		fmt.Print("Error updating codecoAppCR")
		return ctrl.Result{}, err
	}

	fmt.Println("CODECO App status metrics -----------------------")

	jsonacm, err := json.MarshalIndent(codecoAppCR, "", "   ")
	fmt.Println(string(jsonacm))
	if err != nil {
		fmt.Println(err)
	}
	return ctrl.Result{RequeueAfter: time.Minute}, nil
}

// SetupWithManager sets up the controller with the Manager.
func (r *CodecoAppReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&codecov1alpha1.CodecoApp{}). //Owns()
		Complete(r)
}

func CreateNewSWMApplicationModel() {

}

// Function to Map from Codeco Application Model to SWM Application Model
func MapToSWMApplicationModel(codecoApp *codecov1alpha1.CodecoApp, swmApp *swmv1alpha1.Application) {

	dc.DeepCopy(codecoApp.Spec, &swmApp.Spec)

	for i := range codecoApp.Spec.Workloads {
		dc.DeepCopy(codecoApp.Spec.Workloads[i].Template, &swmApp.Spec.Workloads[i].Template.Spec)
		dc.DeepCopy(codecoApp.Spec.Workloads[i].Channels, &swmApp.Spec.Workloads[i].Channels)
		for j := range codecoApp.Spec.Workloads[i].Channels {
			dc.DeepCopy(codecoApp.Spec.Workloads[i].Channels[j].AdvancedChannelSettings, &swmApp.Spec.Workloads[i].Channels[j])
		}
	}

}

