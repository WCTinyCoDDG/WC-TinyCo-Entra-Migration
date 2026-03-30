# main.tf
# This is the core blueprint — it describes every resource that will be
# created in Entra ID. Terraform reads this file and builds everything
# in the correct order automatically.

# ============================================================
# LOCALS — Pre-processed data
# ============================================================
# "locals" are like variables but calculated inside Terraform itself.
# Here we define all 89 employees as a map (like a spreadsheet in code).
# Each entry has a unique key, a display name, and their team.
# This is cleaner than creating 89 separate resource blocks.

locals {
  employees = {
    # ITOps
    "christone.johnson" = { display_name = "Christone Johnson", team = "ITOps" }
    "danny.carey"       = { display_name = "Danny Carey",       team = "ITOps" }
    "chester.burnett"   = { display_name = "Chester Burnett",   team = "ITOps" }
    "albert.king"       = { display_name = "Albert King",       team = "ITOps" }
    "robert.johnson"    = { display_name = "Robert Johnson",    team = "ITOps" }
    "hubert.sumlin"     = { display_name = "Hubert Sumlin",     team = "ITOps" }
    "suman.alfaro"      = { display_name = "Suman Alfaro",      team = "ITOps" }
    "alden.collnigwood" = { display_name = "Alden Collnigwood", team = "ITOps" }
    "rachele.connor"    = { display_name = "Rachele Connor",    team = "ITOps" }
    
    # Backend
    "paula.humphrey"  = { display_name = "Paula Humphrey",  team = "Backend" }
    "emmy.dillon"     = { display_name = "Emmy Dillon",     team = "Backend" }
    "haris.marquez"   = { display_name = "Haris Marquez",   team = "Backend" }
    "clark.pierce"    = { display_name = "Clark Pierce",    team = "Backend" }
    "cayden.lindsey"  = { display_name = "Cayden Lindsey",  team = "Backend" }
    "aine.cuevas"     = { display_name = "Aine Cuevas",     team = "Backend" }
    "poppy.stein"     = { display_name = "Poppy Stein",     team = "Backend" }
    "khadija.barron"  = { display_name = "Khadija Barron",  team = "Backend" }
    "fatimah.harrison"= { display_name = "Fatimah Harrison",team = "Backend" }
    "dan.york"        = { display_name = "Dan York",        team = "Backend" }

    # Design
    "zayd.watson"    = { display_name = "Zayd Watson",    team = "Design" }
    "virgil.hunt"    = { display_name = "Virgil Hunt",    team = "Design" }
    "zoya.cannon"    = { display_name = "Zoya Cannon",    team = "Design" }
    "maddie.benson"  = { display_name = "Maddie Benson",  team = "Design" }
    "bartosz.gamble" = { display_name = "Bartosz Gamble", team = "Design" }
    "nadine.leach"   = { display_name = "Nadine Leach",   team = "Design" }
    "sadia.west"     = { display_name = "Sadia West",     team = "Design" }
    "leyla.pratt"    = { display_name = "Leyla Pratt",    team = "Design" }
    "daniel.archer"  = { display_name = "Daniel Archer",  team = "Design" }
    "junaid.jarvis"  = { display_name = "Junaid Jarvis",  team = "Design" }

    # Frontend
    "jeremy.savage"   = { display_name = "Jeremy Savage",   team = "Frontend" }
    "daisie.riley"    = { display_name = "Daisie Riley",    team = "Frontend" }
    "ayesh.ballard"   = { display_name = "Ayesh Ballard",   team = "Frontend" }
    "mrytle.goodwife" = { display_name = "Mrytle Goodwife", team = "Frontend" }
    "mariam.higgins"  = { display_name = "Mariam Higgins",  team = "Frontend" }
    "steffan.dale"    = { display_name = "Steffan Dale",    team = "Frontend" }
    "elinor.reed"     = { display_name = "Elinor Reed",     team = "Frontend" }
    "lou.reed"        = { display_name = "Lou Reed",        team = "Frontend" }
    "thom.yorke"      = { display_name = "Thom Yorke",      team = "Frontend" }
    "aled.rodriguez"  = { display_name = "Aled Rodriguez",  team = "Frontend" }

    # Legal
    "marwa.morse"    = { display_name = "Marwa Morse",    team = "Legal" }
    "esha.mays"      = { display_name = "Esha Mays",      team = "Legal" }
    "muhammad.rocha" = { display_name = "Muhammad Rocha", team = "Legal" }
    "alia.warren"    = { display_name = "Alia Warren",    team = "Legal" }
    "chaya.nunez"    = { display_name = "Chaya Nunez",    team = "Legal" }
    "kyle.proctor"   = { display_name = "Kyle Proctor",   team = "Legal" }
    "musa.dyer"      = { display_name = "Musa Dyer",      team = "Legal" }
    "kiana.rowland"  = { display_name = "Kiana Rowland",  team = "Legal" }
    "edwin.solis"    = { display_name = "Edwin Solis",    team = "Legal" }
    "billie.lewis"   = { display_name = "Billie Lewis",   team = "Legal" }

    # People Ops
    "eva.brewer"        = { display_name = "Eva Brewer",        team = "PeopleOps" }
    "gail.campos"       = { display_name = "Gail Campos",       team = "PeopleOps" }
    "evangeline.schultz"= { display_name = "Evangeline Schultz",team = "PeopleOps" }
    "caleb.dickson"     = { display_name = "Caleb Dickson",     team = "PeopleOps" }
    "ffion.day"         = { display_name = "Ffion Day",         team = "PeopleOps" }
    "frances.roy"       = { display_name = "Frances Roy",       team = "PeopleOps" }
    "steffan.berg"      = { display_name = "Steffan Berg",      team = "PeopleOps" }
    "will.tanner"       = { display_name = "Will Tanner",       team = "PeopleOps" }
    "lawrence.bray"     = { display_name = "Lawrence Bray",     team = "PeopleOps" }
    "ronald.rojas"      = { display_name = "Ronald Rojas",      team = "PeopleOps" }

    # Product
    "mahnoor.terry"    = { display_name = "Mahnoor Terry",    team = "Product" }
    "frankie.lindsay"  = { display_name = "Frankie Lindsay",  team = "Product" }
    "elspeth.ayers"    = { display_name = "Elspeth Ayers",    team = "Product" }
    "tariq.baker"      = { display_name = "Tariq Baker",      team = "Product" }
    "laura.harrington" = { display_name = "Laura Harrington", team = "Product" }
    "harriett.stafford"= { display_name = "Harriett Stafford",team = "Product" }
    "matthew.burnett"  = { display_name = "Matthew Burnett",  team = "Product" }
    "izaak.olsen"      = { display_name = "Izaak Olsen",      team = "Product" }
    "keira.romero"     = { display_name = "Keira Romero",     team = "Product" }
    "bertha.herbert"   = { display_name = "Bertha Herbert",   team = "Product" }

    # Security
    "emmanuele.goldstein"= { display_name = "Emmanuele Goldstein",team = "Security" }
    "eben.etzebeth"      = { display_name = "Eben Etzebeth",      team = "Security" }
    "maria.thacker"      = { display_name = "Maria Thacker",      team = "Security" }
    "xavier.pham"        = { display_name = "Xavier Pham",        team = "Security" }
    "nora.flynn"         = { display_name = "Nora Flynn",         team = "Security" }
    "adele.house"        = { display_name = "Adele House",        team = "Security" }
    "rupert.ruiz"        = { display_name = "Rupert Ruiz",        team = "Security" }
    "agnes.duncan"       = { display_name = "Agnes Duncan",       team = "Security" }
    "ayden.fleming"      = { display_name = "Ayden Fleming",      team = "Security" }
    "deacon.hodge"       = { display_name = "Deacon Hodge",       team = "Security" }

    # SRE
    "louisa.dominguez" = { display_name = "Louisa Dominguez", team = "SRE" }
    "lawson.baird"     = { display_name = "Lawson Baird",     team = "SRE" }
    "catrin.jordan"    = { display_name = "Catrin Jordan",    team = "SRE" }
    "flora.pugh"       = { display_name = "Flora Pugh",       team = "SRE" }
    "judy.rollins"     = { display_name = "Judy Rollins",     team = "SRE" }
    "farhan.ashley"    = { display_name = "Farhan Ashley",    team = "SRE" }
    "lana.scott"       = { display_name = "Lana Scott",       team = "SRE" }
    "lia.dalton"       = { display_name = "Lia Dalton",       team = "SRE" }
    "samia.norman"     = { display_name = "Samia Norman",     team = "SRE" }
    "neil.montoya"     = { display_name = "Neil Montoya",     team = "SRE" }
  }
}

# ============================================================
# USERS — Create all 90 TinyCo accounts in Entra ID
# ============================================================
# This uses "for_each" to loop through every employee in the locals block above.
# Instead of writing 90 identical resource blocks, Terraform repeats this ONE
# block for every employee automatically. Each user gets:
# - A unique username in the format firstname.lastname@TinyCoDDG.onmicrosoft.com
# - A display name visible in Entra and all connected apps
# - A temporary password (forced to change on first login)
# - An account enabled from day one

resource "azuread_user" "employees" {
  for_each = local.employees

  user_principal_name = "${each.key}@TinyCoDDG.onmicrosoft.com"
  display_name        = each.value.display_name
  mail_nickname       = each.key
  password            = var.admin_password
  force_password_change = true
  account_enabled     = true
}

# ============================================================
# EXISTING ADMIN — Reference Will Chang's existing account
# ============================================================
# Rather than creating a new account for Will, we look up the
# existing Global Admin account that was created when the M365
# tenant was set up. This avoids duplicate identities and keeps
# the admin account as the single source of truth for ITOps.

data "azuread_user" "will_chang" {
  user_principal_name = "WC@TinyCoDDG.onmicrosoft.com"
}

# ============================================================
# GROUPS — Create 9 security groups, one per team
# ============================================================
# Security groups are the foundation of our access model.
# Instead of assigning permissions to individual users,
# we assign permissions to groups. Add a user to a group,
# they automatically inherit all that group's permissions.
# This is the least-privilege model — users only get access
# to what their team needs, nothing more.

resource "azuread_group" "teams" {
  for_each = toset([
    "ITOps",
    "SRE",
    "Security",
    "Backend",
    "Frontend",
    "Design",
    "Product",
    "PeopleOps",
    "Legal"
  ])

  display_name     = "TinyCo-${each.key}"
  security_enabled = true
  mail_enabled     = false
  assignable_to_role = true
  description      = "TinyCo ${each.key} team — access group for apps and RBAC"
}

# ============================================================
# GROUP MEMBERS — Assign each employee to their team group
# ============================================================
# This loops through all employees and adds each one to their
# correct team group. The "team" value from locals tells us
# which group each employee belongs to.
# Will Chang's existing admin account is added to ITOps
# separately at the bottom using the data lookup above.

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

# ============================================================
# RBAC — Role Based Access Control assignments
# ============================================================
# RBAC controls what each team can DO in Azure and Entra.
# We assign roles to GROUPS not individuals — this means when
# someone joins or leaves a team, you just update their group
# membership and their permissions update automatically.
#
# Role assignments follow least-privilege principle:
# - ITOps: Global Administrator — full tenant control
# - SRE: Contributor — can manage Azure resources but not identity
# - Security: Security Reader — read-only audit access
# - Backend: Reader — can view Azure resources but not change them
# - All other teams: no Azure RBAC roles (standard users)

# --- ITOps: Global Administrator ---
# Full control over the entire Entra tenant.
# Required for IT Ops to manage users, groups, apps, and policies.
resource "azuread_directory_role" "global_admin" {
  display_name = "Global Administrator"
}

resource "azuread_directory_role_assignment" "itops_global_admin" {
  role_id             = azuread_directory_role.global_admin.template_id
  principal_object_id = azuread_group.teams["ITOps"].id
}

# --- SRE: Contributor ---
# Can create and manage Azure cloud resources (VMs, networking, storage).
# Cannot manage Entra identity — keeps cloud ops separate from identity admin.
resource "azurerm_role_assignment" "sre_contributor" {
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Contributor"
  principal_id         = azuread_group.teams["SRE"].id
}

# --- Security: Security Reader ---
# Read-only access to security settings and audit logs across the tenant.
# Allows security team to audit without ability to make changes.
resource "azuread_directory_role" "security_reader" {
  display_name = "Security Reader"
}

resource "azuread_directory_role_assignment" "security_team_reader" {
  role_id             = azuread_directory_role.security_reader.template_id
  principal_object_id = azuread_group.teams["Security"].id
}

# --- Backend: Reader ---
# Read-only view of Azure cloud resources.
# Backend team can see infrastructure they depend on without modify access.
resource "azurerm_role_assignment" "backend_reader" {
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Reader"
  principal_id         = azuread_group.teams["Backend"].id
}

# ============================================================
# BREAK-GLASS ACCOUNT — Dedicated DDG reviewer/testing account
# ============================================================
# A break-glass account is an emergency/testing account that:
# - Has full admin access to inspect the entire tenant
# - Is EXCLUDED from Conditional Access policies (so DDG can
#   log in without needing MFA set up on their own device)
# - Is clearly named so reviewers know which account to use
#
# This is standard enterprise practice — every well-managed
# tenant has at least one break-glass account for emergency
# access and external audits.

resource "azuread_user" "breakglass" {
  user_principal_name = "admin.test@TinyCoDDG.onmicrosoft.com"
  display_name        = "TinyCo Admin (Test Account)"
  mail_nickname       = "admin.test"
  password            = var.admin_password
  force_password_change = false
  account_enabled     = true
}

# Assign Global Administrator role to the break-glass account
resource "azuread_directory_role_assignment" "breakglass_global_admin" {
  role_id             = azuread_directory_role.global_admin.template_id
  principal_object_id = azuread_user.breakglass.id
}

# ============================================================
# CONDITIONAL ACCESS — Security policies for the tenant
# ============================================================
# Conditional Access is Entra's "if this, then that" security engine.
# It evaluates every login attempt and decides whether to allow,
# block, or challenge it based on conditions you define.
#
# We create two policies:
# 1. Require MFA for all users (security baseline)
# 2. Block legacy authentication protocols (common attack vector)
#
# The break-glass account is explicitly excluded from both policies
# so DDG reviewers can log in without MFA configured on their device.

# --- Policy 1: Require MFA for all users ---
# Every sign-in to the TinyCo tenant requires multi-factor authentication.
# This is the single most impactful security control available in Entra —
# Microsoft reports MFA blocks 99.9% of account compromise attacks.
# The break-glass account is excluded so reviewers can access the tenant.

resource "azuread_conditional_access_policy" "require_mfa" {
  display_name = "TinyCo - Require MFA for All Users"
  state        = "enabled"

  conditions {
    client_app_types = ["all"]

    applications {
      included_applications = ["All"]
    }

    users {
      included_users  = ["All"]
      excluded_users  = [azuread_user.breakglass.id]
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["mfa"]
  }
}

# --- Policy 2: Block Legacy Authentication ---
# Legacy protocols (IMAP, SMTP, POP3, older Office clients) do not
# support MFA — attackers exploit this to bypass modern security controls.
# Blocking legacy auth is a critical baseline recommended by Microsoft
# and required by most security frameworks (CIS, NIST, SOC2).
# The break-glass account is excluded as a precaution.

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