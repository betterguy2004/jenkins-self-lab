#!/bin/bash

echo "Installing AWS EBS CSI Driver..."

# Install EBS CSI Driver using kubectl
kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.28"

echo "Waiting for EBS CSI Driver pods to be ready..."
kubectl wait --for=condition=ready pod -l app=ebs-csi-controller -n kube-system --timeout=300s
kubectl wait --for=condition=ready pod -l app=ebs-csi-node -n kube-system --timeout=300s

echo "EBS CSI Driver installation complete!"
echo ""
echo "Verifying installation:"
kubectl get pods -n kube-system | grep ebs-csi
