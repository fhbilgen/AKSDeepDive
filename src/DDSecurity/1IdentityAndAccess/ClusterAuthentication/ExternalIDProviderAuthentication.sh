# There is a repo in Github for the authenticator part
# https://github.com/fhbilgen/GithubOIDCProviderforAKS

# On a terminal with an admin account logged check the status of the SSH service of the AKS cluster

rg_name="aks-sec-demo-rg"
res_aks_name="aks-sec-demo"

# Register the JWTAuthenticatorPreview feature
az feature register --name JWTAuthenticatorPreview --namespace Microsoft.ContainerService
az feature show --name JWTAuthenticatorPreview --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.ContainerService

# Get the API server URL for your cluster using the az aks show command.
# Set the value to the repo secret AKS_SERVER_URL
az aks show --resource-group $rg_name --name $res_aks_name --query "fqdn" -o tsv | awk '{print "https://" $0 ":443"}'

# https://aks-sec-de-aks-sec-demo-rg-0b84cf-ogmcfzf6.hcp.westus2.azmk8s.io:443

# Get the base64-encoded certificate authority data for your cluster using the az aks get-credentials command.
# Get CA data (base64 encoded)
# Set the value to the repo secret AKS_CA_DATA
az aks get-credentials --resource-group $rg_name --name $res_aks_name --file - --format exec | grep certificate-authority-data | awk '{print $2}'

# Create the JWT authenticator
az aks jwtauthenticator add --resource-group $rg_name --cluster-name $res_aks_name --name external-auth --config-file jwt-config.json

# CONTROL the JWT authenticator
# List all JWT authenticators on your cluster using the az aks jwtauthenticator list command.
az aks jwtauthenticator list --resource-group $rg_name --cluster-name $res_aks_name

# Get details for a specific JWT authenticator using the az aks jwtauthenticator show command.
az aks jwtauthenticator show --resource-group $rg_name --cluster-name $res_aks_name --name external-auth

# At this point the workflow should fail with the following
# Error from server (Forbidden): pods is forbidden: User "aks:jwt:github:repo:fhbilgen/GithubOIDCProviderforAKS:ref:refs/heads/main" cannot list resource "pods" in API group "" at the cluster scope
# Error: Process completed with exit code 1.

# Configure Kubernetes Role-Based Access Control (RBAC)
# Verify the kube config 
az aks get-credentials --resource-group ${rg_name} --name ${res_aks_name} --overwrite-existing

# Apply the RBAC configuration using the kubectl apply command
# name: aks:jwt:github:your-github-sub in rbac-config.yaml file should match the subject name in the JWT authenticator configuration
# You can get this subject name from the output of workflow run. e.g. see line 33 above. 
# e.g. in this case repo:fhbilgen/GithubOIDCProviderforAKS:ref:refs/heads/main should be used. 
# Change the rbac-config.yaml file and then execute the following
kubectl apply -f rbac-config.yaml

# Rerun the workflow and it should succeed this time as the user has now permissions to list pods in the cluster.
# List all pods in the cluster should succeed now and return an empty list as there are no pods in the cluster.