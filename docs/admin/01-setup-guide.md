# TinyCo Entra ID Environment — Setup & Recreation Guide

**Document Type:** Admin Documentation  
**Author:** Will Chang, IT Operations Engineer  
**Audience:** TinyCo IT Administrator  
**Last Updated:** March 2026  
**Repository:** https://github.com/WCTinyCoDDG/WC-TinyCo-Entra-Migration

---

## Overview

This guide provides complete step-by-step instructions to recreate the 
TinyCo Microsoft Entra ID environment from scratch using the provided 
Terraform code. A reviewer or administrator following this guide should 
be able to fully reproduce the environment with no prior knowledge of 
how it was originally built.

The environment includes:
- 89 TinyCo employee accounts across 9 teams
- 9 Entra security groups with role-based access control
- Conditional Access policies enforcing MFA tenant-wide
- 14 Enterprise Application registrations (4 fully configured, 10 stubbed)
- A dedicated break-glass testing account for administrative access

---

## Prerequisites

Before starting, ensure you have the following accounts and tools ready:

### Required Accounts
| Account | Purpose | Cost |
|---|---|---|
| Microsoft 365 E5 Trial | Entra ID P2, Conditional Access, ID Governance | Free (30 days) |
| Azure Pay-As-You-Go | Linux VM hosting, subscription for RBAC scope | ~$20 CAD estimated |
| Tailscale Premium | VPN with SSO + SCIM provisioning | ~$18 USD/month |
| GitHub | Code repository for Terraform files | Free |

### Required Tools (Windows 11)
| Tool | Download | Purpose |
|---|---|---|
| Git (64-bit) | git-scm.com | Version control |
| Azure CLI (64-bit) | aka.ms/installazurecliwindowsx64 | Azure authentication |
| Terraform | developer.hashicorp.com/terraform/install | Infrastructure as Code |
| VS Code | code.visualstudio.com | Code editor |
| VS Code HashiCorp Terraform Extension | VS Code Marketplace | Terraform syntax support |

---

## Step 1 — Microsoft 365 & Entra Setup

### 1.1 Create Microsoft 365 E5 Trial
1. Go to **microsoft.com/en-us/microsoft-365/enterprise/office-365-e5**
2. Click **Try for free** → sign up with a new email
3. Choose your tenant domain — this guide uses `TinyCoDDG.onmicrosoft.com`
4. Complete setup — your admin account will be `WC@TinyCoDDG.onmicrosoft.com`

### 1.2 Link Azure Subscription
1. Go to **portal.azure.com** and sign in with your M365 admin account
2. Search for **Subscriptions** → click **Add**
3. Select **Pay-As-You-Go** → complete billing setup
4. Confirm subscription appears under your TinyCo tenant

### 1.3 Disable Security Defaults
Entra enables Security Defaults on all new tenants. This must be disabled
before custom Conditional Access policies can be applied.

1. Go to **Entra admin centre** → **Entra ID** → **Overview** → **Properties**
2. Click **Manage security defaults**
3. Set Security defaults to **Disabled**
4. Click **Save**

> **Why:** Security Defaults and custom Conditional Access policies cannot
> run simultaneously. Since TinyCo uses an E5 licence with full Conditional
> Access, we disable Security Defaults and replace it with our own
> more granular policies.

---

## Step 2 — Local Environment Setup

### 2.1 Install Git
1. Download from **git-scm.com/download/win** — select the 64-bit installer
2. During install, when asked about default editor → select **Visual Studio Code**
3. When asked about initial branch name → select **main**
4. Leave all other options as default
5. Verify installation — open Git Bash and run:
```bash
git --version
```
Expected output: `git version 2.x.x`

### 2.2 Configure Git Identity
Run these commands in Git Bash — replace with your own details:
```bash
git config --global user.name "Will Chang"
git config --global user.email "WCTinyCoLab@outlook.com"
```
Verify with:
```bash
git config --list
```
Confirm `user.name` and `user.email` appear in the output.

### 2.3 Install Azure CLI
1. Download from **aka.ms/installazurecliwindowsx64** (64-bit MSI)
2. Run installer — all defaults are fine
3. Open a new Git Bash window and verify:
```bash
az --version
```
Expected output: `azure-cli x.x.x` at the top of the list.

### 2.4 Install Terraform
1. Download from **developer.hashicorp.com/terraform/install** → select **Windows AMD64**
2. Extract the zip — you will find a single file: `terraform.exe`
3. Create a folder: `C:\terraform`
4. Move `terraform.exe` into `C:\terraform\`
5. Add to PATH:
   - Press `Windows key` → search **Environment Variables**
   - Click **Edit the system environment variables**
   - Click **Environment Variables**
   - Under **System variables** → find **Path** → click **Edit**
   - Click **New** → type `C:\terraform`
   - Click OK → OK → OK
6. Open a new Git Bash window and verify:
```bash
terraform --version
```
Expected output: `Terraform v1.x.x`

### 2.5 Install VS Code + Terraform Extension
1. Download VS Code from **code.visualstudio.com**
2. During install, check both **"Open with Code"** context menu options
3. Ensure **"Add to PATH"** is checked
4. After install, open VS Code → Extensions (`Ctrl+Shift+X`)
5. Search **HashiCorp Terraform** → install the official extension (6M+ downloads)

---

## Step 3 — Clone Repository & Authenticate

### 3.1 Clone the Repository
Open Git Bash and run:
```bash
cd ~/Desktop
git clone https://github.com/WCTinyCoDDG/WC-TinyCo-Entra-Migration.git
cd WC-TinyCo-Entra-Migration
code .
```
This downloads the project and opens it in VS Code.

### 3.2 Authenticate Azure CLI
```bash
az logout
az login --tenant "42a9915e-aa4a-4426-9a86-a04a0dac6222" \
  --scope "https://graph.microsoft.com/.default"
```
Your browser will open — sign in with your Entra admin account and 
complete MFA when prompted.

Verify authentication:
```bash
az account show
```
Confirm `tenantDefaultDomain` shows `TinyCoDDG.onmicrosoft.com`

---

## Step 4 — Configure Terraform Variables

### 4.1 Create terraform.tfvars
Navigate to the terraform folder and create the variables file:
```bash
cd ~/Desktop/WC-TinyCo-Entra-Migration/terraform
```

Create a new file named `terraform.tfvars` with the following content:
```hcl
tenant_id       = "YOUR_TENANT_ID"
subscription_id = "YOUR_SUBSCRIPTION_ID"
admin_password  = "YOUR_CHOSEN_PASSWORD"
```

Replace values with:
- `tenant_id` — found in Entra admin centre → Overview
- `subscription_id` — found in Azure portal → Subscriptions
- `admin_password` — choose a strong password meeting Azure requirements
  (min 8 chars, uppercase, lowercase, number, special character)

> **Security note:** `terraform.tfvars` is listed in `.gitignore` and will
> never be pushed to GitHub. It contains sensitive credentials and must
> be kept local at all times.

---

## Step 5 — Deploy the Environment

### 5.1 Initialize Terraform
```bash
terraform init
```
This downloads the required Azure and Entra providers. 
Expected output ends with: `Terraform has been successfully initialized!`

### 5.2 Review the Plan
```bash
terraform plan
```
Terraform will show every resource it intends to create.
Expected summary: `Plan: 254 to add, 0 to change, 0 to destroy`

Review the plan carefully before proceeding.

### 5.3 Apply the Configuration
```bash
terraform apply
```
Type `yes` when prompted.

This process takes approximately 3-5 minutes as Terraform makes 
API calls to Azure for each resource.

Expected final output: `Apply complete! Resources: 254 added, 0 changed, 0 destroyed`

> **Note:** If the apply is interrupted, simply run `terraform apply` again.
> Terraform is idempotent — it will only create what is missing and will
> never duplicate existing resources.

---

## Step 6 — Verify the Environment

After apply completes, verify the following in the Entra admin centre:

| Check | Location | Expected |
|---|---|---|
| Users | Entra → Users | 91 users (89 employees + admin + break-glass) |
| Groups | Entra → Groups | 12 groups (9 TinyCo + 3 Microsoft default) |
| Enterprise Apps | Entra → Enterprise Applications | 14 TinyCo apps (search "TinyCo") |
| Conditional Access | Entra → Security → Conditional Access | 2 policies active |
| RBAC — SRE | Azure portal → Subscriptions → IAM | TinyCo-SRE: Contributor |
| RBAC — Backend | Azure portal → Subscriptions → IAM | TinyCo-Backend: Reader |

---

## Known Issues & Notes

| Issue | Resolution |
|---|---|
| Security Defaults conflict | Must be disabled before Conditional Access policies can be created (Step 1.3) |
| Groups not assignable to roles | Groups must be created with `assignable_to_role = true` — already included in provided code |
| MFA challenge on CLI | Re-authenticate using `az login --tenant [id] --scope [graph url]` |
| `terraform.tfvars` warning | File is gitignored by design — create it manually from Step 4.1 |

---

## Important IDs Reference

| Item | Value |
|---|---|
| Tenant ID | `42a9915e-aa4a-4426-9a86-a04a0dac6222` |
| Subscription ID | `29923100-cb5f-44bc-aec9-1207134ba164` |
| Tenant Domain | `TinyCoDDG.onmicrosoft.com` |
| Admin Account | `WC@TinyCoDDG.onmicrosoft.com` |
| Break-glass Account | `admin.test@TinyCoDDG.onmicrosoft.com` |
| Break-glass Password | `[delivered via submission notes]` |