#!/bin/bash

# ============================================
# Crossplane Installation Script
# ============================================

set -e

echo "🚀 Installing Crossplane..."

# Add Crossplane Helm repository
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update

# Create namespace
kubectl create namespace crossplane-system --dry-run=client -o yaml | kubectl apply -f -

# Install Crossplane
helm upgrade --install crossplane crossplane-stable/crossplane \
  --namespace crossplane-system \
  --set args='{"--enable-usages"}' \
  --wait

# Wait for Crossplane to be ready
echo "⏳ Waiting for Crossplane pods to be ready..."
kubectl wait --for=condition=ready pod -l app=crossplane --namespace crossplane-system --timeout=120s

echo "✅ Crossplane installed successfully!"

# Install AWS Provider
echo "📦 Installing AWS Provider..."
kubectl apply -f provider/aws-provider.yaml

# Wait for provider to be healthy
echo "⏳ Waiting for AWS Provider to be healthy..."
sleep 30
kubectl wait --for=condition=healthy provider.pkg.crossplane.io/provider-aws-s3 --timeout=300s || true
kubectl wait --for=condition=healthy provider.pkg.crossplane.io/provider-aws-rds --timeout=300s || true
kubectl wait --for=condition=healthy provider.pkg.crossplane.io/provider-aws-ec2 --timeout=300s || true

echo "✅ AWS Providers installed!"

# Apply ProviderConfig (requires AWS credentials secret first)
echo "⚠️  Before applying ProviderConfig, create AWS credentials secret:"
echo ""
echo "kubectl create secret generic aws-creds -n crossplane-system \\"
echo "  --from-literal=access_key=YOUR_ACCESS_KEY \\"
echo "  --from-literal=secret_key=YOUR_SECRET_KEY"
echo ""
read -p "Have you created the secret? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    kubectl apply -f provider/providerconfig.yaml
    echo "✅ ProviderConfig applied!"
fi

# Apply XRDs and Compositions
echo "📋 Applying XRDs and Compositions..."
kubectl apply -f xrds/
kubectl apply -f compositions/

echo ""
echo "============================================"
echo "✅ Crossplane setup complete!"
echo "============================================"
echo ""
echo "Verify installation:"
echo "  kubectl get providers"
echo "  kubectl get xrd"
echo "  kubectl get compositions"
