# Set the environment variables
export CLUSTER_NAME="aks-dd"
export RESOURCE_GROUP="aks-dd-rg"

# Get the kube credentials for the AKS cluster
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME

# Verify plan enablement
az aks show --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --query "securityProfile.defender"

# expected result
#   "securityMonitoring": {
#     "enabled": true
#   }

# Verify sensor deployment
kubectl get ds microsoft-defender-collector-ds -n kube-system

# All pods should be in running state
# NAME                              DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
# microsoft-defender-collector-ds   4         4         4       4            4           <none>          129m

# Verify Azure Policy add-on
az aks show --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --query addonProfiles.azurepolicy

# Expected result
# {
#   "config": null,
#   "enabled": true,
#   "identity": {

# Execute the Threat simulator
