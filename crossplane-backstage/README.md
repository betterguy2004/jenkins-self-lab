# Crossplane + Backstage + ArgoCD POC

## 🎯 Mục tiêu Demo

Tự động hóa việc tạo AWS infrastructure thông qua:
1. **Backstage** - Developer Portal với form UI
2. **GitHub Actions** - Automation pipeline
3. **ArgoCD** - GitOps sync
4. **Crossplane** - AWS resource provisioning

---

## 🔄 Workflow Overview

```
┌──────────────────────────────────────────────────────────────┐
│ 1. User điền form trong Backstage UI                         │
│    - Input: bucketName, region, environment, etc.            │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────┐
│ 2. Backstage Scaffolder xử lý template                       │
│    - Validate inputs                                          │
│    - Execute các steps theo thứ tự                           │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────┐
│ 3. Step: fetch:template                                      │
│    - Render template files với user inputs                   │
│    - Tạo working directory với rendered content              │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────┐
│ 4. Step: publish:github                                      │
│    - Tạo GitHub repository mới                               │
│    - Push rendered content lên repo                          │
│    - Output: remoteUrl, repoContentsUrl                      │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────┐
│ 5. Step: github:actions:dispatch                             │
│    - Call GitHub API: POST /repos/{owner}/{repo}/actions/... │
│    - API Endpoint: workflow_dispatches                       │
│    - Headers: Authorization: token ${GITHUB_TOKEN}           │
│    - Body: { ref: "main", inputs: {...} }                    │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────┐
│ 6. GitHub Actions nhận dispatch event                        │
│    - Workflow với trigger: workflow_dispatch được activate   │
│    - Nhận inputs từ Backstage                                │
│    - Bắt đầu execute workflow jobs                           │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────┐
│ 7. Workflow thực thi                                          │
│    - Login ArgoCD                                             │
│    - Register repository                                      │
│    - Create ArgoCD Application                               │
│    - Trigger initial sync                                     │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────┐
│ 8. ArgoCD sync resources vào K8s cluster                     │
│    - Monitor GitHub repo                                      │
│    - Apply Crossplane claims to cluster                      │
│    - Crossplane provisions AWS resources                     │
│    - Report status back                                       │
└──────────────────────────────────────────────────────────────┘
```

---

## 📁 Cấu trúc dự án

```
crossplane-backstage/
├── README.md
├── 1-crossplane/                    # Crossplane installation
│   ├── install-crossplane.sh
│   ├── provider/
│   │   ├── aws-provider.yaml
│   │   └── providerconfig.yaml
│   ├── xrds/
│   │   ├── s3bucket-xrd.yaml
│   │   ├── rds-xrd.yaml
│   │   └── vpc-xrd.yaml
│   └── compositions/
│       ├── s3bucket-composition.yaml
│       ├── rds-composition.yaml
│       └── vpc-composition.yaml
├── 2-argocd/                        # ArgoCD installation
│   ├── install-argocd.sh
│   └── argocd-values.yaml
├── 3-backstage/                     # Backstage configuration
│   ├── app-config.yaml
│   ├── backstage-helm-values.yaml
│   ├── catalog/
│   └── templates/
│       ├── s3-bucket-template/
│       │   ├── template.yaml        # Backstage template definition
│       │   └── skeleton/            # Files to be created
│       │       ├── .github/workflows/deploy-infrastructure.yaml
│       │       ├── manifests/s3-claim.yaml
│       │       ├── catalog-info.yaml
│       │       └── README.md
│       ├── rds-template/
│       └── vpc-template/
├── 4-gitops-repo/                   # Example GitOps structure
└── scripts/
    ├── setup-all.sh
    └── cleanup.sh
```

---

## 🚀 Hướng dẫn triển khai

### Prerequisites

- [x] Kubernetes cluster
- [ ] Helm 3.x
- [ ] AWS Access Key & Secret Key
- [ ] GitHub Personal Access Token (với quyền `repo`, `workflow`)
- [ ] GitHub Organization hoặc Personal account

### Bước 1: Cài đặt Crossplane

```bash
cd 1-crossplane

# Install Crossplane
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm upgrade --install crossplane crossplane-stable/crossplane \
  --namespace crossplane-system --create-namespace --wait

# Install AWS Providers
kubectl apply -f provider/aws-provider.yaml

# Wait for providers
kubectl get providers -w

# Create AWS credentials
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: aws-creds
  namespace: crossplane-system
type: Opaque
stringData:
  credentials: |
    [default]
    aws_access_key_id = YOUR_ACCESS_KEY
    aws_secret_access_key = YOUR_SECRET_KEY
EOF

# Apply ProviderConfig
kubectl apply -f provider/providerconfig.yaml

# Apply XRDs and Compositions
kubectl apply -f xrds/
kubectl apply -f compositions/
```

### Bước 2: Cài đặt ArgoCD

```bash
cd ../2-argocd

kubectl create namespace argocd
helm repo add argo https://argoproj.github.io/argo-helm
helm upgrade --install argocd argo/argo-cd \
  -n argocd -f argocd-values.yaml --wait

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

**Access:** https://localhost:8080 (user: admin)

### Bước 3: Cài đặt Backstage

**Option A - Docker (nhanh nhất):**
```bash
docker run -d -p 7007:7007 \
  -e GITHUB_TOKEN=your_github_token \
  --name backstage \
  roadiehq/community-backstage-image
```

**Option B - Helm:**
```bash
kubectl create namespace backstage
kubectl create secret generic backstage-secrets \
  --namespace backstage \
  --from-literal=github-token=YOUR_GITHUB_TOKEN

helm repo add backstage https://backstage.github.io/charts
helm install backstage backstage/backstage \
  -n backstage -f 3-backstage/backstage-helm-values.yaml
```

**Access:** http://localhost:7007

### Bước 4: Cấu hình GitHub Secrets

Cho mỗi repository được tạo, cần có các secrets sau (có thể set ở Organization level):

- `ARGOCD_SERVER` - ArgoCD server URL (e.g., `argocd.example.com`)
- `ARGOCD_AUTH_TOKEN` - ArgoCD auth token
- `KUBECONFIG` - (optional) Kubeconfig cho kubectl access

**Tạo ArgoCD token:**
```bash
argocd account generate-token --account admin --id backstage
```

### Bước 5: Register Templates trong Backstage

1. Access Backstage: http://localhost:7007
2. Go to **Create** menu
3. Click **Register Existing Component**
4. Enter URL đến template files

---

## 🎬 Demo Flow

1. **User mở Backstage** → Chọn "Create" → Chọn "AWS S3 Bucket"
2. **Điền form** → Bucket name, region, environment, owner
3. **Submit** → Backstage tạo GitHub repo mới với manifests
4. **GitHub Actions triggered** → Register repo với ArgoCD, tạo Application
5. **ArgoCD syncs** → Apply Crossplane claim vào K8s
6. **Crossplane provisions** → Tạo S3 bucket thật trên AWS
7. **Status visible** → Backstage hiển thị resource status

---

## 🔧 Versions

| Component | Version |
|-----------|---------|
| Crossplane | v1.15.x |
| ArgoCD | v2.10.x |
| Backstage | latest |
| AWS Providers | v1.1.x |

---

## 📝 Notes

- Đây là POC cho môi trường dev, không sử dụng cho production
- AWS resources sẽ được tạo thật và có thể phát sinh chi phí
- Nhớ chạy `scripts/cleanup.sh` để xóa resources sau khi demo
