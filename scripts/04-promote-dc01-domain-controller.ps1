<#
    Lab 5 — Nessus Vulnerability Scanning

    MANUAL FALLBACK ONLY — as of this revision, AD DS promotion is
    automated by the azurerm_virtual_machine_extension.dc01_promote_adds
    resource in main.tf and runs during `terraform apply`. You should not
    need to run this script by hand.

    Use it only if that extension shows a Failed/TimedOut provisioning
    state (check with `terraform show` or `az vm extension list
    --resource-group rg-lab05-0826 --vm-name DC01 -o table`) and you need
    to complete the promotion manually via RDP instead.

    Promotes DC01 to a real Active Directory domain controller for
    lab.local. Takes 10-15 minutes and ends with an automatic reboot.
#>

Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

Import-Module ADDSDeployment

$SafeModePassword = Read-Host -Prompt "Enter a Directory Services Restore Mode (DSRM) password" -AsSecureString

Install-ADDSForest `
  -DomainName "lab.local" `
  -DomainNetbiosName "LAB" `
  -InstallDns:$true `
  -SafeModeAdministratorPassword $SafeModePassword `
  -Force:$true

# The server reboots automatically to complete promotion.
# After reboot, confirm with:
#   Get-ADDomain
#   Get-Service DNS
