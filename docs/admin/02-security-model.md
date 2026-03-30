# TinyCo Entra ID — Security & Privilege Model

**Document Type:** Admin Documentation  
**Author:** Will Chang, IT Operations Engineer  
**Audience:** TinyCo IT Administrator  
**Last Updated:** March 2026  
**Repository:** https://github.com/WCTinyCoDDG/WC-TinyCo-Entra-Migration

---

## Overview

This document describes the security architecture and privilege model 
implemented for TinyCo's Microsoft Entra ID tenant. Every decision 
follows the principle of least privilege — users and teams receive only 
the access they need to perform their role, nothing more.

At the scale TinyCo is heading toward, identity is the security 
perimeter. A well-structured privilege model means that a compromised 
account causes limited damage, an offboarded employee loses access 
automatically, and an auditor can verify the entire access model 
from a single view.

---

## Core Security Principles

### Least Privilege
Every team receives the minimum access required to perform their 
function. No team has more access than their role requires.

### Group-Based Access
Permissions are assigned to groups, never to individual users. 
This means:
- Adding a user to a group instantly grants them the correct access
- Removing a user from a group instantly revokes all associated access
- Access is auditable at the group level — one view shows who has what

### Identity as the Perimeter
TinyCo is a remote-first company. There is no corporate network 
perimeter to hide behind — every resource is accessed over the 
internet. This means identity verification is the primary security 
control. Every sign-in is evaluated by Conditional Access before 
access is granted.

---

## RBAC Model

### Entra ID Directory Roles

| Team | Entra Role | What They Can Do |
|---|---|---|
| **ITOps** | Global Administrator | Full control over the entire Entra tenant — manage users, groups, apps, policies, and all settings |
| **Security** | Security Reader | Read-only access to all security settings, audit logs, and sign-in reports across the tenant |
| All others | No directory role | Standard users — can access assigned applications only |

### Azure Subscription Roles

| Team | Azure Role | What They Can Do |
|---|---|---|
| **SRE** | Contributor | Create and manage all Azure cloud resources — VMs, networking, storage. Cannot manage identity |
| **Backend** | Reader | View Azure cloud resources and infrastructure they depend on. Cannot make changes |
| All others | No subscription role | No Azure infrastructure access |

### Why These Specific Roles?

**ITOps → Global Administrator**
ITOps is responsible for the entire tenant. They provision users, 
manage applications, configure security policies, and respond to 
incidents. Global Administrator is the only role that provides 
the full access scope required for these responsibilities.

**SRE → Contributor**
SRE manages TinyCo's cloud infrastructure — spinning up VMs, 
configuring networks, managing storage. Contributor grants full 
resource management without the ability to modify identity or 
security settings. This separation ensures cloud operations 
and identity administration remain distinct functions.

**Security → Security Reader**
The Security team's role is to audit, not administer. Security 
Reader provides complete read-only visibility across all security 
settings, Conditional Access policies, sign-in logs, and audit 
trails — everything needed to investigate incidents and validate 
compliance without the ability to accidentally modify configurations.

**Backend → Reader**
Backend engineers need visibility into the Azure infrastructure 
their applications run on — resource health, configuration, 
networking topology. Reader provides this visibility without 
granting any ability to modify resources.

**Frontend, Design, Product, People Ops, Legal → No Azure Role**
These teams have no operational need to access Azure infrastructure 
or Entra administration. Standard user access to their assigned 
applications is sufficient.

---

## Application Access Model

Application access is controlled by group assignment in Entra. 
Only users in an assigned group can access an application via SSO.

| Application | Teams With Access |
|---|---|
| **Tailscale** | All 9 teams |
| **Mattermost** | All 9 teams |
| **Tableau** | ITOps, SRE, Product |
| **Elastic** | ITOps, SRE, Security, Backend, Frontend, People Ops, Legal |
| **Asana** | All 9 teams |
| **Figma** | Design, Frontend, Product, ITOps |
| **Zoom** | All 9 teams |
| **Adobe** | Design, Product, People Ops, Legal |
| **PagerDuty** | ITOps, SRE, Security, Backend |
| **Icinga** | ITOps, SRE, Security, Backend |
| **HackerOne** | Security |
| **ADP** | People Ops, Legal, ITOps |
| **CultureAmp** | People Ops, ITOps |
| **SurveyMonkey** | Product |

---

## Conditional Access Policies

Two Conditional Access policies are enforced tenant-wide:

### Policy 1 — Require MFA for All Users
**Scope:** All users, all applications, all devices  
**Action:** Require multi-factor authentication  
**Exclusion:** Break-glass account (`admin.test@TinyCoDDG.onmicrosoft.com`)

**Rationale:** MFA is the single most impactful security control 
available in Entra. Microsoft's own data shows MFA blocks 99.9% 
of account compromise attacks. At a privacy-focused company like 
TinyCo, protecting user identity is non-negotiable.

### Policy 2 — Block Legacy Authentication
**Scope:** All users, legacy protocol clients (Exchange ActiveSync, other)  
**Action:** Block access entirely  
**Exclusion:** Break-glass account

**Rationale:** Legacy authentication protocols (IMAP, SMTP, POP3, 
older Office clients) do not support MFA. Attackers actively 
exploit these protocols to bypass modern security controls. 
Blocking legacy authentication closes this attack vector entirely 
and is recommended by Microsoft, CIS Benchmarks, and NIST.

### Why Security Defaults Were Disabled
Microsoft enables Security Defaults on all new tenants as a 
basic free security layer. Security Defaults and custom 
Conditional Access policies cannot coexist in the same tenant. 
Since TinyCo operates on an E5 licence with full Conditional 
Access capabilities, Security Defaults were disabled in favour 
of our more granular, auditable custom policies.

---

## Break-Glass Account

**Account:** `admin.test@TinyCoDDG.onmicrosoft.com`  
**Role:** Global Administrator  
**Purpose:** Emergency access and external reviewer testing  
**Password:** Delivered via submission notes

### What is a Break-Glass Account?
A break-glass account is a dedicated emergency access account 
that exists outside normal security controls. It is a standard 
enterprise practice recommended by Microsoft for every Entra tenant.

### Why is it Excluded from Conditional Access?
The break-glass account is excluded from both Conditional Access 
policies so that:
- DDG reviewers can log in without MFA configured on their device
- In a real emergency where all other admin accounts are locked, 
  this account provides guaranteed access to the tenant

### Break-Glass Security Controls
While excluded from Conditional Access, the break-glass account 
is controlled through:
- A strong unique password delivered via secure channel
- Account activity is fully logged in Entra audit logs
- In production, this account would additionally be protected 
  by a Privileged Identity Management (PIM) policy requiring 
  justification for activation

---

## Real-World Context

This security model was designed with TinyCo's growth trajectory 
in mind. At 89 users across 9 teams today, the group-based access 
model is already structured to scale to 300+ users without 
architectural changes.

At Alberta Health Services, I managed identity and access for 
160,000 users across enterprise and clinical environments where 
least-privilege and audit trails were not optional — they were 
required by healthcare compliance standards. That experience 
directly informed the decisions made here:

- Group-based access over individual assignments for auditability
- Clear separation between identity administration (ITOps) and 
  cloud resource management (SRE)
- Read-only audit roles for Security to enable oversight without risk
- A break-glass account following Microsoft's own recommendations

The same principles that protect patient data at a 160,000-user 
healthcare organization apply equally to protecting user privacy 
at a privacy-first technology company.