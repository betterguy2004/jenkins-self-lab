# VPC Network: ${{ values.networkName }}

## Overview

| Property | Value |
|----------|-------|
| **Network Name** | `${{ values.networkName }}` |
| **CIDR** | ${{ values.vpcCidr }} |
| **AZs** | ${{ values.numberOfAZs }} |
| **Environment** | ${{ values.environment }} |
| **Region** | ${{ values.region }} |
| **Owner** | ${{ values.owner }} |

## Configuration

- **DNS Hostnames**: ${{ values.enableDnsHostnames }}
- **DNS Support**: ${{ values.enableDnsSupport }}
- **NAT Gateway**: ${{ values.createNatGateway }}

## Description

${{ values.description }}

## Managed By

This resource is managed via GitOps. Do not modify AWS resources directly!
