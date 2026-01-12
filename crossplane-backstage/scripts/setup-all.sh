#!/bin/bash

# ============================================
# Complete Setup Script for Crossplane + Backstage + ArgoCD POC
# ============================================

set -e

echo "============================================"
echo "🚀 Starting Infrastructure Portal Setup"
echo "============================================"
echo ""

# Check prerequisites
echo "📋 Checking prerequisites..."

if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

if ! command -v helm &> /dev/null; then
    echo "❌ helm not found. Please install Helm first."
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster. Please check your kubeconfig."
    exit 1
fi

echo "✅ Prerequisites check passed!"
echo ""

# Step 1: Install Crossplane
echo "============================================"
echo "Step 1/4: Installing Crossplane"
echo "============================================"
cd ../1-crossplane
chmod +x install-crossplane.sh
./install-crossplane.sh

echo ""

# Step 2: Install ArgoCD
echo "============================================"
echo "Step 2/4: Installing ArgoCD"
echo "============================================"
cd ../2-argocd
chmod +x install-argocd.sh
./install-argocd.sh

echo ""

# Step 3: Configure ArgoCD Application
echo "============================================"
echo "Step 3/4: Configuring ArgoCD Application"
echo "============================================"

# Wait for ArgoCD to be ready
echo "⏳ Waiting for ArgoCD to be fully ready..."
sleep 10

# Apply ArgoCD applications (update repo URL first!)
echo "⚠️  Before applying ArgoCD applications, update the repository URL in:"
echo "   2-argocd/applications/crossplane-resources-app.yaml"
echo ""
read -p "Have you updated the repository URL? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    kubectl apply -f applications/
    echo "✅ ArgoCD applications created!"
else
    echo "⚠️  Skipping ArgoCD application creation. Apply manually later."
fi

echo ""

# Step 4: Setup Backstage (instructions)
echo "============================================"
echo "Step 4/4: Backstage Setup"
echo "============================================"

echo ""
echo "📝 Backstage requires manual setup. Follow these steps:"
echo ""
echo "Option A: Use npx to create a new Backstage app"
echo "  cd 3-backstage"
echo "  npx @backstage/create-app@latest"
echo "  # Copy templates and catalog files to the new app"
echo ""
echo "Option B: Use Docker (recommended for quick demo)"
echo "  docker run -d -p 7007:7007 \\"
echo "    -e GITHUB_TOKEN=your_token \\"
echo "    roadiehq/community-backstage-image"
echo ""
echo "Option C: Use the Helm chart"
echo "  helm repo add backstage https://backstage.github.io/charts"
echo "  helm install backstage backstage/backstage \\"
echo "    --namespace backstage --create-namespace \\"
echo "    -f 3-backstage/backstage-helm-values.yaml"
echo ""

# Summary
echo ""
echo "============================================"
echo "🎉 Setup Complete!"
echo "============================================"
echo ""
echo "📊 Component Status:"
echo ""
echo "Crossplane:"
kubectl get providers -o wide 2>/dev/null || echo "  (checking...)"
echo ""
echo "ArgoCD:"
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server 2>/dev/null || echo "  (checking...)"
echo ""
echo "🔗 Access URLs (after port-forwarding):"
echo "  - ArgoCD:    https://localhost:8080"
echo "  - Backstage: http://localhost:7007"
echo ""
echo "📖 Next steps:"
echo "  1. Create AWS credentials secret for Crossplane"
echo "  2. Setup GitHub repository for GitOps"
echo "  3. Configure and start Backstage"
echo "  4. Register templates in Backstage catalog"
echo ""
