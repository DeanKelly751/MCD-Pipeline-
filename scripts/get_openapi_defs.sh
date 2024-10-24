# Copyright (c) 2024 Red Hat, Inc
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# 
# SPDX-License-Identifier: Apache-2.0
# 
# Contributors:
#     [name] - [contribution]

#!/bin/bash

check_cmd() {
    if ! command -v $1 &> /dev/null
    then
        echo "$1 could not be found"
        echo "$1 is required to run this script; please install it and try again"
        exit
    fi
}

check_cmd jq
check_cmd kubectl
check_cmd awk

file="codeco_openapi.json"
echo "Generating $file"
kubectl get --raw $(kubectl get --raw /openapi/v3 | jq | grep codeco | \
awk '{ print substr($2, 2, length($2)-2)}')  > $file
