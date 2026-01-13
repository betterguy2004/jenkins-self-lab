# ✅ Đã Fix: Lỗi Render Template Backstage

## 🔴 Vấn đề gốc

Khi Backstage tạo repo mới từ template, các biến GitHub Actions bị mất:

**❌ Trước (Bị lỗi):**
```yaml
- name: Login to ArgoCD
  run: |
    argocd login  \           # ← Thiếu $ARGOCD_SERVER
      --auth-token  \         # ← Thiếu $ARGOCD_AUTH_TOKEN
      --insecure \
      --plaintext
```

**Nguyên nhân:**
- Backstage sử dụng cú pháp `${{ }}` để render templates
- Khi gặp `${{ env.ARGOCD_SERVER }}` trong workflow files, Backstage cố gắng replace nó
- Vì không có biến `env.ARGOCD_SERVER` trong Backstage context, nó bị thay thế thành chuỗi rỗng

## ✅ Giải pháp đã áp dụng

### 1. Thêm `copyWithoutRender` trong template.yaml

Ngăn Backstage render workflow files:

```yaml
# File: templates/*/template.yaml
steps:
  - id: fetch-template
    name: Fetch and Render Templates
    action: fetch:template
    input:
      url: ./skeleton
      # ✅ Preserve GitHub Actions syntax
      copyWithoutRender:
        - .github/workflows/**
      values:
        bucketName: ${{ parameters.bucketName }}
        # ... other values
```

### 2. Sử dụng shell variables thay vì GitHub Actions expressions

**✅ Sau (Đúng):**
```yaml
- name: Login to ArgoCD
  env:
    ARGOCD_SERVER: ${{ secrets.ARGOCD_SERVER }}
    ARGOCD_AUTH_TOKEN: ${{ secrets.ARGOCD_AUTH_TOKEN }}
  run: |
    argocd login "$ARGOCD_SERVER" \
      --auth-token "$ARGOCD_AUTH_TOKEN" \
      --plaintext \
      --grpc-web
```

**Tại sao cách này hoạt động?**
- `${{ secrets.* }}` được GitHub Actions xử lý, không phải Backstage
- `$ARGOCD_SERVER` là shell variable, Backstage không render nó
- Backstage chỉ render `${{ }}`, không render `$VAR`

### 3. Cấu hình đúng cho môi trường dev (HTTP)

```yaml
argocd login "$ARGOCD_SERVER" \
  --auth-token "$ARGOCD_AUTH_TOKEN" \
  --plaintext \      # ✅ Cho HTTP (không TLS)
  --grpc-web         # ✅ Cho proxy support
```

**Lưu ý:**
- `--plaintext`: Dùng cho ArgoCD chạy HTTP (dev environment)
- `--insecure`: Dùng cho ArgoCD chạy HTTPS với self-signed cert
- `--grpc-web`: Cho phép hoạt động qua proxy

## 📋 Các file đã được cập nhật

### Templates (3 files)
1. ✅ `templates/s3-bucket-template/template.yaml`
2. ✅ `templates/vpc-template/template.yaml`
3. ✅ `templates/rds-template/template.yaml`

**Thay đổi:** Thêm `copyWithoutRender: [.github/workflows/**]`

### Workflow Files (3 files)
1. ✅ `templates/s3-bucket-template/skeleton/.github/workflows/deploy-infrastructure.yaml`
2. ✅ `templates/vpc-template/skeleton/.github/workflows/deploy-infrastructure.yaml`
3. ✅ `templates/rds-template/skeleton/.github/workflows/deploy-infrastructure.yaml`

**Thay đổi:**
- Xóa `env:` ở workflow level
- Thêm `env:` trong từng step cần secrets
- Dùng `"$VAR"` thay vì `${{ env.VAR }}`
- Đổi `--insecure` thành `--plaintext` (cho HTTP)

## 🧪 Cách test

### Bước 1: Restart Backstage để load template mới

```powershell
# Xóa pod để force restart
kubectl delete pod -n backstage -l app.kubernetes.io/name=backstage

# Hoặc nếu không tìm thấy, list pods trước
kubectl get pods -n backstage
kubectl delete pod backstage-<pod-id> -n backstage

# Đợi pod mới khởi động
kubectl get pods -n backstage -w
```

### Bước 2: Tạo S3 bucket mới từ Backstage

1. Truy cập: http://localhost:7007
2. Click **Create** → **AWS S3 Bucket**
3. Điền form:
   - Bucket Name: `test-workflow-fix` (tên mới, chưa dùng)
   - Environment: `dev`
   - Region: `us-east-1`
   - Enable Encryption: `true`
4. Click **Review** → **Create**

### Bước 3: Kiểm tra repo được tạo

1. Vào GitHub: `https://github.com/manifest-crossplane-poc/infra-s3-test-workflow-fix`
2. Mở file: `.github/workflows/deploy-infrastructure.yaml`
3. **Kiểm tra dòng 51-65:**

```yaml
- name: Login to ArgoCD
  env:
    ARGOCD_SERVER: ${{ secrets.ARGOCD_SERVER }}
    ARGOCD_AUTH_TOKEN: ${{ secrets.ARGOCD_AUTH_TOKEN }}
  run: |
    argocd login "$ARGOCD_SERVER" \
      --auth-token "$ARGOCD_AUTH_TOKEN" \
      --plaintext \
      --grpc-web
```

**✅ Phải thấy:**
- `${{ secrets.ARGOCD_SERVER }}` (KHÔNG bị mất)
- `${{ secrets.ARGOCD_AUTH_TOKEN }}` (KHÔNG bị mất)
- `"$ARGOCD_SERVER"` trong run command
- `--plaintext` flag

**❌ KHÔNG được thấy:**
- `argocd login  \` (thiếu server)
- `--auth-token  \` (thiếu token)

### Bước 4: Kiểm tra GitHub Actions workflow

1. Vào tab **Actions** trong repo
2. Workflow **Deploy Infrastructure** sẽ tự động chạy
3. Click vào workflow run
4. Xem log của step **Login to ArgoCD**

**✅ Kết quả mong đợi:**
```
Run argocd login "$ARGOCD_SERVER" \
  --auth-token "$ARGOCD_AUTH_TOKEN" \
  --plaintext \
  --grpc-web

Logged in successfully
```

**❌ Nếu vẫn lỗi:**
```
Error: accepts 1 arg(s), received 0
Usage: argocd login SERVER [flags]
```
→ Secrets chưa được set hoặc template chưa reload

## 🔐 Verify GitHub Secrets

Đảm bảo secrets đã được set ở organization level:

```powershell
# Kiểm tra trên GitHub UI
# https://github.com/organizations/manifest-crossplane-poc/settings/secrets/actions
```

Phải có 2 secrets:
- ✅ `ARGOCD_SERVER` = `argocd-server.argocd.svc.cluster.local`
- ✅ `ARGOCD_AUTH_TOKEN` = `<your-token>`

## 📊 So sánh Before/After

### ❌ BEFORE (Bị lỗi)

**Template.yaml:**
```yaml
- id: fetch-template
  action: fetch:template
  input:
    url: ./skeleton
    values:
      bucketName: ${{ parameters.bucketName }}
```

**Workflow (sau khi render):**
```yaml
env:
  ARGOCD_SERVER:        # ← Rỗng!
  ARGOCD_AUTH_TOKEN:    # ← Rỗng!

- name: Login to ArgoCD
  run: |
    argocd login  \     # ← Thiếu server!
```

### ✅ AFTER (Đã fix)

**Template.yaml:**
```yaml
- id: fetch-template
  action: fetch:template
  input:
    url: ./skeleton
    copyWithoutRender:
      - .github/workflows/**  # ← Không render workflow files
    values:
      bucketName: ${{ parameters.bucketName }}
```

**Workflow (sau khi render):**
```yaml
# Không có env ở workflow level

- name: Login to ArgoCD
  env:
    ARGOCD_SERVER: ${{ secrets.ARGOCD_SERVER }}      # ← Giữ nguyên!
    ARGOCD_AUTH_TOKEN: ${{ secrets.ARGOCD_AUTH_TOKEN }}  # ← Giữ nguyên!
  run: |
    argocd login "$ARGOCD_SERVER" \  # ← Shell variable
```

## 🎯 Kết luận

**Root cause:** Backstage render `${{ }}` trong tất cả files, kể cả workflow files.

**Solution:**
1. ✅ Dùng `copyWithoutRender` để skip workflow files
2. ✅ Dùng shell variables `$VAR` thay vì `${{ env.VAR }}`
3. ✅ Set `env:` trong step thay vì workflow level
4. ✅ Dùng `--plaintext` cho HTTP ArgoCD

**Next steps:**
1. Test tạo repo mới từ Backstage
2. Verify workflow file không bị mất variables
3. Verify GitHub Actions chạy thành công
4. Verify ArgoCD application được tạo

## 🆘 Troubleshooting

### Vấn đề: Template vẫn bị render sai

**Giải pháp:** Restart Backstage pod
```powershell
kubectl delete pod -n backstage <pod-name>
```

### Vấn đề: Workflow chạy nhưng vẫn lỗi "accepts 1 arg(s), received 0"

**Nguyên nhân:** Secrets chưa được set

**Giải pháp:** Set secrets ở organization level
```
https://github.com/organizations/manifest-crossplane-poc/settings/secrets/actions
```

### Vấn đề: "context deadline exceeded"

**Nguyên nhân:** GitHub Actions runner không thể kết nối đến ArgoCD server

**Giải pháp:** 
- Nếu `ARGOCD_SERVER = argocd-server.argocd.svc.cluster.local`: Cần self-hosted runner trong cluster
- Nếu dùng GitHub-hosted runner: Phải expose ArgoCD ra ngoài

---

**Tài liệu liên quan:**
- `docs/github-secrets-setup.md` - Hướng dẫn setup secrets
- `docs/QUICK-FIX-argocd-login.md` - Quick fix cho lỗi login
- `docs/REBUILD-BACKSTAGE.md` - Hướng dẫn rebuild Backstage
