# conditional-access.tf
# Defines and enforces security policies for the TinyCo tenant.
#
# Conditional Access is Entra's "if this, then that" security engine.
# Every sign-in attempt is evaluated against these policies before
# access is granted. Think of it as a security checkpoint that every
# user passes through on every login.
#
# Two policies are enforced:
# 1. Require MFA for all users — blocks 99.9% of account compromises
# 2. Block legacy authentication — closes a common attacker bypass route
#
# The break-glass account is excluded from both policies so that:
# - DDG reviewers can log in without MFA configured on their device
# - Emergency access remains available if all other admin accounts
#   are locked out
#
# IMPORTANT: Security Defaults must be disabled in Entra before
# these policies can be created. Security Defaults and custom
# Conditional Access policies cannot coexist in the same tenant.
# See 01-setup-guide.md Step 1.3 for instructions.

# ============================================================
# BREAK-GLASS ACCOUNT
# ============================================================
# A dedicated emergency and testing account that exists outside
# normal security controls. Standard enterprise practice recommended
# by Microsoft for every Entra tenant.
# Excluded from all Conditional Access policies below.

resource "azuread_user" "breakglass" {
  user_principal_name   = "admin.test@TinyCoDDG.onmicrosoft.com"
  display_name          = "TinyCo Admin (Test Account)"
  mail_nickname         = "admin.test"
  password              = var.admin_password
  force_password_change = false
  account_enabled       = true
}

# Assign Global Administrator to break-glass account
# Ensures DDG reviewer has full tenant inspection access
resource "azuread_directory_role_assignment" "breakglass_global_admin" {
  role_id             = azuread_directory_role.global_admin.template_id
  principal_object_id = azuread_user.breakglass.id
}

# ============================================================
# POLICY 1 — Require MFA for All Users
# ============================================================
# Every sign-in to the TinyCo tenant requires multi-factor
# authentication. This is the single most impactful security
# control available in Entra — Microsoft reports MFA blocks
# 99.9% of account compromise attacks.

resource "azuread_conditional_access_policy" "require_mfa" {
  display_name = "TinyCo - Require MFA for All Users"
  state        = "enabled"

  conditions {
    client_app_types = ["all"]

    applications {
      included_applications = ["All"]
    }

    users {
      included_users = ["All"]
      excluded_users = [azuread_user.breakglass.id]
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["mfa"]
  }
}

# ============================================================
# POLICY 2 — Block Legacy Authentication
# ============================================================
# Legacy protocols (IMAP, SMTP, POP3, older Office clients)
# do not support MFA — attackers exploit this to bypass modern
# security controls. Blocking legacy auth closes this attack
# vector entirely.
# Recommended by Microsoft, CIS Benchmarks, and NIST.

resource "azuread_conditional_access_policy" "block_legacy_auth" {
  display_name = "TinyCo - Block Legacy Authentication"
  state        = "enabled"

  conditions {
    client_app_types = [
      "exchangeActiveSync",
      "other"
    ]

    applications {
      included_applications = ["All"]
    }

    users {
      included_users = ["All"]
      excluded_users = [azuread_user.breakglass.id]
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["block"]
  }
}