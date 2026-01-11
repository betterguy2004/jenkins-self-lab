#!/bin/bash
helm uninstall jenkins -n jenkins
kubectl delete pvc jenkins -n jenkins
# Install EBS CSI Driver first
echo "=== Installing EBS CSI Driver ==="
./install-ebs-csi.sh
# Add Jenkins Helm Repo
helm repo add jenkins https://charts.jenkins.io
helm repo update

# Create Namespace
kubectl create ns jenkins

# Apply EBS StorageClass
echo "Applying EBS StorageClass..."
kubectl apply -f ./ebs-storageclass.yaml

# Apply RBAC for agents
echo "Applying RBAC..."
kubectl apply -f rbac.yaml -n jenkins

# Install Jenkins
echo "Installing Jenkins..."
helm upgrade --install jenkins jenkins/jenkins \
  --namespace jenkins \
  -f values.yaml

echo "Waiting for Jenkins to be ready (this may take a few minutes)..."
kubectl rollout status deployment/jenkins -n jenkins

# Get Admin Password
echo ""
echo "Jenkins is ready!"
echo "URL: http://<Your-Node-IP>:32000"
echo "Admin Password: Jenkins@123456"
