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
