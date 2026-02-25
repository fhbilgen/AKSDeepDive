# STEP 1: AKS control plane metrics
az feature register --namespace "Microsoft.ContainerService" --name "AzureMonitorMetricsControlPlanePreview"

# Refresh the resource provider
az provider register --namespace Microsoft.ContainerService

# STEP 2: Setup environment variables

export RG_NAME="aksmon-rg"
export LOCATION="westus2"
export NODEPOOL_NAME="mynodepool"
export VM_SIZE="Standard_D4ds_v5"
export NAMESPACE="default"

# Service account configuration
export SERVICE_ACCOUNT_NAME="aks-mcp"
export SERVICE_ACCOUNT_NAMESPACE="kube-system" 

# Azure information for workload identity
export SUBSCRIPTION="$(az account show --query id --output tsv)"

# Workload identity configuration
export USER_ASSIGNED_IDENTITY_NAME="aks-mcp-identity"
export FEDERATED_IDENTITY_CREDENTIAL_NAME="aks-mcp-fed-identity"

# Azure Kubernetes Service Cluster
export AKS_CLUSTER_NAME="aksmon"

# Azure Managed Grafana
export GRAFANA_NAME="aks-mon-graf-${RANDOM}"

# Azure Monitor Workspace
export AZ_MONITOR_WORKSPACE_NAME="aksmon-wks"


# STEP 3: Create the Azure Monitor Workspace
# Create resource group
az group create --name ${RG_NAME} --location ${LOCATION}

# Create an Azure Monitor Workspace
az monitor account create --resource-group $RG_NAME --location $LOCATION --name $AZ_MONITOR_WORKSPACE_NAME

# Retrieve the Azure Monitor Workspace ID
export AZ_MONITOR_WORKSPACE_ID=$(az monitor account show --resource-group $RG_NAME --name $AZ_MONITOR_WORKSPACE_NAME --query id -o tsv)

# STEP 4: Create an Azure Managed Grafana instance
# Add the Azure Manage Grafana extension to az cli
az extension add --name amg

# Create an Azure Managed Grafana instance
az grafana create --name $GRAFANA_NAME --resource-group $RG_NAME --location $LOCATION

# Save the Grafana resource ID
export GRAFANA_RESOURCE_ID=$(az grafana show --name $GRAFANA_NAME --resource-group $RG_NAME --query id -o tsv)

# STEP 5: Log Analytics Workspace (for Container Insights)
export AZ_LA_WORKSPACE_NAME="aksmon-la-wks"
az monitor log-analytics workspace create --resource-group $RG_NAME --workspace-name $AZ_LA_WORKSPACE_NAME --location $LOCATION
export LOG_ANALYTICS_WORKSPACE_ID=$(az monitor log-analytics workspace show --resource-group $RG_NAME --workspace-name $AZ_LA_WORKSPACE_NAME --query id -o tsv)


# STEP 6: Create an AKS Cluster
# Create a new AKS cluster and attach the Grafana instance to it
az aks create --name $AKS_CLUSTER_NAME --resource-group $RG_NAME  --node-count 1 --enable-managed-identity --enable-azure-monitor-metrics --enable-cost-analysis --grafana-resource-id $GRAFANA_RESOURCE_ID --azure-monitor-workspace-resource-id $AZ_MONITOR_WORKSPACE_ID --enable-addons monitoring --workspace-resource-id $LOG_ANALYTICS_WORKSPACE_ID --tier Standard

# STEP 7: Taint the default pool and add a new node pool for user workloads
# Taint the default node pool to prevent user pods from being scheduled on it
az aks nodepool update --resource-group $RG_NAME --cluster-name $AKS_CLUSTER_NAME --name nodepool1 --node-taints CriticalAddonsOnly=true:NoSchedule --mode System

# STEP 8: Add a second node pool 
echo "Adding a second node pool to the existing AKS cluster"
az aks nodepool add --resource-group $RG_NAME --cluster-name $AKS_CLUSTER_NAME --name $NODEPOOL_NAME --node-vm-size $VM_SIZE --os-type Linux --os-sku Ubuntu --node-count 1 --mode User

# STEP 9: Control plane metrics
az feature register --namespace "Microsoft.ContainerService" --name "AzureMonitorMetricsControlPlanePreview"

# Get the credentials to access the cluster
az aks get-credentials --name $AKS_CLUSTER_NAME --resource-group $RG_NAME



# Check the credentails are working
kubectl cluster-info
kubectl get nodes

# STEP 7: Working on Grafana
# Create a folder in Grafana to host our new dashboards
az grafana folder create --name $GRAFANA_NAME --title AKS-Mon --resource-group $RG_NAME

# import kube-apiserver dashboard
az grafana dashboard import --name $GRAFANA_NAME --resource-group $RG_NAME --folder 'AKS-Mon' --definition 20331

# import etcd dashboard
az grafana dashboard import --name $GRAFANA_NAME --resource-group $RG_NAME --folder 'AKS-Mon' --definition 20330

# To access the Grafana Dashboard
GRAFANA_UI=$(az grafana show --name $GRAFANA_NAME --resource-group $RG_NAME --query "properties.endpoint" -o tsv)

echo "Your Azure Managed Grafana is accessible at: $GRAFANA_UI"

az grafana show --name $GRAFANA_NAME --resource-group $RG_NAME --query "properties.endpoint" -o tsv

# Browse the dashboard as described at https://azure-samples.github.io/aks-labs/docs/operations/observability-and-monitoring/#working-on-grafana

# STEP 8: Deploying the AKS Store Demo Application
# Do it before Example: Customizing the collection of metrics in the Lab document !!!
# https://azure-samples.github.io/aks-labs/docs/getting-started/setting-up-lab-environment#deploying-the-aks-store-demo-application

# Create a namespace for the application
kubectl create namespace pets

# Install the AKS Store Demo application
kubectl apply -f https://raw.githubusercontent.com/Azure-Samples/aks-store-demo/refs/heads/main/aks-store-quickstart.yaml -n pets

# Verify the application was installed
kubectl get all -n pets

# get the storefront service IP address
kubectl get svc store-front -n pets

# STEP 9: Example: Customizing the collection of metrics

# deploy the ama-metrics-settings-configmap in the kube-system namespace
kubectl apply -f https://raw.githubusercontent.com/Azure/prometheus-collector/refs/heads/main/otelcollector/configmaps/ama-metrics-settings-configmap.yaml

# Edit the ama-metrics-settings-configmap to enable the metrics you want to collect.
kubectl edit cm ama-metrics-settings-configmap -n kube-system

####################################################################
###################  AGENTIC CLI FOR AKS ###########################
####################################################################

# Phase 1: Install the CLI Extension

az extension add --name aks-agent
az extension update --name aks-agent
az aks agent --help


# Phase 2: Choose Your Deployment Mode
# Option B: Cluster Mode (Recommended for SREs)

# SERVICE_ACCOUNT_NAME
# Create the Service Account: aks-mcp
# kubectl create serviceaccount aks-mcp -n kube-system
kubectl create serviceaccount "${SERVICE_ACCOUNT_NAME}" -n "${SERVICE_ACCOUNT_NAMESPACE}"

# Create RBAC permissions

# Cluster-wide read access 
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
   name: aks-mcp-view-rolebinding
roleRef:
   apiGroup: rbac.authorization.k8s.io
   kind: ClusterRole
   name: view
subjects:
  - kind: ServiceAccount
    name: ${SERVICE_ACCOUNT_NAME}
    namespace: ${SERVICE_ACCOUNT_NAMESPACE}
EOF

# Namespace-scoped read access (for limited access scenarios)
# cat <<EOF | kubectl apply -f -
# apiVersion: rbac.authorization.k8s.io/v1
# kind: RoleBinding
# metadata:
#    name: aks-mcp-view-rolebinding
#    namespace: ${SERVICE_ACCOUNT_NAMESPACE}
# roleRef:
#    apiGroup: rbac.authorization.k8s.io
#    kind: ClusterRole
#    name: view
# subjects:
#   - kind: ServiceAccount
#     name: ${SERVICE_ACCOUNT_NAME}
#     namespace: ${SERVICE_ACCOUNT_NAMESPACE}
# EOF

# EOF Create RBAC permissions

# Assign permissions to the Service Account:
kubectl create clusterrole aks-agent-reader \
  --verb=get,list,watch \
  --resource=pods,pods/log,events,nodes,deployments,services,namespaces,configmaps

kubectl create clusterrolebinding aks-agent-reader-binding \
  --clusterrole=aks-agent-reader \
  --serviceaccount=kube-system:aks-mcp


kubectl create clusterrole aks-mcp-role \
  --verb=get,list,watch \
  --resource=pods,pods/log,events,nodes,deployments,services,namespaces,configmaps

kubectl create clusterrolebinding aks-mcp-rolebinding \
  --clusterrole=aks-mcp-role \
  --serviceaccount=kube-system:aks-mcp

kubectl create role aks-mcp-role \
  --verb=get,list,watch \
  --resource=pods,pods/log,events,nodes,deployments,services,namespaces,configmaps \
  --namespace="${SERVICE_ACCOUNT_NAMESPACE}"

kubectl create rolebinding aks-mcp-rolebinding \
  --role=aks-mcp-role \
  --serviceaccount=kube-system:aks-mcp \
  --namespace="${SERVICE_ACCOUNT_NAMESPACE}"

# metrics reading permissions
kubectl create clusterrole system:metrics-reader --verb=get,list --resource=pods.metrics.k8s.io,nodes.metrics.k8s.io
kubectl create clusterrolebinding aks-mcp-metrics --clusterrole=system:metrics-reader --serviceaccount=kube-system:aks-mcp
kubectl auth can-i list pods.metrics.k8s.io --as=system:serviceaccount:kube-system:aks-mcp --all-namespaces


# Verify the service account resources
kubectl get serviceaccount "${SERVICE_ACCOUNT_NAME}" -n "${SERVICE_ACCOUNT_NAMESPACE}"
kubectl get role aks-mcp-role -n "${SERVICE_ACCOUNT_NAMESPACE}"
kubectl get rolebinding aks-mcp-rolebinding -n "${SERVICE_ACCOUNT_NAMESPACE}"

# testing: Answer should be yes!
kubectl auth can-i get pods --as=system:serviceaccount:kube-system:aks-mcp


# Workload identity setup (Optional)

# Check current workload identity status
# The expected result is : true
az aks show --resource-group "${RG_NAME}" --name "${AKS_CLUSTER_NAME}" --query "securityProfile.workloadIdentity.enabled"

# Retrieve the OIDC issuer URL
export AKS_OIDC_ISSUER="$(az aks show --name "${AKS_CLUSTER_NAME}" --resource-group "${RG_NAME}" --query "oidcIssuerProfile.issuerUrl" --output tsv)"

# Create a user-assigned managed identity for Azure resource access:
az identity create --name "${USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${RG_NAME}" --location "${LOCATION}" --subscription "${SUBSCRIPTION}"

# Get the managed identity client ID
export USER_ASSIGNED_CLIENT_ID="$(az identity show --resource-group "${RG_NAME}" --name "${USER_ASSIGNED_IDENTITY_NAME}" --query 'clientId' --output tsv)"

# Assign necessary role to managed identity
az role assignment create --role "Reader" --assignee $USER_ASSIGNED_CLIENT_ID --scope /subscriptions/${SUBSCRIPTION}

# Annotate the service account with workload identity
kubectl annotate serviceaccount "${SERVICE_ACCOUNT_NAME}" \
    -n "${SERVICE_ACCOUNT_NAMESPACE}" \
    azure.workload.identity/client-id="${USER_ASSIGNED_CLIENT_ID}" \
    --overwrite

# Create the federated identity credential
az identity federated-credential create --name "${FEDERATED_IDENTITY_CREDENTIAL_NAME}" --identity-name "${USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${RG_NAME}" --issuer "${AKS_OIDC_ISSUER}" --subject "system:serviceaccount:${SERVICE_ACCOUNT_NAMESPACE}:${SERVICE_ACCOUNT_NAME}" --audience api://AzureADTokenExchange



# Check the service account annotation
kubectl describe serviceaccount "${SERVICE_ACCOUNT_NAME}" -n "${SERVICE_ACCOUNT_NAMESPACE}"

# Verify the federated identity credential
az identity federated-credential list --identity-name "${USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${RG_NAME}"



# INSTALLING THE AGENT !!!!
az aks agent-init --resource-group $RG_NAME --name $AKS_CLUSTER_NAME

# Select Choice 1: When prompted, choose Cluster Mode.
# Enter Details: Provide the namespace (kube-system) and the service account name (aks-mcp) you created.

# Please choose the LLM provider (1-5): 1
# You selected provider: Azure OpenAI
# Enter value for deployment_name:  (Hint: ensure your deployment name is the same as the model name, e.g., gpt-5) gpt-5.2-chat
# Enter value for api_key: 6Uc...l44a
# Enter value for api_base:  (Hint: https://{azure-openai-service-name}.openai.azure.com/) https://faikbilgen-0128-resource.openai.azure.com/
# Enter value for api_version:  (Default: 2025-04-01-preview) 2024-12-01-preview


# Verify the agent installation status
az aks agent --status --resource-group $RG_NAME --name $AKS_CLUSTER_NAME --namespace $SERVICE_ACCOUNT_NAMESPACE

# testing the agent

az aks agent "How many nodes are in my cluster?" --resource-group $RG_NAME --name $AKS_CLUSTER_NAME --namespace $SERVICE_ACCOUNT_NAMESPACE
az aks agent "What is the Kubernetes version on the cluster?" --resource-group $RG_NAME --name $AKS_CLUSTER_NAME --namespace $SERVICE_ACCOUNT_NAMESPACE
az aks agent "Why is coredns not working on my cluster?" --resource-group $RG_NAME --name $AKS_CLUSTER_NAME --namespace $SERVICE_ACCOUNT_NAMESPACE
az aks agent "Why is my cluster in a failed state?" --resource-group $RG_NAME --name $AKS_CLUSTER_NAME --namespace $SERVICE_ACCOUNT_NAMESPACE


# EOF AGENTIC CLI FOR AKS

# Then continue from the LAB article

# STEP 10: Deploying a PodMonitor and a Sample Application

# # Deploy a reference app
# # https://github.com/Azure/prometheus-collector/blob/main/internal/referenceapp/prometheus-reference-app.yaml
# kubectl apply -f https://raw.githubusercontent.com/Azure/prometheus-collector/refs/heads/main/internal/referenceapp/prometheus-reference-app.yaml

# # Verify it's running
# kubectl get pods,svc -l app=prometheus-reference-app

# #  Deploy a PodMonitor
# # https://github.com/Azure/prometheus-collector/blob/main/otelcollector/deploy/example-custom-resources/pod-monitor/pod-monitor-reference-app.yaml
# kubectl apply -f https://raw.githubusercontent.com/Azure/prometheus-collector/refs/heads/main/otelcollector/deploy/example-custom-resources/pod-monitor/pod-monitor-reference-app.yaml

# # Get the AMA Prometheus pod name
# AMA_METRICS_POD_NAME="$(kubectl get po -n kube-system -lrsName=ama-metrics -o jsonpath='{.items[0].metadata.name}')"

# # Port-forward Prometheus locally
# kubectl port-forward ${AMA_METRICS_POD_NAME} -n kube-system 9090

# # Open your browser at: http://localhost:9090
# # Then continue from the LAB article

