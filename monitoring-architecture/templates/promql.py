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