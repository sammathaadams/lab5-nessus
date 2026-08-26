output "dc01_public_ip" {
  description = "Public IP for DC01 (RDP + Nessus scan target)."
  value       = azurerm_public_ip.dc01.ip_address
}

output "dc01_private_ip" {
  description = "Private IP for DC01 — also the VNet's DNS server once AD DS is promoted."
  value       = azurerm_network_interface.dc01.private_ip_address
}

output "ubuntu01_public_ip" {
  description = "Public IP for UBUNTU01 (SSH + Nessus scan target)."
  value       = azurerm_public_ip.ubuntu01.ip_address
}

output "ws01_public_ip" {
  description = "Public IP for WS01 (RDP + Nessus scan target)."
  value       = azurerm_public_ip.ws01.ip_address
}

output "ws01_private_ip" {
  description = "Private IP for WS01 — this is what NESSUS01 actually scans, not the public IP."
  value       = azurerm_network_interface.ws01.private_ip_address
}

output "ubuntu01_private_ip" {
  description = "Private IP for UBUNTU01 — this is what NESSUS01 actually scans, not the public IP."
  value       = azurerm_network_interface.ubuntu01.private_ip_address
}

output "nessus01_public_ip" {
  description = "Public IP for NESSUS01 — browse to https://<this>:8834 to activate and configure scans. Copy this value into the NESSUS01_IP GitHub repo Variable if you set up the scan pipeline (SOP Section 13) — the pipeline reads it as a Variable, not live from this output."
  value       = azurerm_public_ip.nessus01.ip_address
}

output "nessus01_private_ip" {
  description = "Private IP for NESSUS01 (always 10.0.1.10) — used for the scan target list, not by the CI pipeline (which talks to the public IP from outside the VNet)."
  value       = azurerm_network_interface.nessus01.private_ip_address
}

output "key_vault_name" {
  description = "Name of the Azure Key Vault holding the shared admin password."
  value       = azurerm_key_vault.lab_kv.name
}

output "resource_group_name" {
  description = "Resource group name. Copy this into the RESOURCE_GROUP GitHub repo Variable if you set up the scan pipeline (SOP Section 13) — it's a one-time manual copy, not read live, so the pipeline's Azure identity never needs access to this state."
  value       = azurerm_resource_group.rg.name
}

output "nsg_name" {
  description = "NSG name. Copy this into the NSG_NAME GitHub repo Variable if you set up the scan pipeline (SOP Section 13), which uses it to open/close its temporary rule."
  value       = azurerm_network_security_group.nsg.name
}
