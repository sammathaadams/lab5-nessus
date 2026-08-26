<#
    Lab 5 — Nessus Vulnerability Scanning

    MANUAL FALLBACK ONLY — as of this revision, the domain join is
    automated by the azurerm_virtual_machine_extension.ws01_domain_join
    resource in main.tf (with a retry loop and a 6-minute wait for DC01
    to finish rebooting) and runs during `terraform apply`. You should
    not need to run this script by hand.

    Use it only if that extension shows a Failed/TimedOut provisioning
    state (check with `terraform show` or `az vm extension list
    --resource-group rg-lab05-0826 --vm-name WS01 -o table`) — most often
    because DC01 needed longer than 6 minutes to fully come up.

    Because Terraform set the VNet's DNS server to DC01's private IP
    (10.0.1.4), WS01 can resolve lab.local as soon as DC01's DNS role is
    live — no manual DNS reconfiguration needed here.
#>

# Confirm WS01 can resolve the domain before attempting to join
Resolve-DnsName lab.local

$cred = Get-Credential -Message "Enter LAB\labadmin (or your domain admin) credentials"

Add-Computer -DomainName "lab.local" -Credential $cred -Restart -Force

# After reboot, confirm with:
#   (Get-CimInstance Win32_ComputerSystem).Domain
