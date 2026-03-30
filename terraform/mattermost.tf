# mattermost.tf
# Mattermost is TinyCo's internal messaging platform — the equivalent
# of Slack at DuckDuckGo. Every team member gets access.
#
# SSO ONLY — user provisioning is not required per project brief.
# Users log in via Entra SSO but accounts are not auto-provisioned.
# A user must exist in Mattermost before they can SSO for the first time.
#
# Groups assigned: All 9 teams (everyone gets Mattermost access)

resource "azuread_application" "mattermost" {
  display_name = "TinyCo-Mattermost"

  web {
    redirect_uris = ["https://mattermost.tinycoddg.internal/login/sso/saml"]
  }

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000"

    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"
      type = "Scope"
    }
  }
}

resource "azuread_service_principal" "mattermost" {
  client_id                    = azuread_application.mattermost.client_id
  app_role_assignment_required = true
}

# Assign all 9 team groups to Mattermost
# Everyone at TinyCo gets Mattermost access
resource "azuread_app_role_assignment" "mattermost_groups" {
  for_each = azuread_group.teams

  app_role_id         = "00000000-0000-0000-0000-000000000000"
  principal_object_id = each.value.id
  resource_object_id  = azuread_service_principal.mattermost.object_id
}