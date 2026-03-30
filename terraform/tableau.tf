# tableau.tf
# Tableau is TinyCo's data visualization and business intelligence platform.
# Only specific teams need Tableau access based on teams_db.csv:
# ITOps, SRE, and Product teams are assigned.
#
# SSO + SCIM provisioning enabled.
# Users are automatically provisioned when added to assigned groups
# and deprovisioned when removed — no manual Tableau account management.

resource "azuread_application" "tableau" {
  display_name = "TinyCo-Tableau"

  web {
    redirect_uris = ["https://sso.online.tableau.com/public/sp/metadata"]
  }

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000"

    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"
      type = "Scope"
    }
  }
}

resource "azuread_service_principal" "tableau" {
  client_id                    = azuread_application.tableau.client_id
  app_role_assignment_required = true
}

# Assign only teams that need Tableau per teams_db.csv
# ITOps, SRE, Product
resource "azuread_app_role_assignment" "tableau_groups" {
  for_each = {
    for k, v in azuread_group.teams :
    k => v
    if contains(["ITOps", "SRE", "Product"], k)
  }

  app_role_id         = "00000000-0000-0000-0000-000000000000"
  principal_object_id = each.value.id
  resource_object_id  = azuread_service_principal.tableau.object_id
}