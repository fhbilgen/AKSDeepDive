# STEP 1: Set the environment variables
export CLUSTER_NAME="aks-dd"
export RESOURCE_GROUP="aks-dd-rg"
export SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# STEP 2: Get the kube credentials for the AKS cluster
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME


# STEP 3: Register the EnableImageIntegrityPreview feature flag
az feature register --namespace "Microsoft.ContainerService" --name "EnableImageIntegrityPreview"

# STEP 4: Verify the EnableImageIntegrityPreview feature flag registration status
az feature show --namespace "Microsoft.ContainerService" --name "EnableImageIntegrityPreview"

# Refresh the registration
az provider register --namespace Microsoft.ContainerService

# STEP 5: Create a policy assignment with the AKS policy initiative
export SCOPE="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}"
export LOCATION=$(az group show --name ${RESOURCE_GROUP} --query location -o tsv)

echo $SCOPE 
echo $LOCATION
az policy assignment create --name 'deploy-trustedimages' --policy-set-definition 'af28bf8b-c669-4dd3-9137-1e68fdc61bd6' --display-name 'Audit deployment with unsigned container images' --scope ${SCOPE} --mi-system-assigned --role Contributor --identity-scope ${SCOPE} --location ${LOCATION}

# STEP 6: The policy deploys the Image Integrity feature on your cluster when it detects any update operation on the cluster. 
# If you want to enable the feature immediately, you need to create a policy remediation using the az policy remediation create command.
export assignment_id=$(az policy assignment show --name 'deploy-trustedimages' --scope ${SCOPE} --query id -o tsv)
az policy remediation create --policy-assignment "$assignment_id" --definition-reference-id deployAKSImageIntegrity --name remediation --resource-group ${RESOURCE_GROUP}

# STEP 7: Technically the policy enablement should do the same thing ?! 
az aks update --resource-group ${RESOURCE_GROUP} --name ${CLUSTER_NAME} 

# STEP 8: Verify the Image Integrity feature is enabled on the cluster
# Verify Ratify pods are running
kubectl get pods -n gatekeeper-system

# Verify the CRDs exist
kubectl get crd | grep ratify

# STEP 9: Set up verification configurations
kubectl apply -f src/DDSecurity/ImageIntegrity/verify-config-old.yaml 

# STEP 10: 
kubectl run demo-signed --image=ghcr.io/deislabs/ratify/notary-image:signed
kubectl run demo-unsigned --image=ghcr.io/deislabs/ratify/notary-image:unsigned

# STEP 11: Verify the signed image is allowed and the unsigned image is blocked
export AKSRESOURCE_ID=$(az aks show -g ${RESOURCE_GROUP} -n ${CLUSTER_NAME} --query id -o tsv)

az policy state list \
  --resource ${AKSRESOURCE_ID} \
  --query "[].{Time:timestamp, Policy:policyDefinitionName, Compliance:complianceState, Details:policyEvaluationDetails}" \
  -o json
