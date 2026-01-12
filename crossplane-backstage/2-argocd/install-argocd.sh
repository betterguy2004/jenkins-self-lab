#!/bin/bash

# ============================================
# ArgoCD Installation Script
# ============================================

set -e

echo "🚀 Installing ArgoCD..."

# Create namespace
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Option 1: Install with Helm (recommended for customization)
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --values argocd-values.yaml \
  --wait

echo "⏳ Waiting for ArgoCD pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server --namespace argocd --timeout=300s

# Get initial admin password
echo ""
echo "============================================"
echo "✅ ArgoCD installed successfully!"
echo "============================================"
echo ""
echo "📋 Get the initial admin password:"
echo "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo ""
echo "🌐 Access ArgoCD UI:"
echo "kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""
echo "Then open: https://localhost:8080"
echo "Username: admin"
echo ""

# Optional: Create port-forward script
cat > port-forward-argocd.sh << 'EOF'
#!/bin/bash
echo "Starting ArgoCD port-forward on https://localhost:8080"
kubectl port-forward svc/argocd-server -n argocd 8080:443
EOF
chmod +x port-forward-argocd.sh

echo "💡 You can also run: ./port-forward-argocd.sh"
