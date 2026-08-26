<#
    Lab 5 — Nessus Vulnerability Scanning
    Prep all three targets for credentialed scanning, run AFTER DC01 is
    promoted and WS01 is domain-joined (scripts 04 and 05).

    Windows targets (DC01, WS01) — run this block on EACH via RDP:
#>

Set-Service -Name RemoteRegistry -StartupType Automatic
Start-Service RemoteRegistry
Get-Service RemoteRegistry | Select-Object Name, Status, StartType

netsh advfirewall firewall add rule name='Nessus' dir=in action=allow protocol=tcp localport=445

Write-Host "Windows target prepped for credentialed scanning." -ForegroundColor Green

<#
    Linux target (UBUNTU01) — run this over SSH instead, it's a bash
    snippet, not PowerShell. Nessus's SSH credentialed scan just needs a
    working SSH login; no extra service needs enabling on a stock Ubuntu
    22.04 image as long as password auth is on (Terraform already set
    disable_password_authentication = false).

        ssh labadmin@<UBUNTU01_PUBLIC_IP>
        sudo apt update && sudo apt list --upgradable   # sanity check before scanning

    Confirm the Azure NSG rule "Allow-SSH" (see main.tf) covers your
    current public IP before scanning UBUNTU01.
#>
