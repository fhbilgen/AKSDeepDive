
# On a terminal with an admin account logged check the status of the SSH service of the AKS cluster

rg_name="aks-sec-demo-rg"
res_aks_name="aks-sec-demo"
pool_name="nodepool1"

# Register the necessary preview extensions
az extension add --name aks-preview

az extension update --name aks-preview

# Register the EntraIdSSHPreview feature flag using the az feature register command.
az feature register --namespace "Microsoft.ContainerService" --name "EntraIdSSHPreview"

# Verify the registration status using the az feature show command.
az feature show --namespace "Microsoft.ContainerService" --name "EntraIdSSHPreview"

# When the status reflects Registered, refresh the registration of the Microsoft.ContainerService resource provider using the az provider register command.
az provider register --namespace Microsoft.ContainerService

# Use the az aks nodepool update command with the --ssh-access entraid argument to enable Entra ID based SSH on an existing node pool.
az aks nodepool update --cluster-name $res_aks_name --name $pool_name --resource-group $rg_name --ssh-access entraid

# For the change to take effect, you need to reimage the node pool by using the az aks nodepool upgrade command.
az aks nodepool upgrade --cluster-name $res_aks_name --name $pool_name --resource-group $rg_name --node-image-only

# set the correct node resource group and vmss values
node_resource_group="MC_aks-sec-demo-rg_aks-sec-demo_westus2"
vmss_name="aks-nodepool1-31113794-vmss"

# az vmss run-command invoke --resource-group <node-resource-group> --name <vmss-name> --command-id RunShellScript --instance-id 0 --scripts "systemctl status ssh"

az vmss run-command invoke --resource-group $node_resource_group --name $vmss_name --command-id RunShellScript --instance-id 0 --scripts "systemctl status ssh"

# Assign the 'Virtual Machine Administrator Login' role to the user for the node resource group to allow SSH access to the nodes in the cluster. This role allows you to log in to the virtual machines as an administrator.
ACCOUNT_UPN="admin@MngEnvMCAP442322.onmicrosoft.com"
SubscriptionID=$(az account show --query "id")

# Get your Node Resource Group name
NODE_RG=$(az aks show --resource-group $rg_name --name $res_aks_name --query nodeResourceGroup -o tsv)
SCOPE="/subscriptions/"${SubscriptionID//\"/}"/resourceGroups/"$NODE_RG

# Assign the role (replace <YourEmail> with your Entra ID principal)
az role assignment create --role "Virtual Machine Administrator Login" \
    --assignee $ACCOUNT_UPN \
    --scope $SCOPE

# The following steps will not work from your lab machine because the nodes don't have public IPs. You need to use a jumper box that has access to the node resource group and the necessary permissions to connect to the nodes via SSH.
# Install the Azure CLI SSH Extension
az extension add --name ssh

# Connect using the node name
az ssh vm --resource-group $NODE_RG --name aks-nodepool1-31113794-vmss000000

# get the IP address of the node
kubectl get node -o wide

# Create a jumper box in the same region and assign it the 'Virtual Machine Administrator Login' role. Then connect to the jumper box using SSH and from there connect to the nodes using the az ssh command.
# Make sure that the machine is connected to the VNET of the AKS cluster and subnet is the same as the nodes
# Enable EntraID authentication during the setup of the jumper box
# Download the private key for ssh

# Assign the role "Virtual Machine Administrator Login" to the resource group where the jumper box is
JUMPER_SCOPE="/subscriptions/"${SubscriptionID//\"/}"/resourceGroups/"aks-jumper-rg

az role assignment create --role "Virtual Machine Administrator Login" \
    --assignee $ACCOUNT_UPN \
    --scope $JUMPER_SCOPE

# Connect to the jumper box via the ssh command given in the portal. e.g. 
ssh -i "C:\Users\faikb.MIDDLEEAST\Downloads\jumpbpx-ssh-keys.pem" azureuser@20.80.189.136

# Install Azure CLI with
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Check the installation with az version
az version

# Then login use any browser. It works 
az login

# Get the internal IP 
# Finally try to connect to the node using the az ssh command
az ssh vm --ip 10.224.0.4

# It should succeed 