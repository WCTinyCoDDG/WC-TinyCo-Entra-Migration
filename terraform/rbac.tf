# rbac.tf
# Assigns Azure and Entra roles to TinyCo security groups.
#
# Roles are assigned to GROUPS not individuals — this means:
# - When someone joins a team, they inherit the correct permissions automatically
# - When someone leaves a team, permissions are revoked automatically
# - Access is auditable at the group level — one view shows who has what
#
# Role assignments are driven by teams_db.csv which defines what
# each team is permitted to do. This file reads those requirements
# and enforces them in Azure and Entra.
#
# Two types of roles exist:
# - Entra Directory Roles: control identity management (azuread_)
# - Azure Subscription Roles: control cloud resources (azurerm_)

# ============================================================
# ENTRA DIRECTORY ROLES
# ============================================================

# Look up the Global Administrator role in Entra
# This is a built-in role — we reference it by name, not create it
resource "azuread_directory_role" "global_admin" {
  display_name = "Global Administrator"
}

# Look up the Security Reader role in Entra
resource "azuread_directory_role" "security_reader" {
  display_name = "Security Reader"
}

# --- ITOps: Global Administrator ---
# ITOps needs full control over the entire Entra tenant.
# Required to manage users, groups, apps, and security policies.
resource "azuread_directory_role_assignment" "itops_global_admin" {
  role_id             = azuread_directory_role.global_admin.template_id
  principal_object_id = azuread_group.teams["ITOps"].id
}

# --- Security: Security Reader ---
# Security team audits the tenant — read-only access to all
# security settings, sign-in logs, and audit trails.
# Read-only ensures they can investigate without risking changes.
resource "azuread_directory_role_assignment" "security_team_reader" {
  role_id             = azuread_directory_role.security_reader.template_id
  principal_object_id = azuread_group.teams["Security"].id
}

# ============================================================
# AZURE SUBSCRIPTION ROLES
# ============================================================

# --- SRE: Contributor ---
# SRE manages TinyCo's cloud infrastructure — VMs, networking,
# storage. Contributor grants full resource management without
# the ability to modify identity or security settings.
# This keeps cloud operations and identity administration separate.
resource "azurerm_role_assignment" "sre_contributor" {
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Contributor"
  principal_id         = azuread_group.teams["SRE"].id
}

# --- Backend: Reader ---
# Backend engineers need visibility into the Azure infrastructure
# their applications depend on — resource health, configuration,
# networking. Reader provides visibility without modify access.
resource "azurerm_role_assignment" "backend_reader" {
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Reader"
  principal_id         = azuread_group.teams["Backend"].id
}