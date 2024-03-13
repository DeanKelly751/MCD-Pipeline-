# codecoapp-operator
This is the project for the CODECO ACM operator.  
**Note:** It is in PoC mode - current content of the CRD and the operator behavior
is still expetimental

## Description
This projects is used for the development of the CODECO ACM operator. 

The CODECO ACM operatore is the main entry point to the CODECO platform. It serves
2 types of users, and provides 2 different CRDs, one per user.
* _Application developer_ (aka _cluster user_) - This is a user that deploys an 
application on the CODECO platforme. The CRD for the application deployment is 
*CodecoApp*.
* _Cluster admin_ - TBD

On deployment, a 3 node kind cluster will be configured and set up. 

We will then use ACM to install the other 4 project components; SWM, MDM, PDLC & NetMA

Our post_deploy.sh script will then configure the cluster to suit the needs of not only ACM, but of all CODECO components

## Getting Started
You’ll need a Kind installed on your machine. You can use [KIND](https://sigs.k8s.io/kind) to get a local cluster for testing, or run against a remote cluster.  
**Note:** Your controller will automatically use the current context in your kubeconfig file (i.e. whatever cluster `kubectl cluster-info` shows).

### Running on the cluster

1. Build and push your image to the location specified by `IMG`:

```sh
> make docker-build docker-push IMG=<some-registry>/codecoapp-operator:tag
```

**Note I:** This is required only after code changes in the operator.  
**Note II:** For `<some-registry>`, choose from a local registry, which also needs to be made visible in your cluster, to a remote registry, e.g., Docker hub or Podman.  
**Note III:** For _kind_ k8s cluster there is a need to push also the controller to the registry.  
Run the following step as a one time step (tested with Docker hub) - this is needed if the cluster can't access images on _localhost_

```sh
> docker tag controller:latest <some-registry>/codecoapp-operator:tag
> docker push <some-registry>/controller:tag
```

2. Deploy the controller to the cluster with the image specified by `IMG`:

```sh
> make deploy IMG=<some-registry>/controller:latest
```

After successful deployment you should see a pod, a service, a deployment and a replicaset in the odecoapp-operator-system namespace - for example:
```sh
  > kubectl get all -n codecoapp-operator-system
  NAME                                                         READY   STATUS    RESTARTS   AGE
  pod/codecoapp-operator-controller-manager-8664b86964-6k9t4   2/2     Running   0          11s

  NAME                                                            TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
  service/codecoapp-operator-controller-manager-metrics-service   ClusterIP   11.11.11.111   <none>        8443/TCP   11s

  NAME                                                    READY   UP-TO-DATE   AVAILABLE   AGE
  deployment.apps/codecoapp-operator-controller-manager   1/1     1            1           11s

  NAME                                                               DESIRED   CURRENT   READY   AGE
  replicaset.apps/codecoapp-operator-controller-manager-8664b86964   1         1         1       11s
```

**Note IV:** For _STATUS_ errors, inspect if the error is not related to the access to your registry. For example, if the error message refers to the correct registry or registry URL, and if your credentials are working.

The pod should be in _Running_ state and ready 

3. Install Instances of Custom Resources:

```sh
> kubectl apply -f config/samples/
```

#### Checking that the operator works (temp)

A check that the PoC operator that is installed from this rep is working - this may change in the future it just represents the PoC minimal functionality implemented now

1. Retrieve the CR deployed in the previous step 

        > kubectl get codecoapps.codeco.he-codeco.eu -o yaml

1. In the retrieved resource you should see the status with the `errormsg` field (this field is visible only after the operator handles the resource)

    ```yaml
    apiVersion: v1
    items:
    - apiVersion: codeco.he-codeco.eu/v1alpha1
      kind: CodecoApp
      metadata:
        annotations:
          kubectl.kubernetes.io/last-applied-configuration: |
            {"apiVersion":"codeco.he-codeco.eu/v1alpha1","kind":"CodecoApp","metadata":{"annotations":{},"labels":{"app.kubernetes.io/created-by":"codecoapp-operator","app.kubernetes.io/instance":"codecoapp-sample","app.kubernetes.io/managed-by":"kustomize","app.kubernetes.io/name":"codecoapp2","app.kubernetes.io/part-of":"codecoapp-operator"},"name":"codecoapp-sample","namespace":"default"},"spec":{"name":"My CODECO App","qosclass":"Dev"}}
        creationTimestamp: "2023-08-17T09:06:12Z"
        generation: 1
        labels:
          app.kubernetes.io/created-by: codecoapp-operator
          app.kubernetes.io/instance: codecoapp-sample
          app.kubernetes.io/managed-by: kustomize
          app.kubernetes.io/name: codecoapp2
          app.kubernetes.io/part-of: codecoapp-operator
        name: codecoapp-sample
        namespace: default
        resourceVersion: "109117"
        uid: 558568c9-70e0-42ad-9495-16db33d6f35e
      spec:
        name: My CODECO App
        qosclass: Dev
      status:
        ## The next line appears only after the operator handles the resource
        errormsg: No errors
        metrics: {}
        status: OK
    kind: List
    metadata:
      resourceVersion: ""
    ```

### Uninstall CRDs
To delete the CRDs from the cluster:

```sh
> make uninstall
```

### Undeploy controller
UnDeploy the controller from the cluster:

```sh
> make undeploy
```

### Customizing the deployment/undeployment process

If you need to customize the deployment process (for example, deploy your own component with the CODECO operator), you can add your customization to the scripts in the ./scripts directory. These are shell scripts that are executed during the deployment and undeployment process.

- `post_deploy.sh` is executed before the deployment and can be used to install dependencies  
>**Note:** This script is executed before the namespace `codecoapp-operator-system` is created
- `post_undeploy.sh` is executed after the CODECO operator deplyment and can be used to install additional components, for example CODECO platform sub components (so the `make deploy` command installs the entire CPDECO platform)
- `pre_undeploy.sh` is executed before removing the CODECO operator and is the best place to uninstall additional compoenent that were installed in the `post_undeploy.sh` script.
- `post_undeploy.sh` is executed after the CODECO operator was removes and is a good place for last minutes cleanups.  
>**Note:** This script is executed after the namespace `codecoapp-operator-system` is removed

## Contributing
// TODO(user): Add detailed information on how you would like others to contribute to this project

### How it works
This project aims to follow the Kubernetes [Operator pattern](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/).

It uses [Controllers](https://kubernetes.io/docs/concepts/architecture/controller/),
which provide a reconcile function responsible for synchronizing resources until the desired state is reached on the cluster.

### Test It Out (Development only, not a real K8s cluster deployment)
1. Install the CRDs into the cluster:

```sh
> make install
```

2. Run your controller (this will run in the foreground, so switch to a new terminal if you want to leave it running):

```sh
> make run
```

**NOTE:** You can also run this in one step by running: `make install run`

### Modifying the API definitions
If you are editing the API definitions, generate the manifests such as CRs or CRDs using:

```sh
> make manifests
```

**NOTE:** Run `make --help` for more information on all potential `make` targets

More information can be found via the [Kubebuilder Documentation](https://book.kubebuilder.io/introduction.html)

### Exploring the APIs

The script in `scripts/get_openapi_defs.sh` takes the API definitions and exports them in openapi V3 json format into the file `codeco_openapi.json` - this file is not part of the repo and should be generated by each user.  
**Note:** The script uses the utilities `jq` and `awk`. It checks for their existence and asks the user to install them before exeuting. 

In order to explore the API with Swagger, you can copy the file content and paste it into the [swagger editor](https://editor-next.swagger.io)

## License

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

# From Gitlab README info
## Getting started

To make it easy for you to get started with GitLab, here's a list of recommended next steps.

Already a pro? Just edit this README.md and make it your own. Want to make it easy? [Use the template at the bottom](#editing-this-readme)!

## Add your files

- [ ] [Create](https://docs.gitlab.com/ee/user/project/repository/web_editor.html#create-a-file) or [upload](https://docs.gitlab.com/ee/user/project/repository/web_editor.html#upload-a-file) files
- [ ] [Add files using the command line](https://docs.gitlab.com/ee/gitlab-basics/add-file.html#add-a-file-using-the-command-line) or push an existing Git repository with the following command:

```
cd existing_repo
git remote add origin https://gitlab.eclipse.org/eclipse-research-labs/codeco-project/acm.git
git branch -M main
git push -uf origin main
```

## Integrate with your tools

- [ ] [Set up project integrations](https://gitlab.eclipse.org/eclipse-research-labs/codeco-project/acm/-/settings/integrations)

## Collaborate with your team

- [ ] [Invite team members and collaborators](https://docs.gitlab.com/ee/user/project/members/)
- [ ] [Create a new merge request](https://docs.gitlab.com/ee/user/project/merge_requests/creating_merge_requests.html)
- [ ] [Automatically close issues from merge requests](https://docs.gitlab.com/ee/user/project/issues/managing_issues.html#closing-issues-automatically)
- [ ] [Enable merge request approvals](https://docs.gitlab.com/ee/user/project/merge_requests/approvals/)
- [ ] [Automatically merge when pipeline succeeds](https://docs.gitlab.com/ee/user/project/merge_requests/merge_when_pipeline_succeeds.html)

## Test and Deploy

Use the built-in continuous integration in GitLab.

- [ ] [Get started with GitLab CI/CD](https://docs.gitlab.com/ee/ci/quick_start/index.html)
- [ ] [Analyze your code for known vulnerabilities with Static Application Security Testing(SAST)](https://docs.gitlab.com/ee/user/application_security/sast/)
- [ ] [Deploy to Kubernetes, Amazon EC2, or Amazon ECS using Auto Deploy](https://docs.gitlab.com/ee/topics/autodevops/requirements.html)
- [ ] [Use pull-based deployments for improved Kubernetes management](https://docs.gitlab.com/ee/user/clusters/agent/)
- [ ] [Set up protected environments](https://docs.gitlab.com/ee/ci/environments/protected_environments.html)

