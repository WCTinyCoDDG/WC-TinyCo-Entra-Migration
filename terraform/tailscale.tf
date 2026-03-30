# apps.tf
# This file registers all TinyCo applications in Entra ID as Enterprise Apps.
# Each app gets a service principal — the identity Entra uses to communicate
# with the app for SSO and provisioning.
#
# IMPORTANT: Terraform builds the ENTRA SIDE only.
# SSO URLs, certificates, and SCIM tokens are configured in each
# app's own admin portal during Tech Days 2 and 3.

# ============================================================
# TAILSCALE — SSO + SCIM Provisioning
# ============================================================
# Tailscale is our VPN solution. Every TinyCo team member gets
# Tailscale access via group assignment. SCIM ensures users are
# automatically provisioned/deprovisioned as team membership changes.
# Groups assigned: All 9 teams (everyone gets VPN access)

resource "azuread_application" "tailscale" {
  display_name = "TinyCo-Tailscale"

  web {
    redirect_uris = ["https://login.tailscale.com/a/oauth_response"]
  }

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000"

    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"
      type = "Scope"
    }
  }
}

resource "azuread_service_principal" "tailscale" {
  client_id                    = azuread_application.tailscale.client_id
  app_role_assignment_required = true
}

# Assign all 9 team groups to Tailscale
# Everyone at TinyCo gets VPN access regardless of team
resource "azuread_app_role_assignment" "tailscale_groups" {
  for_each = azuread_group.teams

  app_role_id         = "00000000-0000-0000-0000-000000000000"
  principal_object_id = each.value.id
  resource_object_id  = azuread_service_principal.tailscale.object_id
}