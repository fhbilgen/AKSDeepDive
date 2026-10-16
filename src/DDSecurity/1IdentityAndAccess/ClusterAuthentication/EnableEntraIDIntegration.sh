# To get the details of the current logged in user
# az account show

# To get the content of the config file
# cat /home/faikb/.kube/config


# STEP 1: Create a group in EntraID and add the user to that group
# STEP 2: Change the AKS's security setting to "Microsoft Entra ID authentication with Kubernetes RBAC"
# STEP 3: Set the Admin group to the group you created in step 1 and clear the "Kubernetes local accounts"
# STEP 4: Open a PS terminal and login with the admin account 
# STEP 5: Set the variables 

$rg_name="aks-sec-demo-rg"
$res_aks_name="aks-sec-demo"

# STEP 6: Get the credentails for kubectl
az aks get-credentials --resource-group ${rg_name} --name ${res_aks_name} 

# STEP 7: Verify that you can access the cluster with kubectl
kubectl get nodes

# STEP 8: Switch to a terminal where the non-admin account is logged on e.g. developer1
# If you're using a linux terminal then you might want to remove the existing config file to avoid any conflict with the admin account's config file
rm -rf ~/.kube/config
# And get the credentials again to create a new config file for the non-admin account
rg_name="aks-sec-demo-rg"
res_aks_name="aks-sec-demo"


az aks get-credentials --resource-group ${rg_name} --name ${res_aks_name}

# STEP 9: Try to get the list of the nodes
kubectl get nodes

# and it should fail with an error message like 
# Error from server (Forbidden): nodes is forbidden: User "developer1@XYZ.com" cannot list resource "nodes" in API group "" at the cluster scope
