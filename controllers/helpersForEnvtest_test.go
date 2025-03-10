// SPDX-FileCopyrightText: 2025 Siemens AG
// SPDX-License-Identifier: Apache-2.0

package controllers

import (
	"context"
	"sync"
)

var (
	envMutex sync.Mutex
	envSetUp bool
)

func setUpEnvironment(ctx context.Context) {
	envMutex.Lock()
	defer envMutex.Unlock()
	if !envSetUp {
		// TODO register reconcilers
		envSetUp = true
	}
}
