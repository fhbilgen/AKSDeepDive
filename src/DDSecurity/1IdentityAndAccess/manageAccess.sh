rg_name="${1:-aks-sec-demo-rg}"
rg_location="${2:-westus2}"
res_aks_name="${3:-aks-sec-demo}"
ACCOUNT_UPN="developer1@MngEnvMCAP442322.onmicrosoft.com"

# Create a new user in EntraID with ACCOUNT_UPN
# Add that user to the Dev group
# uncomment to run it
# az ad user create --display-name "Deve Loper1" --user-principal-name developer1@contoso.com --password ""

echo ${rg_name}, ${rg_location}, ${res_aks_name}

# echo "az login --use-device-code 

# Get the resource ID of your AKS cluster
AKS_CLUSTER=$(az aks show --resource-group ${rg_name} --name ${res_aks_name} --query id -o tsv)

# Get the account credentials for the logged in user
# use variables so that you don't have to login with the 
ACCOUNT_ID=$(az ad user show --id $ACCOUNT_UPN --query id -o tsv)

# Check existing roles for the ACCOUNT_ID on the AKS_CLUSTER. It should return an empty list
az role assignment list --assignee $ACCOUNT_ID --scope $AKS_CLUSTER 

# Assign the 'Cluster Admin' role to the user
az role assignment create --assignee $ACCOUNT_ID --scope $AKS_CLUSTER --role "Azure Kubernetes Service Cluster Admin Role"

# Run again the assigned role list to see that the user now has the 'Cluster Admin' role
az role assignment list --assignee $ACCOUNT_ID --scope $AKS_CLUSTER

# Get and verify the configuration information
az aks get-credentials --resource-group ${rg_name} --name ${res_aks_name} --admin

# Remove role permissions
az role assignment delete --assignee $ACCOUNT_ID --scope $AKS_CLUSTER

##### More Information #####
az role definition list \
  --query "[?contains(roleName, 'Azure Kubernetes Service')].{Role:roleName, Description:description}" \
  --output table

# Assign the 'Cluster User' role to the user
az role assignment create --assignee $ACCOUNT_ID --scope $AKS_CLUSTER --role "Azure Kubernetes Service Cluster User Role"

az aks get-credentials --resource-group ${rg_name} --name ${res_aks_name}