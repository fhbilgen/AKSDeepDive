# On a terminal with an admin account logged check the status of the SSH service of the AKS cluster

rg_name="aks-sec-demo-rg"
res_aks_name="aks-sec-demo"

# Either run the following line or clear the "Kubernetes local accounts" settings in the portal
az aks update --resource-group ${rg_name} --name ${res_aks_name} --disable-local-accounts

# Check if local accounts are disabled for the AKS cluster
# If they are disabled then the command should return true
az aks show --resource-group ${rg_name} --name ${res_aks_name} --query "disableLocalAccounts"

az aks get-credentials --resource-group ${rg_name} --name ${res_aks_name} --admin

# The command should return an error similar to the following, indicating that local accounts are disabled and you cannot access the cluster using the admin credentials:

# (BadRequest) Getting static credential is not allowed because this cluster is set to disable local accounts.
# Code: BadRequest
# Message: Getting static credential is not allowed because this cluster is set to disable local accounts.