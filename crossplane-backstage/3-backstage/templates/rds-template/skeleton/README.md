# RDS Database: ${{ values.databaseName }}

## Overview

| Property | Value |
|----------|-------|
| **Database Name** | `${{ values.databaseName }}` |
| **Engine** | ${{ values.engine }} ${{ values.engineVersion }} |
| **Instance Class** | ${{ values.instanceClass }} |
| **Storage** | ${{ values.allocatedStorage }} GB |
| **Environment** | ${{ values.environment }} |
| **Region** | ${{ values.region }} |
| **Owner** | ${{ values.owner }} |

## Configuration

- **Multi-AZ**: ${{ values.multiAZ }}
- **Publicly Accessible**: ${{ values.publiclyAccessible }}

## Description

${{ values.description }}

## Managed By

This resource is managed via GitOps. Do not modify AWS resources directly!
