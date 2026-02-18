
kubectl get ds microsoft-defender-collector-ds -n kube-system

# Run the simulation tool
python DDSecurity/KubernetesAlertSimulator/simulation.py 

# Check the alerts created 
# Azure Portal — AKS Cluster Level
# Go to your AKS cluster → Microsoft Defender for Cloud (under Security in the left menu)
# This shows alerts specific to that cluster

