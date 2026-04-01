# TinyCo Tableau Cloud — Entra ID SAML SSO Troubleshooting Log

**Document Type:** Technical Troubleshooting Log  
**Author:** Will Chang, IT Operations Engineer  
**Audience:** TinyCo IT Administrator  
**Last Updated:** March 2026  
**Status:** ✅ RESOLVED  
**Reference:** https://help.tableau.com/current/online/en-us/saml_config_azure_ad.htm

---

## Overview

This document is a complete chronological log of every attempt made to 
configure Entra ID SAML SSO for Tableau Cloud. It serves both as a 
troubleshooting reference and as an honest account of the configuration 
challenges encountered.

**Environment:**
- Tableau Cloud (free trial)
- Site ID: `wctinycolab-33a6800945`
- Entra tenant: `TinyCoDDG.onmicrosoft.com`
- Tableau admin account: `WCTinyCoLab@outlook.com`
- Test SSO account: `WC@TinyCoDDG.onmicrosoft.com`

---

## Root Cause Summary

Two compounding issues caused SSO failures:

1. **Wrong app registration type** — TinyCo-Tableau was created as a 
   custom OIDC app via Terraform instead of using the Entra gallery 
   Tableau Cloud app template. Custom apps require manual API permission 
   grants and don't support SAML out of the box.

2. **Sign On URL misconfiguration** — Adding a Sign On URL in the Entra 
   Basic SAML Configuration bypasses IdP-initiated SSO flow. Per official 
   Tableau documentation, this field must be left blank.

---

## Attempt 1 — Custom OIDC App Registration (Terraform)

**What we tried:**
Our Terraform codebase created `TinyCo-Tableau` as a custom app 
registration using `azuread_application` resource:
```hcl
resource "azuread_application" "tableau" {
  display_name = "TinyCo-Tableau"
  web {
    redirect_uris = ["https://sso.online.tableau.com/public/sp/SSO/alias/wctinycolab-33a6800945"]
  }
}
```

This creates an OIDC/OAuth app, not a SAML app.

**Error when testing SSO:**
```
AADSTS650056: Misconfigured application. The client has not listed 
any permissions for 'AAD Graph' in the requested permissions.
```

**Why it failed:**
Custom app registrations require manual API permission configuration. 
The Tableau Cloud gallery app template includes pre-configured SAML 
settings and correct permissions — custom registrations do not.

**Lesson learned:**
Always use gallery app templates for known SaaS applications. In Terraform,
use `azuread_application_template` instead of `azuread_application` for 
apps that exist in the Entra gallery.

---

## Attempt 2 — Manually Add API Permissions to Custom App

**What we tried:**
Added Microsoft Graph delegated permissions to the custom app:
- `openid`
- `profile`
- `email`
- `User.Read`

**Error:**
```
AADSTS1003031: Misconfigured required resource access in client 
application registration.
```

**Why it failed:**
The Tableau Cloud gallery app has specific pre-configured permission 
requirements that don't match a generic custom OIDC registration. 
Adding Graph permissions to a custom app doesn't satisfy Tableau's 
SAML requirements.

---

## Attempt 3 — Create Entra Gallery App for Tableau Cloud

**What we did:**
Deleted the custom app approach and created a proper Entra gallery app:

1. **Entra admin centre** → **Enterprise Applications** → 
   **New application**
2. Searched **"Tableau Cloud"**
3. Selected the official **Tableau Cloud** gallery app
4. Clicked **Create**

**Result:**
Gallery app created with SAML pre-configured as the only supported 
SSO method. ✅

**Why gallery apps are better:**
- Pre-configured SAML settings
- Correct API permissions included
- Microsoft maintains the integration
- No manual permission grants required

---

## Attempt 4 — Configure Basic SAML (With Sign On URL — Wrong)

**What we tried:**
In Entra → Tableau Cloud → Single sign-on → Basic SAML Configuration:

- **Identifier (Entity ID):** 
  `https://sso.online.tableau.com/public/sp/metadata?alias=wctinycolab-33a6800945`
- **Reply URL (ACS URL):** 
  `https://sso.online.tableau.com/public/sp/SSO/alias/wctinycolab-33a6800945`
- **Sign On URL:** `https://sso.online.tableau.com` ← **WRONG**

Downloaded Federation Metadata XML and uploaded to Tableau.

**Error:**
```
AADSTS1003031: Misconfigured required resource access
```

Also from Tableau test:
```
Remote IdP entity descriptor is not configured
```

**Why it failed:**
Two issues:
1. **Sign On URL bypasses IdP-initiated SSO** — per Tableau docs, this 
   field must be blank for IdP-initiated SSO to work
2. **Wrong order** — Entity ID and ACS URL should be copied FROM 
   Tableau's metadata, not typed manually

---

## Attempt 5 — Admin Consent Issues

**What we encountered:**
Both the "Grant admin consent" button in Enterprise Applications and 
App Registrations were greyed out.

**Why:**
Gallery apps created from the Entra gallery are pre-consented by 
Microsoft at the gallery level. The greyed-out button is expected 
behavior — it doesn't indicate a problem.

**Attempted admin consent URL:**
```
https://login.microsoftonline.com/42a9915e-aa4a-4426-9a86-a04a0dac6222/adminconsent?client_id=447cd081-0b2d-4896-a928-1ce1ee8253aa
```

This returned a different error confirming the issue was the Sign On 
URL configuration, not permissions.

---

## Resolution — Official Tableau Documentation Steps

**Source:** https://help.tableau.com/current/online/en-us/saml_config_azure_ad.htm

The official Tableau documentation revealed the two critical fixes:

### Fix 1 — Remove the Sign On URL

Per official docs:
> "If using IdP-initiated SSO for your application, do not provide a 
> Sign On URL value in the Tableau Cloud application from the gallery 
> in Entra. Providing a value for this field will bypass 
> IdP-initiated SSO."

**Action:** Removed Sign On URL from Basic SAML Configuration in Entra.

### Fix 2 — Use Tableau's Metadata Values (Not Manual Entry)

The correct order per official docs:

**Step 1 — In Tableau Cloud:**
1. Settings → Authentication → New Configuration → SAML
2. Upload Entra Federation Metadata XML
3. Scroll to **"Get Tableau Cloud metadata"** section
4. Copy the exact **Tableau Cloud Entity ID** and **ACS URL** shown

**Step 2 — In Entra:**
1. Enterprise Applications → Tableau Cloud → Single sign-on
2. Basic SAML Configuration → Edit
3. Paste the **exact** Entity ID and ACS URL from Tableau's metadata
4. Leave Sign On URL **blank**
5. Save

**Step 3 — Attribute Mapping in Tableau:**
```
Username:     http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress
Email:        http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress
First Name:   http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname
Last Name:    http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname
```

**Step 4 — Add test user in Tableau:**
1. Tableau → Users → Add Users
2. Add `WC@TinyCoDDG.onmicrosoft.com`
3. Set Authentication type to **SAML**
4. Set Role to **Site Administrator**

---

## Verification — SSO Working

**Test method:** Entra → Tableau Cloud → Single sign-on → Test → 
Sign in as current user

**Assertion mapping confirmed:**

| Tableau Attribute | Resolved Value |
|---|---|
| Username | WC@TinyCoDDG.onmicrosoft.com |
| Email address | WC@TinyCoDDG.onmicrosoft.com |
| First Name | Will |
| Last Name | Chang |

**Working SSO URL (IdP-initiated):**
```
https://sso.online.tableau.com/public/idp/SSO
```

---

## Current State

| Component | Status |
|---|---|
| Tableau Cloud account | ✅ Active |
| Entra gallery app created | ✅ |
| SAML configured in Entra | ✅ |
| Federation metadata uploaded to Tableau | ✅ |
| Attribute mapping configured | ✅ |
| Test user added with SAML auth | ✅ |
| SSO login working | ✅ |
| SCIM provisioning | ⏳ Pending |

---

## Key Lessons for Future Entra + Tableau SAML Setup

1. **Always use the Entra gallery app** — never custom OIDC for Tableau
2. **Leave Sign On URL blank** for IdP-initiated SSO
3. **Copy Entity ID and ACS URL from Tableau's metadata** — don't type 
   them manually
4. **Upload Federation Metadata XML first** — let Tableau auto-populate 
   the IdP fields
5. **Set user authentication type to SAML** in Tableau user settings
6. **Test via Entra test button** before changing default auth for all users
7. **In Terraform** — use `azuread_application_template` for gallery apps:
```hcl
data "azuread_application_template" "tableau" {
  display_name = "Tableau Cloud"
}

resource "azuread_service_principal" "tableau" {
  application_template_id = data.azuread_application_template.tableau.template_id
  use_existing            = true
}
```

---

## For DDG Submission

Tableau Cloud SSO is fully functional via Entra ID SAML. Users in the 
`TinyCo-Product` and `TinyCo-Design` groups can authenticate to Tableau 
using their `@TinyCoDDG.onmicrosoft.com` credentials.

SCIM provisioning is configured as a next step — users added to the 
Tableau-assigned groups in Entra will automatically be provisioned in 
Tableau Cloud.