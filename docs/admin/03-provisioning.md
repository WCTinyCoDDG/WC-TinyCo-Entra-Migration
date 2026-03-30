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
changing team assignments, and adding new groups.

Two methods are available for each operation:

- **Terraform method** — the preferred approach for bulk changes or 
  when maintaining infrastructure as code discipline. All changes are 
  version controlled and auditable in GitHub.
- **Entra portal method** — suitable for urgent one-off changes where 
  speed is prioritised over code discipline. Should be followed up with 
  a Terraform code update to keep the codebase in sync.

---

## How to Provision a New User

### Method 1 — Terraform (Preferred)

**Step 1 — Add the employee to `main.tf`**

Open `terraform/main.tf` in VS Code. Find the `locals` block containing 
the employee list. Add the new employee following the existing format:
```hcl
"firstname.lastname" = { display_name = "First Last", team = "TeamName" }
```

Example — adding a new Backend engineer named Alex Smith:
```hcl
"alex.smith" = { display_name = "Alex Smith", team = "Backend" }
```

Valid team names: `ITOps`, `SRE`, `Security`, `Backend`, `Frontend`, 
`Design`, `Product`, `PeopleOps`, `Legal`

**Step 2 — Apply the change**
```bash
cd ~/Desktop/WC-TinyCo-Entra-Migration/terraform
terraform plan
terraform apply
```

Type `yes` when prompted.

**Step 3 — Commit the change to GitHub**
```bash
cd ~/Desktop/WC-TinyCo-Entra-Migration
git add .
git commit -m "Add new user: Alex Smith (Backend)"
git push
```

**Result:** The user account is created in Entra with the email 
`alex.smith@TinyCoDDG.onmicrosoft.com`, added to the `TinyCo-Backend` 
group, and automatically provisioned in all apps assigned to Backend 
via SCIM within minutes.

---

### Method 2 — Entra Portal (Quick)

1. Go to **Entra admin centre** → **Users** → **New user** → 
   **Create new user**
2. Fill in:
   - **User principal name:** `firstname.lastname@TinyCoDDG.onmicrosoft.com`
   - **Display name:** `First Last`
   - **Password:** Use the standard TinyCo temporary password
   - **Force password change:** Yes
3. Click **Create**
4. Go to **Groups** → find the correct `TinyCo-[Team]` group → 
   **Members** → **Add members** → search and add the new user

> **Important:** After using the portal method, update `main.tf` to 
> include the new user so the codebase stays in sync with reality. 
> If Terraform is run again without the update, it will not recognise 
> the manually created user.

---

## How to Deprovision a User

### Method 1 — Terraform (Preferred)

**Step 1 — Remove the employee from `main.tf`**

Find and delete the employee's entry from the `locals` block in `main.tf`.

**Step 2 — Apply the change**
```bash
terraform plan
terraform apply
```

Review the plan carefully — confirm only the intended user is being 
removed before typing `yes`.

**Step 3 — Commit to GitHub**
```bash
git add .
git commit -m "Deprovision user: Alex Smith (Backend) — offboarded"
git push
```

**Result:** The user account is disabled in Entra and removed from 
all groups. SCIM automatically deprovisions the user from all 
connected apps within minutes.

---

### Method 2 — Entra Portal (Quick)

For immediate access revocation (e.g. urgent termination):

1. Go to **Entra admin centre** → **Users**
2. Search for the user → click their name
3. Click **Revoke sessions** — immediately invalidates all active sessions
4. Click **Edit** → set **Account enabled** to **No** → **Save**

> This is the fastest way to cut off access. Follow up with the 
> Terraform method to formally remove the user from the codebase.

---

## How to Change a User's Team

When an employee moves between teams, their group membership and 
application access must be updated.

### Method 1 — Terraform (Preferred)

**Step 1 — Update the team value in `main.tf`**

Find the employee in the `locals` block and change their `team` value:
```hcl
# Before
"alex.smith" = { display_name = "Alex Smith", team = "Backend" }

# After
"alex.smith" = { display_name = "Alex Smith", team = "Frontend" }
```

**Step 2 — Apply the change**
```bash
terraform plan
terraform apply
```

Terraform will remove the user from `TinyCo-Backend` and add them 
to `TinyCo-Frontend` automatically.

**Step 3 — Commit to GitHub**
```bash
git add .
git commit -m "Team change: Alex Smith moved from Backend to Frontend"
git push
```

**Result:** Group membership updates immediately. SCIM removes access 
to Backend-only apps and grants access to Frontend apps automatically.

---

### Method 2 — Entra Portal (Quick)

1. Go to **Entra admin centre** → **Groups**
2. Find `TinyCo-[OldTeam]` → **Members** → remove the user
3. Find `TinyCo-[NewTeam]` → **Members** → **Add members** → add the user

---

## How to Add a New Group

When TinyCo adds a new team or department, a new security group is needed.

### Method 1 — Terraform (Preferred)

**Step 1 — Add the team name to the groups list in `main.tf`**

Find the `azuread_group` resource block and add the new team:
```hcl
resource "azuread_group" "teams" {
  for_each = toset([
    "ITOps",
    "SRE",
    "Security",
    "Backend",
    "Frontend",
    "Design",
    "Product",
    "PeopleOps",
    "Legal",
    "NewTeamName"    # ← add here
  ])

  display_name       = "TinyCo-${each.key}"
  security_enabled   = true
  mail_enabled       = false
  assignable_to_role = true
  description        = "TinyCo ${each.key} team — access group for apps and RBAC"
}
```

> **Critical:** The `assignable_to_role = true` property must be 
> included at creation time. This property cannot be added to an 
> existing group — the group must be deleted and recreated.

**Step 2 — Assign apps to the new group**

Update the relevant `.tf` app files to include the new group where 
appropriate. For example, if the new team needs Mattermost access, 
add their team name to the `contains([...])` filter in `mattermost.tf`.

**Step 3 — Apply and commit**
```bash
terraform plan
terraform apply
git add .
git commit -m "Add new group: TinyCo-NewTeamName"
git push
```

---

## How to Add a New Application

When TinyCo adopts a new SaaS application, it needs to be registered 
in Entra for SSO and provisioning.

### Step 1 — Create a new Terraform file

Create a new file in the `terraform/` folder named after the app, 
e.g. `notion.tf`. Follow the pattern established by existing app files:
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

### Step 2 — Apply and commit
```bash
terraform plan
terraform apply
git add .
git commit -m "Add new app: TinyCo-Notion"
git push
```

### Step 3 — Configure SSO in Entra portal

After Terraform creates the app registration:

1. Go to **Entra admin centre** → **Enterprise Applications** → 
   find `TinyCo-Notion`
2. Click **Single sign-on** → select **SAML**
3. Fill in the SSO URLs from the app vendor's documentation
4. Download the Entra SAML certificate
5. Paste the certificate and Entra SSO URLs into the app's admin portal

### Step 4 — Configure SCIM (if supported)

1. In the Enterprise App → click **Provisioning**
2. Set **Provisioning Mode** to **Automatic**
3. Enter the SCIM endpoint URL and secret token from the app vendor
4. Click **Test Connection** → **Save**

---

## Production Recommendations

The following improvements are recommended as TinyCo scales beyond 
the current 89-user environment:

**CSV-driven user provisioning**
Replace the hardcoded user list in `main.tf` with a CSV-driven 
`for_each` loop. Adding a new employee becomes as simple as adding 
a row to a CSV file — no Terraform code editing required.

**HR System SCIM Integration**
Connect TinyCo's HR system (e.g. ADP, which is already registered 
as a stub app) directly to Entra via SCIM. New hire data flows 
automatically from HR into Entra — zero manual provisioning required.

**Privileged Identity Management (PIM)**
Use Entra ID Governance PIM to require justification and approval 
for Global Administrator activation. ITOps members would hold 
eligible (not permanent) Global Admin access, activating it 
only when needed with a logged reason.

**Automated Access Reviews**
Schedule quarterly access reviews using Entra ID Governance. 
Group owners are prompted to confirm each member still requires 
access — reducing the risk of stale permissions accumulating over time.