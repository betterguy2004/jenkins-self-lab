# Quick Fix: ArgoCD Login Error in GitHub Workflow

## 🔴 Lỗi bạn đang gặp

```
Error: accepts 1 arg(s), received 0
Usage: argocd login SERVER [flags]
```

## ✅ Nguyên nhân và giải pháp

### 1. Kiểm tra GitHub Secrets

Lỗi này xảy ra khi `ARGOCD_SERVER` secret **CHƯA được set** hoặc **EMPTY**.

**Kiểm tra ngay:**

```powershell
# Kiểm tra organization secrets
gh secret list --org manifest-crossplane-poc

# Hoặc kiểm tra repo secrets
gh secret list --repo manifest-crossplane-poc/infra-s3-test
```

### 2. Set GitHub Secrets đúng cách

**Bước 1: Lấy ArgoCD Server URL**

```powershell
# Nếu dùng port-forward (local dev)
kubectl get svc argocd-server -n argocd

# Server URL sẽ là một trong các giá trị sau:
# - argocd-server.argocd.svc.cluster.local (trong cluster)
# - localhost:8080 (nếu dùng port-forward)
# - <external-ip>:443 (nếu có LoadBalancer)
```

**Bước 2: Lấy ArgoCD Auth Token**

```powershell
# 1. Port-forward ArgoCD server
kubectl port-forward svc/argocd-server -n argocd 8080:443

# 2. Lấy admin password
$ARGOCD_PASSWORD = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# 3. Login và tạo token
argocd login localhost:8080 --username admin --password $ARGOCD_PASSWORD --insecure

# 4. Generate token (lưu lại token này!)
argocd account generate-token --account admin
```

**Bước 3: Set secrets vào GitHub**

```powershell
# Set ARGOCD_SERVER (KHÔNG bao gồm http:// hoặc https://)
gh secret set ARGOCD_SERVER `
  --org manifest-crossplane-poc `
  --body "argocd-server.argocd.svc.cluster.local"

# Set ARGOCD_AUTH_TOKEN
gh secret set ARGOCD_AUTH_TOKEN `
  --org manifest-crossplane-poc `
  --body "<token-từ-bước-2>"
```

### 3. Verify Secrets đã được set

```powershell
# Kiểm tra lại
gh secret list --org manifest-crossplane-poc

# Kết quả mong đợi:
# ARGOCD_SERVER       Updated 2026-01-14
# ARGOCD_AUTH_TOKEN   Updated 2026-01-14
```

## 🔧 Đã sửa trong code

File workflow đã được cập nhật để loại bỏ conflict giữa `--plaintext` và `--insecure`:

**❌ Trước (SAI):**
```yaml
argocd login ${{ env.ARGOCD_SERVER }} \
  --auth-token ${{ env.ARGOCD_AUTH_TOKEN }} \
  --insecure \
  --grpc-web \
  --plaintext  # ← Conflict với --insecure
```

**✅ Sau (ĐÚNG):**
```yaml
argocd login ${{ env.ARGOCD_SERVER }} \
  --auth-token ${{ env.ARGOCD_AUTH_TOKEN }} \
  --insecure \
  --grpc-web
```

## 🚀 Test lại workflow

Sau khi set secrets:

1. **Trigger workflow thủ công:**
   - Vào repo: https://github.com/manifest-crossplane-poc/infra-s3-test
   - Click **Actions** tab
   - Chọn **Deploy Infrastructure**
   - Click **Run workflow**

2. **Hoặc tạo repo mới từ Backstage:**
   - Vào Backstage UI: http://localhost:7007
   - Create new S3 bucket
   - Workflow sẽ tự động chạy

## 📝 Lưu ý quan trọng

### ✅ ĐÚNG - Server URL format:
- `argocd-server.argocd.svc.cluster.local`
- `localhost:8080`
- `192.168.1.100:443`

### ❌ SAI - KHÔNG dùng protocol:
- ~~`https://argocd-server.argocd.svc.cluster.local`~~
- ~~`http://localhost:8080`~~

### 🔐 Security:
- Auth token có thời hạn, nên rotate định kỳ
- Dùng organization secrets để tất cả repos đều có access
- Không commit token vào code

## 🆘 Vẫn gặp lỗi?

### Lỗi: "context deadline exceeded"

**Nguyên nhân:** GitHub Actions runner không thể kết nối đến ArgoCD server.

**Giải pháp:**
- Nếu dùng `argocd-server.argocd.svc.cluster.local`: Cần dùng **self-hosted runner** trong cluster
- Nếu dùng GitHub-hosted runner: Phải expose ArgoCD ra ngoài (LoadBalancer/Ingress)

### Lỗi: "Unauthorized"

**Nguyên nhân:** Token không hợp lệ hoặc hết hạn.

**Giải pháp:** Tạo token mới và update secret:
```powershell
argocd account generate-token --account admin
gh secret set ARGOCD_AUTH_TOKEN --org manifest-crossplane-poc --body "<new-token>"
```

## 📚 Tài liệu chi tiết

Xem thêm: `docs/github-secrets-setup.md`
