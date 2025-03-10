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
	"path/filepath"
	"testing"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	swm "siemens.com/qos-scheduler/api/v1alpha1"

	"k8s.io/client-go/kubernetes/scheme"
	"k8s.io/client-go/rest"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/envtest"
	logf "sigs.k8s.io/controller-runtime/pkg/log"
	"sigs.k8s.io/controller-runtime/pkg/log/zap"

	codecov1alpha1 "gitlab.eclipse.org/eclipse-research-labs/codeco-project/acm/api/v1alpha1"
)

// These tests use Ginkgo (BDD-style Go testing framework). Refer to
// http://onsi.github.io/ginkgo/ to learn more about Ginkgo.

var cfg *rest.Config
var k8sClient client.Client
var testEnv *envtest.Environment

func TestAPIs(t *testing.T) {
	RegisterFailHandler(Fail)

	RunSpecs(t, "Controller Suite")
}

var _ = BeforeSuite(func() {
	logf.SetLogger(zap.New(zap.WriteTo(GinkgoWriter), zap.UseDevMode(true)))

	By("bootstrapping test environment")
	testEnv = &envtest.Environment{
		CRDDirectoryPaths: []string{
			filepath.Join("..", "config", "crd", "bases"),
			filepath.Join("..", "internal", "qos-scheduler", "crds")},
		ErrorIfCRDPathMissing: true,
	}

	var err error
	// cfg is defined in this file globally.
	cfg, err = testEnv.Start()
	Expect(err).NotTo(HaveOccurred())
	Expect(cfg).NotTo(BeNil())

	err = codecov1alpha1.AddToScheme(scheme.Scheme)
	Expect(err).NotTo(HaveOccurred())
	err = swm.AddToScheme(scheme.Scheme)
	Expect(err).NotTo(HaveOccurred())

	//+kubebuilder:scaffold:scheme

	k8sClient, err = client.New(cfg, client.Options{Scheme: scheme.Scheme})
	Expect(err).NotTo(HaveOccurred())
	Expect(k8sClient).NotTo(BeNil())

})

var _ = AfterSuite(func() {
	By("tearing down the test environment")
	if testEnv != nil {
		Expect(testEnv.Stop()).NotTo(HaveOccurred())
	}
})

var _ = Describe("SWM Data", func() {
	BeforeEach(func(ctx context.Context) {
		setUpEnvironment(ctx)
	})
	It("saves node recommendations for SWM", func(ctx context.Context) {
		swmApp := makeApp(noGroup, "app", "w1", "w2")
		Expect(k8sClient.Create(ctx, swmApp)).Should(Succeed())
		Expect(swmApp.Spec.Workloads[0].NodeRecommendations).To(BeNil())
		Expect(swmApp.Spec.Workloads[1].NodeRecommendations).To(BeNil())

		SetRecomms(swmApp, "w1:n2", "w2:n1")
		Expect(k8sClient.Update(ctx, swmApp)).Should(Succeed())

		var app swm.Application // start with a fresh copy
		app.Name, app.Namespace = swmApp.Name, swmApp.Namespace
		Expect(k8sClient.Get(ctx, client.ObjectKeyFromObject(&app), &app)).
			Should(Succeed())
		Expect(app.Spec.Workloads[0].NodeRecommendations).
			To(Equal(map[string]float64{"n2": 0.9}))
		Expect(app.Spec.Workloads[1].NodeRecommendations).
			To(Equal(map[string]float64{"n1": 0.9}))
	})
})
