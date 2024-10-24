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

import requests
import time
import sys

# Prometheus api endpoint for query 
URL = "http://prometheus-operated.monitoring.svc.cluster.local:9090/api/v1/query"

# Node name
PROMQL = {'query':'node_uname_info'}

response = requests.get(f'{prometheus_url}/api/v1/query', params= PROMQL)

 # Check if the request was successful
if response.status_code == 200:
    # Parse the JSON response
    result = response.json()
    if 'data' in result and 'result' in result['data']:
        # Extract node names from the result
        node_names = [item['metric']['nodename'] for item in result['data']['result']]
        print("Node Names:", node_names)
    else:
        print("No data found in the response")
else:
    print(f"Error querying Prometheus: {response.status_code} - {response.text}")