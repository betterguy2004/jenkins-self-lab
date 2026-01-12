# S3 Bucket: ${{ values.bucketName }}

## Overview

| Property | Value |
|----------|-------|
| **Bucket Name** | `${{ values.bucketName }}` |
| **Environment** | ${{ values.environment }} |
| **Region** | ${{ values.region }} |
| **Owner** | ${{ values.owner }} |
| **Created** | ${{ values.timestamp }} |

## Configuration

- **Versioning**: ${{ values.versioning }}
- **Encryption**: ${{ values.encryption }}
- **Public Access**: ${{ values.publicAccess }}

## Description

${{ values.description }}

## Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Backstage  │────▶│   GitHub    │────▶│   ArgoCD    │────▶│  Crossplane │
│  (Created)  │     │  (This Repo)│     │   (Sync)    │     │  (Provision)│
└─────────────┘     └─────────────┘     └─────────────┘     └──────┬──────┘
                                                                    │
                                                                    ▼
                                                            ┌─────────────┐
                                                            │   AWS S3    │
                                                            │   Bucket    │
                                                            └─────────────┘
```

## Files

- `manifests/s3-claim.yaml` - Crossplane S3Bucket claim
- `catalog-info.yaml` - Backstage catalog entity
- `.github/workflows/deploy-infrastructure.yaml` - Deployment workflow

## Links

- [AWS S3 Console](https://console.aws.amazon.com/s3/buckets/${{ values.bucketName }})
- [ArgoCD Application](https://argocd.example.com/applications/s3-${{ values.bucketName }})
- [Backstage Component](http://backstage.example.com/catalog/default/component/s3-${{ values.bucketName }})

## Managed By

This resource is managed via GitOps:
1. Changes to this repository trigger ArgoCD sync
2. ArgoCD applies Crossplane claims to Kubernetes
3. Crossplane provisions/updates AWS resources

**Do not modify AWS resources directly!** Make changes through this repository.
