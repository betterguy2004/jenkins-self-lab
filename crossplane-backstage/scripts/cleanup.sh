#!/bin/bash

# ============================================
# Cleanup Script - Remove all POC components
# ============================================

set -e

echo "⚠️  This will remove ALL POC components!"
echo "Components to be removed:"
echo "  - Backstage (if installed in cluster)"
echo "  - ArgoCD"
echo "  - Crossplane and all providers"
echo "  - All Crossplane managed resources"
echo ""
read -p "Are you sure you want to continue? (yes/no) " -r
echo

if [[ ! $REPLY == "yes" ]]; then
    echo "Aborted."
    exit 0
fi

echo "🧹 Starting cleanup..."

# Delete ArgoCD applications first
echo "Removing ArgoCD applications..."
kubectl delete applications --all -n argocd 2>/dev/null || true
kubectl delete applicationsets --all -n argocd 2>/dev/null || true

# Delete Crossplane claims
echo "Removing Crossplane claims..."
kubectl delete s3buckets --all 2>/dev/null || true
kubectl delete databases --all 2>/dev/null || true
kubectl delete networks --all 2>/dev/null || true

# Wait for managed resources to be deleted
echo "Waiting for managed resources to be deleted..."
sleep 30

# Delete Crossplane XRDs and Compositions
echo "Removing XRDs and Compositions..."
kubectl delete compositions --all 2>/dev/null || true
kubectl delete xrd --all 2>/dev/null || true

# Uninstall ArgoCD
echo "Uninstalling ArgoCD..."
helm uninstall argocd -n argocd 2>/dev/null || true
kubectl delete namespace argocd 2>/dev/null || true

# Uninstall Crossplane
echo "Uninstalling Crossplane..."
kubectl delete providers --all 2>/dev/null || true
helm uninstall crossplane -n crossplane-system 2>/dev/null || true
kubectl delete namespace crossplane-system 2>/dev/null || true

# Uninstall Backstage (if installed via Helm)
echo "Uninstalling Backstage..."
helm uninstall backstage -n backstage 2>/dev/null || true
kubectl delete namespace backstage 2>/dev/null || true

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "Note: AWS resources created by Crossplane may take some time to be fully deleted."
echo "Please verify in AWS Console that all resources have been removed."
