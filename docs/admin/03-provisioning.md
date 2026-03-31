# TinyCo Entra ID — User & Group Provisioning Guide

**Document Type:** Admin Documentation  
**Author:** Will Chang, IT Operations Engineer  
**Audience:** TinyCo IT Administrator  
**Last Updated:** March 2026  
**Repository:** https://github.com/WCTinyCoDDG/WC-TinyCo-Entra-Migration

---

## Overview

This document covers day-to-day administration of the TinyCo Entra ID 
tenant — provisioning new users, deprovisioning departing employees, 
changing team assignments, and adding new groups and applications.

### Source of Truth Philosophy

TinyCo's identity infrastructure is driven by two CSV files that act 
as a stand-in for a production HR system:

- **`data/employees.csv`** — the employee roster. Every account in 
  Entra ID originates from a row in this file.
- **`data/teams.csv`** — the team configuration. Group structure and 
  application access is derived from this file.

These files are stored locally and gitignored — they contain personal 
information that must never be committed to version control.

**The operational principle:**
> Make the change in the CSV first. Then run `terraform apply`. 
> Entra ID reflects the CSV — always.

This mirrors how a production HRIS integration works. In a future 
production environment, these CSV files would be replaced by a direct 
SCIM feed from an HR system like ADP — the Terraform code itself would 
require minimal modification to support that upgrade.

### Two Methods Available

For each operation, two methods are documented:

- **Terraform method** — preferred for all changes. Changes are 
  version controlled, auditable, and reproducible.
- **Entra portal method** — for urgent situations where speed is 
  required. Must be followed up with a CSV and Terraform update 
  to keep the codebase in sync.

---

## Before Any Terraform Operation

Always authenticate your Azure CLI session before running Terraform:
```bash
az login --tenant "42a9915e-aa4a-4426-9a86-a04a0dac6222" \
  --scope "https://graph.microsoft.com/.default"
```

---

## How to Provision a New User

### Method 1 — Terraform (Preferred)

**Step 1 — Add the employee to `employees.csv`**

Open `data/employees.csv` and add a new row:
```
first_name,last_name,team
...existing rows...
Alex,Smith,Backend
```

Valid team names: `ITOps`, `SRE`, `Security`, `Backend`, `Frontend`, 
`Design`, `Product`, `PeopleOps`, `Legal`

**Step 2 — Preview the change**
```bash
cd ~/Desktop/WC-TinyCo-Entra-Migration/terraform
terraform plan
```

Confirm the plan shows exactly 1 new user and 1 new group membership 
being added. Review before proceeding.

**Step 3 — Apply the change**
```bash
terraform apply
```
Type `yes` when prompted.

**Step 4 — Commit the updated CSV is NOT required**

The CSV is gitignored by design — it never goes to GitHub. However, 
ensure your local CSV is backed up securely as it is the source of 
truth for your tenant.

**Result:** The user account `alex.smith@TinyCoDDG.onmicrosoft.com` 
is created in Entra, added to `TinyCo-Backend`, and automatically 
provisioned in all Backend-assigned apps via SCIM within minutes.

---

### Method 2 — Entra Portal (Urgent)

1. **Entra admin centre** → **Users** → **New user** → **Create new user**
2. Fill in:
   - **User principal name:** `firstname.lastname@TinyCoDDG.onmicrosoft.com`
   - **Display name:** `First Last`
   - **Password:** Standard TinyCo temporary password
   - **Force password change:** Yes
3. Click **Create**
4. Go to **Groups** → find `TinyCo-[Team]` → **Members** → 
   **Add members** → add the user

> **Important:** After using the portal method, add the user to 
> `employees.csv` and run `terraform apply` to keep the codebase 
> in sync. Failing to do this means the next `terraform apply` 
> will not recognise the manually created user.

---

## How to Deprovision a User

### Method 1 — Terraform (Preferred)

**Step 1 — Remove the employee from `employees.csv`**

Delete the employee's row from `data/employees.csv`.

**Step 2 — Preview the change**
```bash
terraform plan
```

Carefully review — confirm only the intended user is being removed.

**Step 3 — Apply**
```bash
terraform apply
```

**Result:** The account is disabled in Entra, removed from all groups, 
and deprovisioned from all SCIM-connected apps within minutes.

---

### Method 2 — Entra Portal (Immediate Access Revocation)

For urgent terminations where immediate access cut-off is required:

1. **Entra admin centre** → **Users** → search for the user
2. Click **Revoke sessions** — immediately invalidates all active sessions
3. Click **Edit** → set **Account enabled** to **No** → **Save**

> Follow up with the Terraform method to remove the user from 
> `employees.csv` and keep the codebase in sync.

---

## How to Change a User's Team

When an employee moves between teams their group membership, RBAC 
permissions, and application access all update automatically.

### Method 1 — Terraform (Preferred)

**Step 1 — Update the team value in `employees.csv`**
```
# Before
Alex,Smith,Backend

# After  
Alex,Smith,Frontend
```

**Step 2 — Preview and apply**
```bash
terraform plan
terraform apply
```

Terraform removes the user from `TinyCo-Backend` and adds them to 
`TinyCo-Frontend` automatically. SCIM removes Backend-only app access 
and grants Frontend app access.

---

### Method 2 — Entra Portal

1. **Groups** → `TinyCo-[OldTeam]` → **Members** → remove the user
2. **Groups** → `TinyCo-[NewTeam]` → **Members** → **Add members** → add the user

---

## How to Add a New Group

When TinyCo adds a new team, no Terraform code changes are required. 
Simply add employees with the new team name to `employees.csv` — 
Terraform derives all group names dynamically from the CSV.

**Example — adding a new "Finance" team:**

Add Finance employees to `employees.csv`:
```
Sarah,Jones,Finance
Michael,Brown,Finance
```

Run:
```bash
terraform plan
terraform apply
```

Terraform automatically creates `TinyCo-Finance` and assigns all 
Finance employees to it. No `.tf` file editing required.

> **Critical:** Groups are created with `assignable_to_role = true` 
> by default in this codebase. This property must be set at creation 
> time — it cannot be added to an existing group. The group must be 
> deleted and recreated if this property is missing.

---

## How to Add a New Application

**Step 1 — Create a new Terraform file**

Create `terraform/[appname].tf` following the existing pattern:
```hcl
# notion.tf
resource "azuread_application" "notion" {
  display_name = "TinyCo-Notion"

  web {
    redirect_uris = ["https://www.notion.so/sso/saml"]
  }

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000"
    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"
      type = "Scope"
    }
  }
}

resource "azuread_service_principal" "notion" {
  client_id                    = azuread_application.notion.client_id
  app_role_assignment_required = true
}

resource "azuread_app_role_assignment" "notion_groups" {
  for_each = {
    for k, v in azuread_group.teams :
    k => v
    if contains(["ITOps", "Product"], k)
  }

  app_role_id         = "00000000-0000-0000-0000-000000000000"
  principal_object_id = each.value.id
  resource_object_id  = azuread_service_principal.notion.object_id
}
```

**Step 2 — Apply and commit**
```bash
terraform plan
terraform apply
git add .
git commit -m "Add new app: TinyCo-Notion"
git push
```

**Step 3 — Configure SSO in Entra portal**

1. **Entra admin centre** → **Enterprise Applications** → `TinyCo-Notion`
2. **Single sign-on** → **SAML**
3. Fill in SSO URLs from the app vendor's documentation
4. Download the Entra SAML certificate
5. Paste certificate and Entra SSO URLs into the app's admin portal

**Step 4 — Configure SCIM (if supported)**

1. Enterprise App → **Provisioning** → **Automatic**
2. Enter SCIM endpoint URL and secret token from app vendor
3. **Test Connection** → **Save**

---

## Production Recommendations

**CSV-driven provisioning is the current approach** — suitable for 
TinyCo's current scale of 89 users. As the organization grows, 
the following upgrades are recommended:

**HR System SCIM Integration**  
Connect TinyCo's HR system (ADP is already registered as a stub app) 
directly to Entra via SCIM. New hire data flows automatically from 
HR into Entra — the `employees.csv` file becomes unnecessary. 
The Terraform code structure supports this upgrade with minimal changes.

**Privileged Identity Management (PIM)**  
Use Entra ID Governance PIM to require justification and time-bound 
activation for Global Administrator access. ITOps members hold 
eligible (not permanent) Global Admin — activating only when needed 
with a logged reason.

**Automated Access Reviews**  
Schedule quarterly access reviews using Entra ID Governance. 
Group owners confirm each member still requires access — reducing 
stale permissions over time.

**Terraform Remote State**  
Move `terraform.tfstate` to Azure Blob Storage with state locking. 
This enables multiple administrators to run Terraform safely without 
state file conflicts.