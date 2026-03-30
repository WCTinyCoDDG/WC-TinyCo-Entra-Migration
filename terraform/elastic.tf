# elastic.tf
# Elastic is TinyCo's search and observability platform.
# Used for log analysis, security monitoring, and infrastructure visibility.
# Based on teams_db.csv, the following teams need Elastic access:
# ITOps, SRE, Security, Backend, Frontend, People Ops, Legal
#
# SSO + SCIM provisioning enabled.
# Users are automatically provisioned when added to assigned groups
# and deprovisioned when removed.

resource "azuread_application" "elastic" {
  display_name = "TinyCo-Elastic"

  web {
    redirect_uris = ["https://cloud.elastic.co/"]
  }

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000"

    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"
      type = "Scope"
    }
  }
}

resource "azuread_service_principal" "elastic" {
  client_id                    = azuread_application.elastic.client_id
  app_role_assignment_required = true
}

# Assign only teams that need Elastic per teams_db.csv
# ITOps, SRE, Security, Backend, Frontend, People Ops, Legal
resource "azuread_app_role_assignment" "elastic_groups" {
  for_each = {
    for k, v in azuread_group.teams :
    k => v
    if contains(["ITOps", "SRE", "Security", "Backend", "Frontend", "PeopleOps", "Legal"], k)
  }

  app_role_id         = "00000000-0000-0000-0000-000000000000"
  principal_object_id = each.value.id
  resource_object_id  = azuread_service_principal.elastic.object_id
}