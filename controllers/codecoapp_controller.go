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

package controllers

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	// "encoding/json"
	"fmt"
	dc "github.com/fluidtruck/deepcopy"
	// "github.com/tidwall/pretty"
	"encoding/json"
	monitoringv1 "github.com/prometheus-operator/prometheus-operator/pkg/apis/monitoring/v1"
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
			fmt.Println("Creating new prometheus rule")
			if err := r.Create(context.TODO(), &rule); err != nil {
				fmt.Println("Error creating rule")
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

func initializePrometheusRules(r *CodecoAppReconciler) error {
	// Read the rules from the specified directory
	rules, err := readPrometheusRulesFromDir("/prom_rules")
	if err != nil {
		return err
	}

	// Apply the rules to the cluster
	return applyPrometheusRules(r, rules)
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

	// Initialize and apply Prometheus rules on startup
	err := initializePrometheusRules(r)
	if err != nil {
		fmt.Print(err, "unable to initialize Prometheus rules")
		os.Exit(1)
	}

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

	err = r.Get(ctx, client.ObjectKey{Namespace: codecoAppCR.Namespace, Name: "acm-applicationgroup"}, qos_scheduler_new_application_group)
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

// Function to Map from Codeco Apllication Model to SWM Application Model
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
