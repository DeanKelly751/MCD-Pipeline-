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
	"fmt"
	codecov1alpha1 "gitlab.eclipse.org/eclipse-research-labs/codeco-project/acm/api/v1alpha1"
	swmv1alpha1 "gitlab.eclipse.org/rcarrollred/qos-scheduler/scheduler/api/v1alpha1"
	"k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/log"
	"time"
)

// CodecoAppReconciler reconciles a CodecoApp object
type CodecoAppReconciler struct {
	client.Client
	Scheme *runtime.Scheme
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

	codecoAppCR := &codecov1alpha1.CodecoApp{}
	qos_scheduler_app := &swmv1alpha1.Application{}
	qos_scheduler_new_app := &swmv1alpha1.Application{}
	qos_scheduler_app_list := &swmv1alpha1.ApplicationList{}
	qos_scheduler_app2 := &swmv1alpha1.Application{}

	// GET Codeco Application

	if err := r.Get(ctx, req.NamespacedName, codecoAppCR); err != nil {
		fmt.Printf("Error getting Codeco CR \n")
		if errors.IsNotFound(err) {
			// Request object not found, could have been deleted after reconcile request.
			return ctrl.Result{}, nil
		}
		return ctrl.Result{}, err
	}

	fmt.Printf("CodecoApp QOS : %v\n", codecoAppCR.Spec.QosClass)

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
			fmt.Printf("\n\nSWM App Phase: %v\n", s.Status.Phase)
			fmt.Printf("\n\nSWM App Name: %v\n", s.Name)
			fmt.Printf("\n\nSWM App 1 W1: %v\n", s.Spec.Workloads[0].Basename)
			fmt.Printf("\n\nSWM App 1 W1 Service Class: %v\n\n", s.Spec.Workloads[0].Channels[0].ServiceClass)
			fmt.Printf("\n\nSWM App 1 W2 Name: %v\n", s.Spec.Workloads[1].Basename)
			fmt.Printf("\n\nSWM App 1 W2 Service Class: %v\n\n", s.Spec.Workloads[1].Channels[0].ServiceClass)
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

	// TODO
	// 1. Map Codeco App to SWM App (locally)

	qos_scheduler_new_app.Name = "app3"
	qos_scheduler_new_app.Namespace = "default"
	qos_scheduler_new_app.Spec = swmv1alpha1.ApplicationSpec{}
	qos_scheduler_new_app.Spec.Workloads = []swmv1alpha1.ApplicationWorkloadSpec{}

	var addvalue swmv1alpha1.Application
	addvalue = *qos_scheduler_new_app

	qos_scheduler_app_list.Items = append(qos_scheduler_app_list.Items, addvalue)
	// 2. Push new SWM App to SWM ApplicationList

	/*qos_scheduler_app.Status.Phase = swmv1alpha1.ApplicationWaiting

	if qos_scheduler_app.Spec.Workloads[0].Channels[0].ServiceClass == swmv1alpha1.ServiceClassBestEffort {
		fmt.Printf("Change to Assured")
		qos_scheduler_app.Spec.Workloads[0].Channels[0].ServiceClass = swmv1alpha1.ServiceClassAssured
	} else {
		fmt.Printf("Change to Best Effort")
		qos_scheduler_app.Spec.Workloads[0].Channels[0].ServiceClass = swmv1alpha1.ServiceClassBestEffort
	}

	fmt.Printf("\n\nSWM App Phase2 : %v\n\n", qos_scheduler_app.Status.Phase)
	*/
	/// -------------------- UPDATE SWM Application --------------------------------------
	//fmt.Printf("\n\nUpdating SWM App 1 W1 Service Class to: %v\n\n", qos_scheduler_app.Spec.Workloads[0].Channels[0].ServiceClass)

	fmt.Printf("\n ------------------- UPDATING SWM ------------------------- \n")

	//if uperr := r.Update(ctx, *qos_scheduler_app_list); uperr != nil {
	if uperr := r.Create(ctx, qos_scheduler_new_app); uperr != nil {
		//if uperr := r.CoreV1().Pods("default").Create(ctx, qos_scheduler_new_app); uperr != nil {
		//.Create(context.TODO(), deployment, metav1.CreateOptions{})
		fmt.Printf("\n\nError Updating SWM: %v\n\n", uperr)
		return ctrl.Result{}, nil
	}

	// WAIT 8secs just to ensure UPDATE has completed
	fmt.Printf("\n\n ------ Waiting 8 seconds ------- %v\n\n", uperr)
	time.Sleep(8 * time.Second)

	if err := r.Get(ctx, client.ObjectKey{Namespace: "default", Name: "app1"}, qos_scheduler_app2); err != nil {
		fmt.Printf("\n\nError Returning SWM CRD: %v\n\n", uperr)
		if errors.IsNotFound(err) {
			// Request object not found, could have been deleted after reconcile request.
			return ctrl.Result{}, nil
		}
		return ctrl.Result{}, err
	}

	fmt.Printf("\n\nSWM App Phase3 : %v\n\n", qos_scheduler_app2.Status.Phase)
	fmt.Printf("\n\nSWM App Service Class: %v\n\n", qos_scheduler_app2.Spec.Workloads[0].Channels[0].ServiceClass)

	// TODO(user): your logic here

	if codecoAppCR.Status.Status == "" {
		codecoAppCR.Status.Status = codecov1alpha1.OK
	} else {
		// intentionally do nothing
	}

	if codecoAppCR.Status.ErrorMsg == "" {

		//pod := &corev1.Pod{}

		// c is a created client.
		_ = r.Get(context.Background(), client.ObjectKey{
			Namespace: "default", //qos-scheduler
			Name:      "app1",
		}, qos_scheduler_app)

		fmt.Printf("Checking the SWM operator ")

		if qos_scheduler_app != nil {
			codecoAppCR.Status.ErrorMsg = string(qos_scheduler_app.Status.Phase)
			//codecoAppCR.Status.ErrorMsg = "No errors " + qos_scheduler_app.Status.Phase
		} else {
			codecoAppCR.Status.ErrorMsg = "can't get SWM details"
		}

		fmt.Printf("SWM Operator: %v\n", qos_scheduler_app.Status.Phase)
	} else {
		// intentionally do nothing
	}

	//fmt.Printf("CodecoApp: %v\n", codecoAppCR)

	err := r.Status().Update(ctx, codecoAppCR)
	return ctrl.Result{}, err
}

// SetupWithManager sets up the controller with the Manager.
func (r *CodecoAppReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&codecov1alpha1.CodecoApp{}). //Owns()
		Complete(r)
}

func CreateNewSWMApplicationModel() {

}

func MapToSWMApplicationModel(codecoApp codecov1alpha1.CodecoApp, swmApp swmv1alpha1.Application) {
	//Function to Map from Codeco Apllication Model to SWM Application Model

}
