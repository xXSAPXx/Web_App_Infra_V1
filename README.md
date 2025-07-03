
# Project Architecture Overview:
<img src="https://github.com/user-attachments/assets/9bfc34bd-079e-4131-95d2-fa5fb5e1557b" alt="DEV_OPS PROJECT IaC vpd" width="550"/>



# Infrastructure Deployment with Terraform, AWS, Cloudflare, and Grafana Cloud

This project provisions cloud infrastructure using **Terraform**, integrating **AWS**, **Cloudflare**, and **Grafana Cloud** to deploy a production-ready environment.

---

## ✅ Requirements

Before deploying this infrastructure, ensure the following prerequisites are met:

### 🔧 Software

- **Terraform** `>= 1.10.0`  
  _Used for infrastructure as code (IaC) provisioning._

- **AWS CLI**  
  _Used for checking resources, managing credentials, and manual verification (e.g., EC2 status, logs).

---

### 🌐 Accounts & Services

- **AWS Account**
  - Must have:
    - S3 (for Terraform backend) -- [Check backend.tf]
    - **Key Pair** must exist or be created for SSH access.

- **Cloudflare Account**
  - With:
    - API Token with DNS edit permissions
    - Zone ID of your domain

- **Own Domain Name**
  - Managed in Cloudflare — used for DNS records and HTTPS via AWS ALB.

- **Grafana Cloud Account**
  - With **Prometheus Remote Write** credentials:
    - `prometheus_grafana_user`
    - `prometheus_grafana_api_key`

---

### 🔐 Required Terraform Variables

These must be defined (e.g., in `terraform.tfvars`):

```hcl
# Cloudflare
cloudflare_api_token       = "<YOUR_TOKEN>"
cloudflare_zone_id         = "<YOUR_ZONE_ID>"
cloudflare_domain_name     = "<YOUR_DOMAIN_NAME>"

# AWS EC2 Key Pair
aws_key_pair               = "<YOUR_KEY_PAIR_NAME>"

# Grafana Cloud (Prometheus Remote Write)
prometheus_grafana_user    = "<YOUR_GRAFANA_USERNAME>"
prometheus_grafana_api_key = "<YOUR_GRAFANA_API_KEY>"
