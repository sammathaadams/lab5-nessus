# -----------------------------
# Resource Group
# -----------------------------
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# -----------------------------
# Virtual Network
# DNS is pre-pointed at DC01's static private IP (10.0.1.4) so that once
# DC01 is manually promoted to a domain controller (Section 3 of the SOP),
# every other VM in the VNet can already resolve lab.local without a
# separate "reconfigure DNS" step later.
# -----------------------------
resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = [var.vnet_cidr]
  dns_servers         = ["10.0.1.4"]
}

# Wait after VNet create (helps Azure consistency)
resource "time_sleep" "wait_after_vnet" {
  create_duration = "45s"
  depends_on      = [azurerm_virtual_network.vnet]
}

# -----------------------------
# Subnet
# -----------------------------
resource "azurerm_subnet" "subnet" {
  name                 = var.subnet_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_cidr]

  depends_on = [time_sleep.wait_after_vnet]
}

# -----------------------------
# Network Security Group — shared across DC01, UBUNTU01, WS01
# Every rule is scoped to var.allowed_source_ip (your public IP) only.
# -----------------------------
resource "azurerm_network_security_group" "nsg" {
  name                = var.nsg_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-RDP"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = var.allowed_source_ip
    source_port_range          = "*"
    destination_port_range     = "3389"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = var.allowed_source_ip
    source_port_range          = "*"
    destination_port_range     = "22"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-Nessus-SMB"
    priority                   = 1020
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = var.allowed_source_ip
    source_port_range          = "*"
    destination_port_range     = "445"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-Nessus-NetBIOS"
    priority                   = 1030
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = var.allowed_source_ip
    source_port_range          = "*"
    destination_port_range     = "139"
    destination_address_prefix = "*"
  }

  # Nessus web UI / REST API on NESSUS01. Scoped to your own IP so you can
  # browse to https://<nessus01-ip>:8834 interactively. A separate GitHub
  # Actions pipeline (.github/workflows/run-scan.yml) runs scans against
  # this already-provisioned infrastructure — it never runs terraform
  # apply/destroy itself (that stays a local, manual step; see SOP Section
  # 2), and its Azure identity is scoped to Network Contributor on just
  # this NSG, not Contributor on the subscription, so it's not capable of
  # touching a VM even if it wanted to. It opens its own SEPARATE,
  # temporary rule for the runner's IP via raw `az network nsg rule
  # create` — outside Terraform on purpose, so a CI run's rule never shows
  # up as drift here — and deletes that temp rule itself when it finishes.
  security_rule {
    name                       = "Allow-Nessus-UI"
    priority                   = 1040
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = var.allowed_source_ip
    source_port_range          = "*"
    destination_port_range     = "8834"
    destination_address_prefix = "*"
  }

  depends_on = [time_sleep.wait_after_vnet]
}

# Wait after NSG create (helps Azure consistency)
resource "time_sleep" "wait_after_nsg" {
  create_duration = "45s"
  depends_on      = [azurerm_network_security_group.nsg]
}

# -----------------------------
# Public IPs (Standard SKU, static)
# -----------------------------
resource "azurerm_public_ip" "dc01" {
  name                = "dc01-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"

  depends_on = [time_sleep.wait_after_nsg]
}

resource "azurerm_public_ip" "ubuntu01" {
  name                = "ubuntu01-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"

  depends_on = [time_sleep.wait_after_nsg]
}

resource "azurerm_public_ip" "ws01" {
  name                = "ws01-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"

  depends_on = [time_sleep.wait_after_nsg]
}

resource "azurerm_public_ip" "nessus01" {
  name                = "nessus01-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"

  depends_on = [time_sleep.wait_after_nsg]
}

# -----------------------------
# Network Interfaces
# DC01 gets a static private IP (10.0.1.4) — this is the address the VNet's
# dns_servers setting above points to, and what UBUNTU01/WS01 will use as
# their domain controller address once DC01 is promoted.
# -----------------------------
resource "azurerm_network_interface" "dc01" {
  name                = "dc01-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.4"
    public_ip_address_id          = azurerm_public_ip.dc01.id
  }

  depends_on = [time_sleep.wait_after_nsg]
}

resource "azurerm_network_interface" "ubuntu01" {
  name                = "ubuntu01-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ubuntu01.id
  }

  depends_on = [time_sleep.wait_after_nsg]
}

resource "azurerm_network_interface" "ws01" {
  name                = "ws01-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ws01.id
  }

  depends_on = [time_sleep.wait_after_nsg]
}

# Static private IP so this is always predictable within the VNet (DNS,
# internal scan traffic) regardless of what the public IP happens to be.
resource "azurerm_network_interface" "nessus01" {
  name                = "nessus01-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.10"
    public_ip_address_id          = azurerm_public_ip.nessus01.id
  }

  depends_on = [time_sleep.wait_after_nsg]
}

# -----------------------------
# Attach NSG to all three NICs
# -----------------------------
resource "azurerm_network_interface_security_group_association" "dc01" {
  network_interface_id      = azurerm_network_interface.dc01.id
  network_security_group_id = azurerm_network_security_group.nsg.id

  depends_on = [time_sleep.wait_after_nsg]
}

resource "azurerm_network_interface_security_group_association" "ubuntu01" {
  network_interface_id      = azurerm_network_interface.ubuntu01.id
  network_security_group_id = azurerm_network_security_group.nsg.id

  depends_on = [time_sleep.wait_after_nsg]
}

resource "azurerm_network_interface_security_group_association" "ws01" {
  network_interface_id      = azurerm_network_interface.ws01.id
  network_security_group_id = azurerm_network_security_group.nsg.id

  depends_on = [time_sleep.wait_after_nsg]
}

resource "azurerm_network_interface_security_group_association" "nessus01" {
  network_interface_id      = azurerm_network_interface.nessus01.id
  network_security_group_id = azurerm_network_security_group.nsg.id

  depends_on = [time_sleep.wait_after_nsg]
}

# -----------------------------
# DC01 (Windows Server 2025) — becomes the domain controller in Section 3
# -----------------------------
resource "azurerm_windows_virtual_machine" "dc01" {
  name                = "DC01"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = var.server_vm_size

  admin_username = var.admin_username
  admin_password = random_password.admin.result

  network_interface_ids = [azurerm_network_interface.dc01.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2025-datacenter-g2"
    version   = "latest"
  }

  depends_on = [time_sleep.wait_after_nsg]
}

# -----------------------------
# UBUNTU01 (Ubuntu 22.04 LTS) — plain Linux scan target, cross-platform
# credentialed scanning demo. No application installed.
# Password authentication is enabled (rather than requiring an SSH key)
# so the same admin_password variable works for Nessus's SSH credentials.
# -----------------------------
resource "azurerm_linux_virtual_machine" "ubuntu01" {
  name                = "UBUNTU01"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = var.linux_vm_size

  admin_username                 = var.admin_username
  admin_password                 = random_password.admin.result
  disable_password_authentication = false

  network_interface_ids = [azurerm_network_interface.ubuntu01.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  depends_on = [time_sleep.wait_after_nsg]
}

# -----------------------------
# WS01 (Windows 11 Pro) — domain-joined workstation (Section 4)
# -----------------------------
resource "azurerm_windows_virtual_machine" "ws01" {
  name                = "WS01"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = var.client_vm_size

  admin_username = var.admin_username
  admin_password = random_password.admin.result

  network_interface_ids = [azurerm_network_interface.ws01.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "windows-11"
    sku       = "win11-23h2-pro"
    version   = "latest"
  }

  depends_on = [time_sleep.wait_after_nsg]
}

# -----------------------------
# Enable RDP on WS01 (Windows 11 has RDP disabled by default)
# -----------------------------
resource "azurerm_virtual_machine_extension" "ws01_enable_rdp" {
  name                 = "enable-rdp"
  virtual_machine_id   = azurerm_windows_virtual_machine.ws01.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = "powershell -Command \"Set-ItemProperty -Path 'HKLM:\\System\\CurrentControlSet\\Control\\Terminal Server' -Name 'fDenyTSConnections' -Value 0; Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'\""
  })

  depends_on = [azurerm_windows_virtual_machine.ws01]
}

# -----------------------------
# NESSUS01 (Ubuntu 22.04 LTS) — the scanner itself, hosted in Azure instead
# of your local machine. This is what makes CI/CD possible: a GitHub-hosted
# Actions runner can reach this VM's public IP over HTTPS, but it could
# never reach a scanner sitting at localhost:8834 on your laptop.
#
# It also scans DC01/UBUNTU01/WS01 over their PRIVATE IPs (same VNet),
# rather than routing scan traffic out to the public internet and back in —
# tighter and more realistic than the local-scanner design.
#
# Installing and activating Nessus itself stays a one-time manual SSH step
# (see SOP Section 5) — Tenable's activation code and current-version
# download link are tied to your account and change over time, the same
# reason the original Splunk lab never hardcoded a package URL either.
# Terraform's job here is just the VM and network path; everything after
# that first manual activation is scriptable via the Nessus REST API,
# which is what the CI pipeline actually calls.
# -----------------------------
resource "azurerm_linux_virtual_machine" "nessus01" {
  name                = "NESSUS01"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = var.nessus_vm_size

  admin_username                  = var.admin_username
  admin_password                  = random_password.admin.result
  disable_password_authentication = false

  network_interface_ids = [azurerm_network_interface.nessus01.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  depends_on = [time_sleep.wait_after_nsg]
}

##############################################################################
# Automated AD DS promotion (DC01) and domain join (WS01)
#
# These run as VM extensions during `terraform apply` — no RDP session
# required. Scripts are passed as -EncodedCommand (base64/UTF-16LE) via
# textencodebase64() so multi-line PowerShell doesn't need manual quote
# escaping inside a JSON string.
#
# Secret sourcing: the password itself is generated by Terraform
# (random_password.admin in keyvault.tf) and recorded in Key Vault — no
# human ever types, sets an env var for, or carries it. That closes the
# "a person originates the secret" gap.
#
# Remaining caveat (lab-appropriate, not production-grade): the resolved
# value still gets embedded in each extension's protected_settings, and it
# still lands in Terraform state — that's true of ANY Terraform-managed
# resource with a sensitive attribute, regardless of where the value
# originated. Azure encrypts protected_settings at rest and keeps it out
# of the Activity Log, but state itself isn't encrypted by Terraform — the
# real mitigation is restricting who/what can read the remote state
# backend (the storage account in backend.tf), not the source of the
# value. A further hardening step — granting each VM a managed identity
# and having the script pull the password from Key Vault via the IMDS
# token at runtime, instead of Terraform ever passing it into
# protected_settings at all — remains a noted follow-up, not implemented
# here to keep this lab's scope focused rather than turning into an
# identity-plumbing exercise.
##############################################################################

locals {
  # Install-ADDSForest is run with -NoRebootOnCompletion so the script can
  # exit and let the extension report success BEFORE the reboot happens —
  # `shutdown /r /t 30` schedules the actual restart 30s later. Rebooting
  # synchronously inside the cmdlet's own reboot logic is what makes CSE
  # unreliable for AD promotion; this two-step version avoids that.
  dc01_promote_script = <<-EOT
    Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
    Import-Module ADDSDeployment
    $securePwd = ConvertTo-SecureString '${random_password.admin.result}' -AsPlainText -Force
    Install-ADDSForest -DomainName 'lab.local' -DomainNetbiosName 'LAB' -InstallDns:$true -SafeModeAdministratorPassword $securePwd -Force:$true -NoRebootOnCompletion:$true
    shutdown.exe /r /t 30 /c "Rebooting to complete AD DS promotion"
  EOT

  # Retries the join for up to 5 minutes (10 x 30s) in case DC01's AD DS /
  # DNS services are still finishing startup after its own reboot — a real
  # possibility since this extension is only gated by a fixed time_sleep,
  # not a live health check against DC01.
  ws01_join_script = <<-EOT
    for ($i = 0; $i -lt 10; $i++) {
      try {
        $securePwd = ConvertTo-SecureString '${random_password.admin.result}' -AsPlainText -Force
        $cred = New-Object System.Management.Automation.PSCredential('LAB\labadmin', $securePwd)
        Add-Computer -DomainName 'lab.local' -Credential $cred -Restart:$false -Force -ErrorAction Stop
        break
      } catch {
        Start-Sleep -Seconds 30
      }
    }
    shutdown.exe /r /t 30 /c "Rebooting to complete domain join"
  EOT
}

resource "azurerm_virtual_machine_extension" "dc01_promote_adds" {
  name                 = "promote-adds"
  virtual_machine_id   = azurerm_windows_virtual_machine.dc01.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  protected_settings = jsonencode({
    commandToExecute = "powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand ${textencodebase64(local.dc01_promote_script, "UTF-16LE")}"
  })

  depends_on = [azurerm_windows_virtual_machine.dc01]
}

# Fixed wait for DC01's scheduled reboot + AD DS/DNS/SYSVOL to come up.
# The extension itself only confirms the *script* finished, not that the
# domain controller is fully operational after its reboot — this gap is
# why the join script above also retries.
resource "time_sleep" "wait_for_dc01_promotion" {
  create_duration = "6m"
  depends_on       = [azurerm_virtual_machine_extension.dc01_promote_adds]
}

resource "azurerm_virtual_machine_extension" "ws01_domain_join" {
  name                 = "domain-join"
  virtual_machine_id   = azurerm_windows_virtual_machine.ws01.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  protected_settings = jsonencode({
    commandToExecute = "powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand ${textencodebase64(local.ws01_join_script, "UTF-16LE")}"
  })

  depends_on = [azurerm_virtual_machine_extension.ws01_enable_rdp, time_sleep.wait_for_dc01_promotion]
}
