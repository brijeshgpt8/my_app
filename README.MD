####  This application endpoints has been developed in Ruby as a scripting language .

Please follow the below mentioned steps to run the app in local development environment

**1:** Install dev dependency

**I:)** Install docker

**II:)** Install docker compose

**III:)** kubernetes

**IV:)** helm

**V:)** Setting Up Postgres

**VI:)** Create a Postgres user for the Rails app we’ll create in the next step. To do this, switch into the Postgres user:
        
`su - postgres`
in MAC OSX  
`/usr/local/bin/psql -d postgres`
```
➜ my_app git:(master) ✗ /usr/local/bin/psql -d postgres
psql (12.3)
Type "help" for help.

postgres=# create role myapp with createdb login password 'password1';
CREATE ROLE
postgres=#
```
##### Then create a user (or a “role”, as Postgres calls it):
`create role myapp with createdb login password 'password1';`

**2:** clone the `application`

**3:** cd to `my_app`

**4:** run `docker-compose build`

**5:** run `docker-compose up`

**6:** Call an API

**7:** Run the app using `docker-compose`

````
docker build -t brijeshgpt8/my_app:latest .
docker push 
docker run -it -p 3000:3000 brijeshgpt8/my_app:latest
cd my_app && docker-compose up
````

## Updating our blue/green deployment to Helm charts
For this, we introduced value, called production to reference which color is now in production.

````
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
  labels:
    run: webapp

spec:
  type: NodePort
  selector:
    color: {{ .Values.production }}
  ports:
    - protocol: TCP
      port: 3000
      targetPort: 3000
````
With our templates at the ready, we can go ahead and run our end-to-end example for a first time. 
We’ll install via `helm install helm` . (this has to be executed from the directory that contains Chart.yaml)

Doing a `kubectl get all` will show us that we have all our services and deployments running. Let’s wait a minute for our production service to get a public ip address.

Once we have a production IP address, we can see that blue is now our production service.

Let’s do an update to green via helm. This time, without touching the values.yaml file, but by setting a runtime value in helm: `helm upgrade helm . --set green.version=1.1`

This again has no impact on our production service, which we can flip around with yet another helm command: `helm upgrade helm . --set production=green`

Looking at our production service now, this doesn’t look like expected.

We can force Helm to use server values via the flag --reuse-values.

Let’s try this out by updating blue:

````
helm upgrade bluegreen . --set blue.version=1.1
kubectl rollout status deploy/blue #wait for blue to finish deploying
helm upgrade bluegreen . --set production=blue --reuse-values
````

With all of this done, we have turned our blue-green deployment into Helm charts, and now have a better update mechanism.

***Building a CI/CD pipeline in Azure Devops***
1: I’ll login to Azure Devops, and create a new pipeline.

2: We’ll then authorize Azure pipelines in Github.
   
3: Next we’ll select a repo, after which Github will again ask us for approval. As I might be doing more pipelines via Github, I’ll allow this in all my repos.

4: Next step would be to configure our pipeline. We’ll start of with a starter pipeline, as I don’t have an existing YAML pipeline.
   
5: We’ll start of with a starter pipeline. Making a blue/green deployment pipeline
6: The first thing we’ll need to do, is add our Kubernetes cluster to the pipeline by creating an environment in Azure Devops.
7: We’ll go ahead and create a new environment
8: We’ll name our environment and pick Kubernetes.
9: There’s a built-in connection to Azure, so we can easily pick our existing AKS cluster.
10: Next up, we’ll start editing our pipeline itself. We’ll add the ‘Helm tool installer’ step and a ‘Package and deploy Helm charts’ step to our pipeline. We won’t do a Helm upgrade just yet, but we’ll do a helm ls, just to see if Helm is installed correctly. This basic pipeline will look like:
````

# Starter pipeline
# Start with a minimal pipeline that you can customize to build and deploy your code.
# Add steps that build, run tests, deploy, and more:
# https://aka.ms/yaml

trigger:
- master

pool:
  vmImage: 'ubuntu-latest'

jobs:
- job: Update_version
  steps:
  - task: HelmInstaller@1
    inputs:
      helmVersionToInstall: '3.0.0'
  - task: HelmDeploy@0
    inputs:
      connectionType: 'Kubernetes Service Connection'
      kubernetesServiceConnection: 'k8s-cluster-nf-keda-default-1574378163229'
      command: 'ls'
````

11: We can now save our pipeline, and run it.
12: We can save our pipeline. Notice how I’m playing nicely and commiting to a branch.
13: Let’s run our pipeline for a first time.
14: The pipeline should finish quickly, and actually return us the output from our helm ls command:
15: The output of helm ls, executed in our pipeline.
16: This worked out pretty well. Let’s update our pipeline to include a couple extra steps:

add a variable
````
variables:
  version: 1
````

install kubectl
```
- task: KubectlInstaller@0
    name: Install_kubectl
    inputs:
      kubectlVersion: 'latest'
````
get a kubeconfig via az cli To achieve this, you’ll need to authorize Azure Devops access to your subscription.
````
- task: AzureCLI@2
    name: Get_kubeconfig
    inputs:
      azureSubscription: 'Nills''s Cloud-scale Datacenter(d19dddf3-9520-4226-a313-ae8ee08675e5)'
      scriptType: 'bash'
      scriptLocation: 'inlineScript'
      inlineScript: 'az aks get-credentials -g KEDA -n nf-keda'
````
get the current production version (and store it as a variable in Azure Devops)

````
- task: Bash@3
    name: Get_current_prod
    inputs:
      targetType: 'inline'
      script: |
        color=`kubectl get svc production -o yaml | grep color | awk -F ' ' '{print $2}'`
        echo $color
        if [ "$color" = "blue" ]; then
          echo "##vso[task.setvariable variable=color]green"
        else
          echo "##vso[task.setvariable variable=color]blue"
        fi
````
update the version (helm upgrade)
````
  - task: HelmDeploy@0
    name: Update_version
    inputs:
      connectionType: 'Kubernetes Service Connection'
      kubernetesServiceConnection: 'k8s-cluster-nf-keda-default-1574378163229'
      command: 'upgrade'
      chartType: 'FilePath'
      chartPath: 'helm-blue-green/blue-green/Chart.yaml'
      releaseName: 'bluegreen'
      overrideValues: '$(color).version=$(version)'
      arguments: '--reuse-values'
````

wait for the deployment to finish

````
- task: Bash@3
    name: Wait_for_deployment
    inputs:
      targetType: 'inline'
      script: 'kubectl rollout status deploy/$(color)'
````
flip the production service

````
 - task: HelmDeploy@0
    name: Flip_prod
    inputs:
      connectionType: 'Kubernetes Service Connection'
      kubernetesServiceConnection: 'k8s-cluster-nf-keda-default-1574378163229'
      command: 'upgrade'
      chartType: 'FilePath'
      chartPath: 'helm-blue-green/blue-green/Chart.yaml'
      releaseName: 'bluegreen'
      overrideValues: 'production=$(color)'
      arguments: '--reuse-values'
````

I've turned our blue-green deployment into a (CI/) CD pipeline. Every time somebody pushes to master, we’ll trigger a this pipeline. In terms of being fully correct, we are only doing a CD step, not a CI step. We don’t have any software to build, we are just releasing.

##Automation Task: Ansible

**Requirements:** Currently Ansible can be run from any machine with Python 2.6 installed

**1:** `Install Ansible` on your local computer, 

**2:** run `pip install ansible`

**3:** run the playbook on the target node

**4:** Playbook location: my_app_playbook.yml
````
vi hosts 
add hosts in this file

ansible-playbook playbook.yml -i hosts -u username
````