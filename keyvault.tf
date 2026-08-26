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
  purge_protection_enabled   = false

  tags = {
    Environment = "Lab"
    ManagedBy   = "Terraform"
  }
}

resource "azurerm_role_assignment" "kv_deployer_access" {
  scope                = azurerm_key_vault.lab_kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id          = data.azurerm_client_config.current.object_id
}

resource "azurerm_key_vault_secret" "admin_password" {
  name         = "vm-admin-password"
  value        = random_password.admin.result
  key_vault_id = azurerm_key_vault.lab_kv.id

  depends_on = [azurerm_role_assignment.kv_deployer_access]

  tags = {
    ManagedBy = "Terraform"
  }
}
