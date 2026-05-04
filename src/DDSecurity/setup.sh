#!/usr/bin/env bash

set -euo pipefail

# Default values
rg_name="aks-sec-demo-rg"
rg_location="westus2"
res_aks_name="aks-sec-demo"

echo "Using values:"
echo "  rg_name=${rg_name}"
echo "  rg_location=${rg_location}"
echo "  res_aks_name=${res_aks_name}"

echo "Creating resource group..."
az group create --name $rg_name --location $rg_location

echo "Creating AKS cluster..."
az aks create --resource-group $rg_name --name $res_aks_name --location $rg_location --node-count 1 --generate-ssh-keys 

echo "Done. AKS cluster ${res_aks_name} created in resource group ${rg_name}."
