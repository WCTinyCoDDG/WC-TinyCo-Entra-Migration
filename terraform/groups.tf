# groups.tf
# Creates one Entra security group per team and assigns
# each employee to their correct team group.
#
# Team names are derived dynamically from the employees.csv file —
# no team names are hardcoded in this file. Adding a new team
# is as simple as adding employees with that team name to the CSV.
#
# Group naming convention: TinyCo-[TeamName]
# Example: TinyCo-ITOps, TinyCo-Backend, TinyCo-SRE

locals {
  # Extract all unique team names from the employees CSV
  # This means we never hardcode team names — they come from the data
  teams = toset([
    for emp in local.employees_raw : emp.team
  ])
}

# Create one security group per unique team found in employees.csv
resource "azuread_group" "teams" {
  for_each = local.teams

  display_name       = "TinyCo-${each.key}"
  security_enabled   = true
  mail_enabled       = false
  assignable_to_role = true
  description        = "TinyCo ${each.key} team — access group for apps and RBAC"
}

# Assign each employee to their team group
# The team value in the CSV determines which group they join
resource "azuread_group_member" "employee_membership" {
  for_each = local.employees

  group_object_id  = azuread_group.teams[each.value.team].id
  member_object_id = azuread_user.employees[each.key].id
}

# Add Will Chang's existing admin account to ITOps group
resource "azuread_group_member" "will_chang_itops" {
  group_object_id  = azuread_group.teams["ITOps"].id
  member_object_id = data.azuread_user.will_chang.id
}