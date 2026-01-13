# Hướng dẫn Rebuild và Redeploy Backstage

## Vấn đề
Sau khi cập nhật template, Backstage vẫn sử dụng template cũ và render sai workflow files, làm mất các biến `${{ env.ARGOCD_SERVER }}` và `${{ env.ARGOCD_AUTH_TOKEN }}`.

## Nguyên nhân
Backstage đang chạy với image cũ hoặc đang cache template. Cần rebuild Docker image và redeploy.

## Giải pháp: Rebuild và Redeploy

### Bước 1: Build Docker image mới

```powershell
# Di chuyển vào thư mục Backstage
cd d:\backstage-self-lab\jenkins-self-lab\crossplane-backstage\3-backstage

# Build Docker image với tag mới
docker build -t backstage:latest .

# Hoặc với tag cụ thể
docker build -t backstage:v1.1 .
```

### Bước 2: Load image vào Kind cluster

```powershell
# Load image vào Kind cluster
kind load docker-image backstage:latest --name crossplane-cluster

# Verify image đã được load
docker exec -it crossplane-cluster-control-plane crictl images | grep backstage
```

### Bước 3: Restart Backstage deployment

```powershell
# Restart deployment để sử dụng image mới
kubectl rollout restart deployment backstage -n backstage

# Theo dõi quá trình restart
kubectl rollout status deployment backstage -n backstage

# Kiểm tra pods
kubectl get pods -n backstage
```

### Bước 4: Verify template đã được cập nhật

1. **Truy cập Backstage UI**: http://localhost:7007
2. **Tạo S3 bucket mới** với tên khác (ví dụ: `test-template-fix`)
3. **Kiểm tra repo được tạo** trên GitHub
4. **Xem workflow file** trong repo mới:
   - File: `.github/workflows/deploy-infrastructure.yaml`
   - Kiểm tra dòng 61-64 phải có:
     ```yaml
     argocd login ${{ env.ARGOCD_SERVER }} \
       --auth-token ${{ env.ARGOCD_AUTH_TOKEN }} \
       --insecure \
       --plaintext
     ```

## Lưu ý quan trọng

### ⚠️ Về flag `--plaintext` vs `--insecure`

Bạn đã thay đổi từ `--grpc-web` sang `--plaintext`. Điều này chỉ đúng nếu:
- ArgoCD server đang chạy trên **HTTP** (không phải HTTPS)
- Thường dùng cho local development

**Nếu ArgoCD dùng HTTPS (self-signed cert):**
```yaml
argocd login ${{ env.ARGOCD_SERVER }} \
  --auth-token ${{ env.ARGOCD_AUTH_TOKEN }} \
  --insecure \
  --grpc-web
```

**Nếu ArgoCD dùng HTTP:**
```yaml
argocd login ${{ env.ARGOCD_SERVER }} \
  --auth-token ${{ env.ARGOCD_AUTH_TOKEN }} \
  --plaintext \
  --grpc-web
```

### 🔍 Kiểm tra ArgoCD server protocol

```powershell
# Kiểm tra service
kubectl get svc argocd-server -n argocd

# Kiểm tra xem có TLS không
kubectl get secret argocd-server-tls -n argocd
```

## Alternative: Force reload template without rebuild

Nếu không muốn rebuild, có thể thử:

```powershell
# Xóa pod để force restart
kubectl delete pod -n backstage -l app=backstage

# Hoặc scale down và up
kubectl scale deployment backstage -n backstage --replicas=0
kubectl scale deployment backstage -n backstage --replicas=1
```

**Lưu ý**: Cách này chỉ hiệu quả nếu template files được mount từ ConfigMap/Volume. Nếu template được build vào Docker image thì PHẢI rebuild image.

## Troubleshooting

### Template vẫn bị render sai sau khi restart

**Nguyên nhân**: Template đã được build vào Docker image, không phải mount từ volume.

**Giải pháp**: PHẢI rebuild Docker image (Bước 1-3 ở trên).

### Không thể build Docker image

**Lỗi**: `Cannot connect to Docker daemon`

**Giải pháp**:
```powershell
# Khởi động Docker Desktop
# Hoặc kiểm tra Docker service
docker version
```

### Image mới không được sử dụng

**Nguyên nhân**: Kubernetes đang dùng image cũ từ cache.

**Giải pháp**:
```powershell
# Xóa deployment và tạo lại
kubectl delete deployment backstage -n backstage

# Apply lại manifest
kubectl apply -f backstage-deployment.yaml -n backstage
```

## Checklist

- [ ] Build Docker image mới
- [ ] Load image vào Kind cluster
- [ ] Restart Backstage deployment
- [ ] Verify pods đang chạy
- [ ] Test tạo repo mới từ Backstage
- [ ] Kiểm tra workflow file trong repo mới
- [ ] Verify các biến `${{ env.* }}` không bị mất
- [ ] Test chạy workflow trên GitHub Actions
