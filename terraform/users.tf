# users.tf
# Creates all TinyCo employee accounts in Entra ID by reading
# directly from the employees.csv file in the data/ folder.
#
# This approach means:
# - No employee names are hardcoded in version-controlled code
# - Adding a new employee = add a row to employees.csv, run terraform apply
# - Removing an employee = delete their row, run terraform apply
# - The CSV acts as our stand-in for an HR system like ADP
#
# In production, this CSV would be replaced by a direct SCIM feed
# from the HR system — the Terraform code itself would require
# minimal modification to support that upgrade.

locals {
  # Read the CSV file and decode it into a list of employee objects
  # Each row becomes: { first_name, last_name, team }
  employees_raw = csvdecode(file("${path.module}/../data/employees.csv"))

  # Transform the list into a map keyed by "firstname.lastname"
  # This format is required by for_each and becomes the username prefix
  employees = {
    for emp in local.employees_raw :
    "${lower(emp.first_name)}.${lower(emp.last_name)}" => emp
  }
}

# Create one Entra user account per employee in the CSV
resource "azuread_user" "employees" {
  for_each = local.employees

  # Username format: firstname.lastname@TinyCoDDG.onmicrosoft.com
  user_principal_name = "${each.key}@TinyCoDDG.onmicrosoft.com"
  display_name        = "${each.value.first_name} ${each.value.last_name}"
  mail_nickname       = each.key
  password            = var.admin_password
  force_password_change = true
  account_enabled     = true
}

# Reference Will Chang's existing Global Admin account
# rather than creating a duplicate identity
data "azuread_user" "will_chang" {
  user_principal_name = "WC@TinyCoDDG.onmicrosoft.com"
}