# TinyCo Entra ID Migration — Project Retrospective

**Document Type:** Project Write-Up (Deliverable 7)  
**Author:** Will Chang, IT Operations Engineer  
**Date:** March 2026  
**Repository:** https://github.com/WCTinyCoDDG/WC-TinyCo-Entra-Migration

---

## Overview

This document is an honest account of how the TinyCo Entra ID migration 
project was planned, executed, and what I would do differently with more 
time or in a production environment. It covers technical decisions, 
lessons learned, errors encountered, and the reasoning behind every 
major choice.

---

## What Was Built

A fully deployed Microsoft Entra ID tenant for TinyCo, a fictional 
startup migrating to Microsoft identity infrastructure. The environment 
includes:

- **91 user accounts** — 89 employees across 9 teams, 1 global admin, 
  1 break-glass testing account
- **9 security groups** — one per team, with group-based RBAC and 
  application access
- **4 fully configured Enterprise Apps** — Tailscale (SSO + SCIM), 
  Mattermost (SSO), Tableau (SSO + SCIM), Elastic (SSO + SCIM)
- **10 stub Enterprise App registrations** — Asana, Figma, Zoom, Adobe, 
  PagerDuty, Icinga, HackerOne, ADP, CultureAmp, SurveyMonkey
- **2 Conditional Access policies** — MFA enforcement and legacy 
  authentication blocking
- **Full RBAC model** — Global Admin (ITOps), Contributor (SRE), 
  Security Reader (Security), Reader (Backend)
- **Infrastructure as Code** — entire environment deployable from 
  Terraform in under 5 minutes

---

## Project Management Approach

This project was managed using Asana — DuckDuckGo's own source-of-truth 
tool — from day one. Every task, decision, and milestone was tracked 
with DRI-style ownership, mirroring DDG's async-first workflow.

The Asana board can be viewed here: [WC | TinyCo Entra Migration — 
DDG IT Ops Engineer](https://app.asana.com/your-board-link)

Documentation was written concurrently with technical work rather than 
retrospectively — every decision was captured at the moment it was made, 
while the reasoning was still fresh. This produced significantly higher 
quality documentation than writing from memory at the end.

---

## Key Technical Decisions

### 1. Infrastructure as Code via Terraform

The project brief requested Terraform as the primary tool. Having no 
prior Terraform experience, I approached this as a senior engineer would 
approach any unfamiliar tool — understand the principles first, then 
apply them.

The key insight is that Terraform is declarative: you describe what 
you want to exist, not how to build it. This maps directly to how I've 
approached infrastructure at Alberta Health Services — define the 
desired state, validate it, apply it, verify it.

### 2. CSV-Driven Identity Data Over Hardcoded Values

**Initial approach:** Employee names and team names were hardcoded 
directly into Terraform `locals` blocks. This worked technically but 
committed 89 real employee names to a public GitHub repository.

**Why this was wrong:** DuckDuckGo's core mission is protecting user 
privacy. Committing personal information to public version control 
directly contradicts that mission — even in a test environment. 
A privacy-first engineer doesn't make exceptions for convenience.

**Revised approach:** All employee and team data was moved to two 
gitignored CSV files (`data/employees.csv`, `data/teams.csv`). 
Terraform reads these files at apply time using `csvdecode()`. 
No names, no team data, no PII exists anywhere in the committed codebase.

**Production upgrade path:** The CSV files are a deliberate stand-in 
for a production HR system like ADP. In production, these files would 
be replaced by a direct SCIM feed from the HR system. The Terraform 
code structure would require minimal modification — swap the data 
source, keep the logic.

### 3. Separated Terraform Files by Concern

**Initial approach:** All resources lived in a single `main.tf` file — 
users, groups, RBAC, and Conditional Access in one 300+ line file.

**Revised approach:** Separated into individual files by concern:
- `users.tf` — identity creation
- `groups.tf` — group structure and membership
- `rbac.tf` — role assignments
- `conditional-access.tf` — security policies
- One file per application

**Why:** In a team environment, multiple engineers may need to modify 
different aspects of the infrastructure simultaneously. Separate files 
reduce merge conflicts, make the codebase navigable, and follow the 
single responsibility principle. A new engineer can open `rbac.tf` 
and understand the entire access model without reading 300 lines.

### 4. Break-Glass Account Design

A dedicated break-glass account (`admin.test@TinyCoDDG.onmicrosoft.com`) 
was created and excluded from all Conditional Access policies. This 
follows Microsoft's own recommendation for every Entra tenant.

In this project, the break-glass account serves two purposes:
1. Emergency access if all other admin accounts are locked out
2. DDG reviewer access — allowing inspection of the tenant without 
   MFA configured on the reviewer's personal device

In production, this account would be additionally protected by 
Privileged Identity Management (PIM), requiring justification and 
approval for activation with full audit logging.

### 5. Tailscale Premium Over Free Trial

Tailscale offers a 14-day free trial. The project submission and DDG's 
review window extends beyond 14 days. Rather than risk the environment 
becoming inaccessible mid-review, Tailscale Premium (~$18 USD/month 
for 1 active user) was chosen — well within the $25 allocated budget.

---

## Errors Encountered & Lessons Learned

### Security Defaults Conflict with Conditional Access

**Error:** Terraform failed to create Conditional Access policies with 
`BadRequest: Security Defaults is enabled in the tenant.`

**Cause:** Microsoft enables Security Defaults on all new tenants. 
Security Defaults and custom Conditional Access policies cannot coexist.

**Resolution:** Disabled Security Defaults via Entra admin centre → 
Entra ID → Overview → Properties → Manage Security Defaults.

**Lesson:** New tenant setup should always include disabling Security 
Defaults as an explicit step before deploying Conditional Access. 
This is now documented in `01-setup-guide.md` Step 1.4.

---

### Groups Require `assignable_to_role = true` at Creation

**Error:** Directory role assignments failed with 
`Groups without IsAssignableToRole property set cannot be assigned to roles.`

**Cause:** Entra groups cannot be assigned directory roles unless 
created with `assignable_to_role = true`. This property cannot be 
added to an existing group — the group must be deleted and recreated.

**Resolution:** Added `assignable_to_role = true` to the group 
resource block and ran `terraform apply` to recreate the groups.

**Lesson:** Any Terraform codebase that assigns directory roles to 
groups must include this property from the start. It is now included 
in the `groups.tf` template and documented as a critical note in 
`03-provisioning.md`.

---

### UTF-8 BOM in CSV Files

**Error:** Terraform's `csvdecode()` failed with 
`This object does not have an attribute named "first_name"` despite 
the CSV header clearly showing `first_name`.

**Cause:** The CSV files were exported from Windows which silently 
adds a UTF-8 Byte Order Mark (BOM) — three invisible bytes at the 
start of the file. Terraform reads these bytes as part of the first 
column name, making it unrecognisable.

**Resolution:** Removed the BOM using `sed`:
```bash
sed -i 's/^\xEF\xBB\xBF//' data/employees.csv
```

**Lesson:** Any CSV file sourced from Windows should have its BOM 
stripped before use in Terraform or any other automation tool. 
This step is now documented in `01-setup-guide.md` Step 4.4 as 
a standard data cleaning step.

---

### MFA Challenge on Azure CLI Session

**Error:** `terraform plan` failed mid-session with 
`AADSTS50076: you must use multi-factor authentication.`

**Cause:** The Azure CLI session expired. Our own Conditional Access 
MFA policy was correctly enforced — even on our own CLI session.

**Resolution:** Re-authenticated using:
```bash
az login --tenant [tenant-id] --scope "https://graph.microsoft.com/.default"
```

**Lesson:** This was actually confirmation the Conditional Access 
policy was working correctly before the environment was fully deployed. 
Azure CLI sessions must be refreshed at the start of every working 
session — now documented as the first step in every operational 
procedure.

---

### PeopleOps vs People Ops Naming Inconsistency

**Error:** After switching to CSV-driven groups, Terraform planned to 
destroy `TinyCo-PeopleOps` and create `TinyCo-People Ops` — because 
the original hardcoded code used `PeopleOps` but the CSV used 
`People Ops`.

**Resolution:** Standardised to `PeopleOps` (no space) in the CSV 
using `sed`. Group names with spaces cause issues in some app 
integrations and are inconsistent with the rest of the codebase.

**Lesson:** Establish naming conventions before writing any code and 
enforce them in the data source. Snake_case or CamelCase with no 
spaces is the standard for programmatic identifiers.

---

## What I Would Do Differently With More Time

### 1. Direct HR System Integration
Replace the CSV files with a direct SCIM integration from ADP 
(already registered as a stub app). New hires entered in ADP would 
automatically appear in Entra — zero manual provisioning required. 
At AHS, I managed identity for 160,000 users where manual provisioning 
at scale was simply not viable — automated HR integration is the only 
production-grade approach.

### 2. Privileged Identity Management (PIM)
Implement PIM for all privileged roles. Global Administrators would 
hold eligible (not permanent) access — activating only when needed 
with a logged justification and time-bound approval. This reduces 
the blast radius of a compromised admin account significantly.

### 3. Terraform Remote State
Move `terraform.tfstate` to Azure Blob Storage with state locking. 
In a team environment, multiple engineers running Terraform 
simultaneously against a local state file causes corruption. 
Remote state with locking is the production standard.

### 4. Terraform Plan Saved Output
Use `terraform plan -out=tfplan` to save the plan before applying. 
This guarantees the apply executes exactly what was reviewed — 
important in environments where other changes may occur between 
plan and apply.

### 5. Automated Access Reviews
Configure quarterly access reviews using Entra ID Governance. 
Group owners would be prompted to confirm each member still 
requires access — preventing permission creep over time.

### 6. Entra App Gallery for Known Apps
For well-known SaaS apps like Zoom and Asana, use Entra's app 
gallery templates rather than custom registrations. Gallery apps 
come pre-configured with correct SSO settings — reducing manual 
configuration time significantly.

---

## Real-World Context

My background at Alberta Health Services managing identity for 
160,000 users across enterprise and clinical environments directly 
shaped every decision in this project:

- **Group-based access over individual assignments** — auditable, 
  scalable, and reversible. The same model that works for a 160,000 
  user healthcare org works for a 89 user startup.
- **Identity as the security perimeter** — at AHS, there is no 
  corporate network perimeter. Every resource is accessed over the 
  internet via identity verification. DuckDuckGo's remote-first 
  model operates the same way.
- **Documentation as a first-class deliverable** — at AHS, if a 
  ticket wasn't created, it didn't happen. At Apple, repair notes 
  were the handoff between engineers. Clear documentation is not 
  overhead — it is the work.
- **DRI ownership** — at AHS I managed end-to-end escalation as 
  the single responsible individual for C-suite and enterprise 
  site operations. This project was approached the same way — 
  scoped, planned, executed, and documented by one person with 
  full accountability.

---

## LLM Use Disclosure

Claude (Anthropic) was used throughout this project as a technical 
collaborator and documentation partner. Specifically:

**How Claude was used:**
- Generating Terraform code blocks with explanations of each 
  component — enabling me to understand, defend, and modify 
  every line rather than blindly executing generated code
- Explaining Azure and Entra concepts in plain English as they 
  were encountered — building genuine understanding alongside 
  the practical implementation
- Drafting documentation templates that were reviewed, modified, 
  and approved before committing
- Debugging errors by analysing error output and explaining 
  root causes
- Structuring the project management approach in Asana

**What Claude did not do:**
- Make architectural decisions — every major decision (CSV vs 
  hardcoded, separate files vs monolithic, Tailscale Premium vs 
  trial) was a deliberate choice I made and can defend
- Replace understanding — every piece of code was explained to 
  me before I ran it. I can speak to any line in any file.
- Write this retrospective — the observations, lessons, and 
  real-world connections in this document are my own

The use of an LLM to accelerate learning and implementation on 
an unfamiliar stack is, in my view, exactly how a modern senior 
engineer approaches new technology. The goal was never to pretend 
expertise I don't have — it was to build genuine understanding 
as fast as possible and deliver production-quality work.

---

## Summary

This project asked me to do something I had never done before — 
build a complete Entra ID environment from scratch using Terraform. 

I could have treated it as a box-ticking exercise. Instead I 
treated it as my first week at DuckDuckGo — asking why at every 
step, documenting decisions as they were made, catching my own 
mistakes and fixing them properly, and building something I would 
be proud to hand to another engineer to maintain.

The environment works. The code is clean. The documentation is 
complete. And I understand every line of it.