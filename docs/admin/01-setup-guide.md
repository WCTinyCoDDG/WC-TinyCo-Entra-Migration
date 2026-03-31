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

### Architecture Philosophy

Employee and team data is intentionally kept out of version control. 
Two CSV files serve as the source of truth for all identity data — 
mirroring how a production HR system like ADP would feed into Entra ID. 
This means:

- No employee names or team names are hardcoded in any `.tf` file
- Adding or removing an employee = updating the CSV, running `terraform apply`
- The same Terraform code works for any organization by swapping the CSV files
- In production, the CSV files would be replaced by a direct SCIM feed 
  from the HR system with minimal code changes required

---

## Prerequisites

### Required Accounts

| Account | Purpose | Cost |
|---|---|---|
| Microsoft 365 E5 Trial | Entra ID P2, Conditional Access, ID Governance | Free (30 days) |
| Azure Free Account | $200 CAD credit included, Linux VM hosting, RBAC scope | Free credit |
| Tailscale Premium | VPN with SSO + SCIM provisioning | ~$18 USD/month |
| GitHub | Code repository for Terraform files | Free |

> **Tailscale note:** The free trial lasts 14 days. Since DDG's review 
> window extends beyond 14 days from project submission, Tailscale 
> Premium ($18 USD/month for 1 active user) was chosen to ensure 
> the environment remains accessible throughout the full review period.

### Required Tools (Windows 11)

| Tool | Download | Purpose |
|---|---|---|
| Git (64-bit) | git-scm.com | Version control |
| Azure CLI (64-bit) | aka.ms/installazurecliwindowsx64 | Azure authentication |
| Terraform | developer.hashicorp.com/terraform/install | Infrastructure as Code |
| VS Code | code.visualstudio.com | Code editor |
| HashiCorp Terraform Extension | VS Code Marketplace | Terraform syntax support |

---

## Step 1 — Microsoft 365 & Azure Setup

### 1.1 Create Microsoft 365 E5 Trial
1. Go to **microsoft.com/en-us/microsoft-365/enterprise/office-365-e5**
2. Click **Try for free** → sign up with a new email
3. Choose your tenant domain — this guide uses `TinyCoDDG.onmicrosoft.com`
4. Complete setup — your admin account will be `WC@TinyCoDDG.onmicrosoft.com`

### 1.2 Link Azure Free Account
1. Go to **portal.azure.com** and sign in with your M365 admin account
2. Sign up for a free Azure account — you will receive $200 CAD in credits
3. Confirm the subscription appears under your TinyCo tenant
4. Verify in **Subscriptions** — note your **Subscription ID** for later

### 1.3 Create Tailscale Account
1. Go to **tailscale.com** → click **Get Started**
2. Sign in using your **Microsoft account** (`WC@TinyCoDDG.onmicrosoft.com`)
3. Tailscale will auto-enroll you in a 14-day Premium trial
4. After the trial, subscribe to **Premium** (~$18 USD/month for 1 user)

> **Why sign in with Microsoft?** Using your M365 identity from the start 
> makes SSO wiring significantly cleaner — no identity mismatch to debug later.

### 1.4 Disable Security Defaults
Entra enables Security Defaults on all new tenants. This must be disabled
before custom Conditional Access policies can be applied.

1. Go to **Entra admin centre** → **Entra ID** → **Overview** → **Properties**
2. Click **Manage security defaults**
3. Set Security defaults to **Disabled**
4. Click **Save**

> **Why:** Security Defaults and custom Conditional Access policies cannot
> coexist in the same tenant. Since TinyCo uses an E5 licence with full 
> Conditional Access, we disable Security Defaults and replace it with 
> more granular, auditable custom policies.

---

## Step 2 — Local Environment Setup

### 2.1 Install Git
1. Download from **git-scm.com/download/win** — select the 64-bit installer
2. During install:
   - Default editor → select **Visual Studio Code**
   - Initial branch name → select **main**
   - Leave all other options as default
3. Verify:
```bash
git --version
```
Expected: `git version 2.x.x`

### 2.2 Configure Git Identity
```bash
git config --global user.name "Will Chang"
git config --global user.email "WCTinyCoLab@outlook.com"
```
Verify:
```bash
git config --list
```

### 2.3 Install Azure CLI (64-bit)
1. Download from **aka.ms/installazurecliwindowsx64**
2. Run installer — all defaults are fine
3. Verify in a new Git Bash window:
```bash
az --version
```

### 2.4 Install Terraform
1. Download from **developer.hashicorp.com/terraform/install** → **Windows AMD64**
2. Extract the zip — you will find a single file: `terraform.exe`
3. Create folder: `C:\terraform`
4. Move `terraform.exe` into `C:\terraform\`
5. Add to PATH:
   - `Windows key` → search **Environment Variables**
   - **Edit the system environment variables** → **Environment Variables**
   - Under **System variables** → find **Path** → **Edit**
   - Click **New** → type `C:\terraform` → OK → OK → OK
6. Verify in a new Git Bash window:
```bash
terraform --version
```

### 2.5 Install VS Code + Terraform Extension
1. Download from **code.visualstudio.com**
2. During install — check both **"Open with Code"** context menu options
3. Ensure **"Add to PATH"** is checked
4. After install → Extensions (`Ctrl+Shift+X`) → search **HashiCorp Terraform** → Install

---

## Step 3 — Clone Repository & Authenticate

### 3.1 Clone the Repository
```bash
cd ~/Desktop
git clone https://github.com/WCTinyCoDDG/WC-TinyCo-Entra-Migration.git
cd WC-TinyCo-Entra-Migration
code .
```

### 3.2 Authenticate Azure CLI

> **Important:** Run this command at the start of every working session. 
> Azure CLI sessions expire and require re-authentication. Always 
> authenticate before running any Terraform commands.
```bash
az login --tenant "42a9915e-aa4a-4426-9a86-a04a0dac6222" \
  --scope "https://graph.microsoft.com/.default"
```

Your browser will open — sign in with your Entra admin account and 
complete MFA when prompted.

Verify:
```bash
az account show
```
Confirm `tenantDefaultDomain` shows `TinyCoDDG.onmicrosoft.com`

---

## Step 4 — Prepare Employee & Team Data

The Terraform code reads employee and team information from two CSV 
files stored locally. These files are gitignored and never committed 
to version control — they contain personal information that must be 
kept private.

### 4.1 Create the Data Folder
```bash
mkdir ~/Desktop/WC-TinyCo-Entra-Migration/data
```

### 4.2 Add Employee & Team CSV Files
Place the following files in the `data/` folder:
- `employees.csv` — one row per employee
- `teams.csv` — one row per team

### 4.3 Required CSV Format

**`employees.csv`** — must use exactly these headers:
```
first_name,last_name,team
Paula,Humphrey,Backend
Emmy,Dillon,Backend
...
```

**`teams.csv`** — must use exactly these headers:
```
team,applications,role_requirements
ITOps,"Asana,TailScale,Tableau...",Administrate the entire tenant
SRE,"Asana,TailScale,Tableau...",Administrate Azure cloud resources
...
```

### 4.4 Clean the CSV Files

CSV files exported from Windows often contain a UTF-8 BOM 
(Byte Order Mark) — three invisible bytes at the start of the file 
that cause Terraform's `csvdecode` function to fail. Remove them:
```bash
sed -i 's/^\xEF\xBB\xBF//' ~/Desktop/WC-TinyCo-Entra-Migration/data/employees.csv
sed -i 's/^\xEF\xBB\xBF//' ~/Desktop/WC-TinyCo-Entra-Migration/data/teams.csv
```

Verify the BOM is removed:
```bash
head -1 ~/Desktop/WC-TinyCo-Entra-Migration/data/employees.csv | cat -A
```

Expected output: `first_name,last_name,team$`

> **What is a BOM?** A Byte Order Mark is an invisible signature 
> Windows adds to UTF-8 files. Most tools ignore it, but Terraform 
> reads it literally as part of the first column name — causing 
> attribute errors. The `sed` command removes it silently.

### 4.5 Standardize Team Names
Ensure team names in `employees.csv` use no spaces — use `PeopleOps` 
not `People Ops`. This ensures consistency with group names in Entra 
and prevents naming conflicts in app assignments:
```bash
sed -i 's/People Ops/PeopleOps/g' \
  ~/Desktop/WC-TinyCo-Entra-Migration/data/employees.csv
```

### 4.6 Verify the Data Folder is Gitignored
```bash
cd ~/Desktop/WC-TinyCo-Entra-Migration
git status
```

Confirm `data/employees.csv` and `data/teams.csv` do **not** appear 
in the output. If they do appear, add the following to `.gitignore`:
```
# Employee and team data — contains PII, never commit to version control
data/employees.csv
data/teams.csv
```

---

## Step 5 — Configure Terraform Variables

### 5.1 Create `terraform.tfvars`
Navigate to the terraform folder:
```bash
cd ~/Desktop/WC-TinyCo-Entra-Migration/terraform
```

Create a new file named `terraform.tfvars`:
```hcl
tenant_id       = "YOUR_TENANT_ID"
subscription_id = "YOUR_SUBSCRIPTION_ID"
admin_password  = "YOUR_CHOSEN_PASSWORD"
```

Replace values with:
- `tenant_id` — found in Entra admin centre → Overview
- `subscription_id` — found in Azure portal → Subscriptions
- `admin_password` — minimum 8 characters, must include uppercase, 
  lowercase, number, and special character

> **Security note:** `terraform.tfvars` is listed in `.gitignore` 
> and will never be pushed to GitHub. It contains sensitive credentials 
> and must be kept local at all times.

**TinyCo reference values:**
| Item | Value |
|---|---|
| Tenant ID | `42a9915e-aa4a-4426-9a86-a04a0dac6222` |
| Subscription ID | `29923100-cb5f-44bc-aec9-1207134ba164` |
| Tenant Domain | `TinyCoDDG.onmicrosoft.com` |

---

## Step 6 — Deploy the Environment

### 6.1 Initialize Terraform
```bash
terraform init
```
Expected: `Terraform has been successfully initialized!`

### 6.2 Review the Plan
```bash
terraform plan
```
Review every resource that will be created. Expected summary:
`Plan: ~254 to add, 0 to change, 0 to destroy`

### 6.3 Apply the Configuration
```bash
terraform apply
```
Type `yes` when prompted. Takes approximately 3-5 minutes.

Expected: `Apply complete! Resources: X added, 0 changed, 0 destroyed`

> **Note:** If the apply is interrupted, run `terraform apply` again. 
> Terraform is idempotent — it only creates what is missing and never 
> duplicates existing resources.

---

## Step 7 — Verify the Environment

| Check | Location | Expected |
|---|---|---|
| Users | Entra → Users | 91 users (89 employees + admin + break-glass) |
| Groups | Entra → Groups | 12 groups (9 TinyCo + 3 Microsoft default) |
| Enterprise Apps | Entra → Enterprise Applications → search "TinyCo" | 14 apps |
| Conditional Access | Entra → Security → Conditional Access | 2 policies active |
| RBAC — SRE | Azure portal → Subscriptions → IAM | TinyCo-SRE: Contributor |
| RBAC — Backend | Azure portal → Subscriptions → IAM | TinyCo-Backend: Reader |

---

## Terraform File Reference

| File | Purpose |
|---|---|
| `providers.tf` | Azure and Entra provider configuration |
| `variables.tf` | Variable definitions |
| `terraform.tfvars` | Actual values — gitignored, never on GitHub |
| `users.tf` | All 89 employee accounts, CSV-driven |
| `groups.tf` | 9 security groups, teams derived from CSV |
| `rbac.tf` | Azure and Entra role assignments |
| `conditional-access.tf` | MFA policy, legacy auth block, break-glass account |
| `tailscale.tf` | Tailscale Enterprise App registration |
| `mattermost.tf` | Mattermost Enterprise App registration |
| `tableau.tf` | Tableau Enterprise App registration |
| `elastic.tf` | Elastic Enterprise App registration |
| `apps-stub.tf` | Stub registrations for remaining apps |

---

## Important Reference IDs

| Item | Value |
|---|---|
| Tenant ID | `42a9915e-aa4a-4426-9a86-a04a0dac6222` |
| Subscription ID | `29923100-cb5f-44bc-aec9-1207134ba164` |
| Tenant Domain | `TinyCoDDG.onmicrosoft.com` |
| Admin Account | `WC@TinyCoDDG.onmicrosoft.com` |
| Break-glass Account | `admin.test@TinyCoDDG.onmicrosoft.com` |
| Break-glass Password | `[delivered via submission notes]` |