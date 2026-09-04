##############################################################################
# keyvault.tf
#
# Purpose : Key Vault is the SOURCE of the shared admin password, not just a
#           backup copy of one you typed. `random_password.admin` generates
#           a strong password at apply time — no human ever picks, types,
#           or carries it (no TF_VAR_admin_password, no tfvars entry, no
#           shell history). Every VM/extension that needs it in main.tf
#           references `random_password.admin.result` directly. If you ever
#           need to RDP/SSH in by hand, retrieve the current value with:
#             az keyvault secret show --vault-name <kv-name> --name vm-admin-password --query value -o tsv
#           (Caveat, same as before: the resolved value still lands in
#           Terraform state, same as any Terraform-managed resource
#           attribute — that's a state-backend-access problem, not
#           something Key Vault itself removes. See SOP Notes.)
#
# Access  : Uses Azure RBAC (not legacy access policies).
##############################################################################

data "azurerm_client_config" "current" {}

# Generated once per apply — nobody types this, nobody needs to know it
# until they retrieve it from Key Vault after the fact.
resource "random_password" "admin" {
  length      = 20
  special     = true
  min_upper   = 2
  min_lower   = 2
  min_numeric = 2
  min_special = 2
  # Azure VM local-admin passwords reject a handful of characters
  # (backslash, quotes) that random_password could otherwise generate.
  override_special = "!@#$%^&*()-_=+[]{}"
}

# Key Vault names must be globally unique across all of Azure (3-24 chars).
resource "random_id" "kv_suffix" {
  byte_length = 4
}

resource "azurerm_key_vault" "lab_kv" {
  name                = "kv-lab5-${random_id.kv_suffix.hex}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  soft_delete_retention_days = 7

  # tfsec: azure-keyvault-no-purge — deliberately NOT enabled. Purge
  # protection is a one-way switch in Azure: once on, it can never be
  # turned off, and a purged/deleted vault name stays reserved for up to
  # 90 days. This lab gets destroyed and redeployed repeatedly during
  # normal use — enabling this would mean every teardown risks blocking
  # the next `terraform apply` from reusing the same Key Vault name for
  # up to 90 days. Accepted risk for a lab environment; would flip this
  # to true for anything long-lived or production.
  #tfsec:ignore:azure-keyvault-no-purge
  purge_protection_enabled = false

  # tfsec: azure-keyvault-specify-network-acl — fixed, not suppressed.
  # Without this block, the vault's data plane (secrets) is reachable
  # from any network as long as the caller has valid Azure AD RBAC —
  # this adds a second layer scoped to the same IP already trusted
  # everywhere else in this lab (main.tf's NSG rules use the same
  # variable). default_action = Deny means only that IP (or trusted
  # first-party Azure services) can reach it at all, regardless of RBAC.
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    ip_rules       = [var.allowed_source_ip]
  }

  tags = {
    Environment = "Lab"
    ManagedBy   = "Terraform"
  }
}

resource "azurerm_role_assignment" "kv_deployer_access" {
  scope                = azurerm_key_vault.lab_kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Stable, one-time-computed expiry for the secret below. Deliberately NOT
# using timestamp()+offset inline — timestamp() re-evaluates on every
# plan, which would show a spurious "changed" diff on every single
# `terraform plan` even though nothing actually changed. time_offset is a
# real managed resource: it computes its value once, at creation, and
# only changes if offset_days itself changes.
resource "time_offset" "secret_expiry" {
  offset_days = 90
}

resource "azurerm_key_vault_secret" "admin_password" {
  name         = "vm-admin-password"
  value        = random_password.admin.result
  key_vault_id = azurerm_key_vault.lab_kv.id

  # tfsec: azure-keyvault-content-type-for-secret — fixed. Purely
  # descriptive metadata, no functional effect.
  content_type = "text/plain"

  # tfsec: azure-keyvault-ensure-secret-expiry — fixed. 90 days from
  # whenever this secret was actually created (see time_offset above),
  # not a hardcoded date that would become meaningless over time.
  expiration_date = time_offset.secret_expiry.rfc3339

  depends_on = [azurerm_role_assignment.kv_deployer_access]

  tags = {
    ManagedBy = "Terraform"
  }
}
