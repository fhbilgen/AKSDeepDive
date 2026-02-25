# Set the environment variables
export CLUSTER_NAME="aks-imgsign"
export RESOURCE_GROUP="aks-imgsign-rg"
export LOCATION="westus2"

export ACR_NAME="aksimgsgncr"
az aks create --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --enable-oidc-issuer --enable-""workload-identity --enable-addons azure-policy --enable-image-integrity --attach-acr $ACR_NAME
