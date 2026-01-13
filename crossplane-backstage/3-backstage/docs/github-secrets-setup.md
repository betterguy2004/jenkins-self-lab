# Setup GitHub Organization Secrets for ArgoCD Integration

## Overview
This guide shows how to configure GitHub Organization Secrets so that all infrastructure repositories created by Backstage can automatically access ArgoCD credentials.

## Prerequisites
- GitHub account with organization (or use personal account)
- ArgoCD installed in Kubernetes cluster
- kubectl access to the cluster

---

## Step 1: Get ArgoCD Credentials

### 1.1 Get ArgoCD Server URL

If ArgoCD is exposed externally:
```powershell
# Get the external URL/IP
kubectl get svc argocd-server -n argocd
```

If using port-forward (for local/dev):
```powershell
# The server URL will be: localhost:8080 or argocd-server.argocd.svc.cluster.local
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

**Recommended for Kubernetes internal access:**
```
ARGOCD_SERVER=argocd-server.argocd.svc.cluster.local
```

### 1.2 Get ArgoCD Admin Password

```powershell
# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### 1.3 Generate ArgoCD Auth Token

```powershell
# Login to ArgoCD
argocd login localhost:8080 --username admin --password <password-from-above> --insecure

# Generate a long-lived token
argocd account generate-token --account admin
```

**Save this token** - you'll need it for GitHub Secrets.

---

## Step 2: Configure GitHub Organization Secrets

### Option A: Organization-Level Secrets (Recommended)

1. Go to your GitHub organization: `https://github.com/organizations/betterguy2004/settings/secrets/actions`
   
2. Click **"New organization secret"**

3. Create **ARGOCD_SERVER** secret:
   - **Name**: `ARGOCD_SERVER`
   - **Value**: `argocd-server.argocd.svc.cluster.local` (or your external URL)
   - **Repository access**: Select "All repositories" or "Selected repositories"
   - Click **"Add secret"**

4. Create **ARGOCD_AUTH_TOKEN** secret:
   - **Name**: `ARGOCD_AUTH_TOKEN`
   - **Value**: `<token-from-step-1.3>`
   - **Repository access**: Same as above
   - Click **"Add secret"**

### Option B: Repository-Level Secrets (For Testing)

If you don't have an organization, add secrets to each repo manually:

1. Go to repo: `https://github.com/betterguy2004/infra-s3-<bucket-name>/settings/secrets/actions`

2. Click **"New repository secret"**

3. Add both secrets as described above

---

## Step 3: Verify Secrets

### 3.1 Check Organization Secrets

```powershell
# Using GitHub CLI
gh secret list --org betterguy2004
```

Expected output:
```
ARGOCD_SERVER       Updated 2024-01-14
ARGOCD_AUTH_TOKEN   Updated 2024-01-14
```

### 3.2 Test in a Repository

Create a test workflow in any repo:

```yaml
# .github/workflows/test-secrets.yaml
name: Test Secrets
on: workflow_dispatch

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Check Secrets
        run: |
          echo "ARGOCD_SERVER is set: ${{ secrets.ARGOCD_SERVER != '' }}"
          echo "ARGOCD_AUTH_TOKEN is set: ${{ secrets.ARGOCD_AUTH_TOKEN != '' }}"
```

Run this workflow manually and check if both secrets are available.

---

## Step 4: Update Backstage Template (Already Done)

The template has been updated with a comment explaining that secrets should be configured at organization level. No code changes needed in the template itself.

---

## Step 5: Test End-to-End

1. **Restart Backstage** to load updated templates:
   ```powershell
   kubectl rollout restart deployment backstage -n backstage
   ```

2. **Create a new S3 bucket** via Backstage UI

3. **Check GitHub Actions**:
   - Go to the created repo
   - Navigate to Actions tab
   - The "Deploy Infrastructure" workflow should run successfully

4. **Verify ArgoCD**:
   ```powershell
   # Check if ArgoCD application was created
   argocd app list
   
   # Get details
   argocd app get s3-<bucket-name>
   ```

---

## Troubleshooting

### Issue: "argocd login" requires SERVER argument

**Error message:**
```
Error: accepts 1 arg(s), received 0
Usage: argocd login SERVER [flags]
```

**Root Cause**: The `ARGOCD_SERVER` secret is empty or not set.

**Solution**:
1. Verify the secret exists:
   ```powershell
   gh secret list --org manifest-crossplane-poc
   # or for personal repos
   gh secret list --repo betterguy2004/infra-s3-test
   ```

2. Set the secret with correct value:
   ```powershell
   # For organization
   gh secret set ARGOCD_SERVER --org manifest-crossplane-poc --body "argocd-server.argocd.svc.cluster.local"
   
   # For specific repo
   gh secret set ARGOCD_SERVER --repo betterguy2004/infra-s3-test --body "argocd-server.argocd.svc.cluster.local"
   ```

3. **Important**: Do NOT include protocol (`http://` or `https://`) in the server value
   - ✅ Correct: `argocd-server.argocd.svc.cluster.local`
   - ✅ Correct: `localhost:8080`
   - ❌ Wrong: `https://argocd-server.argocd.svc.cluster.local`

### Issue: Conflicting flags "--plaintext" and "--insecure"

**Error**: Login fails with TLS or protocol errors

**Root Cause**: Using both `--plaintext` (HTTP) and `--insecure` (HTTPS with self-signed cert) together causes conflicts.

**Solution**: Choose the right combination:

- **For HTTPS with self-signed certificate** (most common):
  ```bash
  argocd login $SERVER --auth-token $TOKEN --insecure --grpc-web
  ```

- **For plain HTTP** (not recommended):
  ```bash
  argocd login $SERVER --auth-token $TOKEN --plaintext --grpc-web
  ```

- **For HTTPS with valid certificate**:
  ```bash
  argocd login $SERVER --auth-token $TOKEN --grpc-web
  ```

### Issue: Workflow fails with "argocd login failed"

**Solution**: Check if secrets are properly set:
```powershell
# In the failed workflow run, check if secrets are masked
# You should see: argocd login *** (masked)
```

### Issue: "Error: repository not found"

**Solution**: Make sure the GitHub token has access to the repo:
```powershell
# The workflow uses GITHUB_TOKEN automatically
# Check repo permissions in Settings > Actions > General
```

### Issue: "Error: context deadline exceeded"

**Solution**: ArgoCD server might not be accessible from GitHub Actions runners.

For **local development**, you need to:
1. Expose ArgoCD externally (LoadBalancer or Ingress)
2. Update `ARGOCD_SERVER` secret with external URL

For **production**, use:
- ArgoCD with external URL
- Or use self-hosted GitHub Actions runners inside the cluster

---

## Alternative: Use GitHub App (Advanced)

For automatic secret management, you can create a custom Backstage action using GitHub App:

1. Create a GitHub App with `secrets` write permission
2. Install app on your organization
3. Create custom Backstage action to call GitHub API
4. Use the action in templates

This is more complex but provides better automation.

---

## Security Best Practices

1. **Rotate tokens regularly**: Generate new ArgoCD tokens periodically
2. **Use least privilege**: Create dedicated ArgoCD account for CI/CD
3. **Audit access**: Monitor which repos have access to secrets
4. **Use environment-specific secrets**: Different tokens for dev/staging/prod

---

## Next Steps

After configuring secrets:
1. ✅ Test creating infrastructure via Backstage
2. ✅ Verify ArgoCD applications are created
3. ✅ Check Crossplane resources are deployed
4. ✅ Monitor AWS resources in console

Your GitOps workflow is now fully automated! 🚀
