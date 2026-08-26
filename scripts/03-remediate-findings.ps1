<#
    Lab 5 — Nessus Vulnerability Scanning
    Run this ON DC01 or WS01 (via RDP) to remediate a chosen Windows finding
    from the credentialed scan. Comment out any blocks that don't apply to
    the specific finding you picked — running all three is fine too, but the
    lab only asks you to remediate and verify one.

    After running, re-launch the credentialed scan in Nessus and confirm
    the finding no longer appears (see README Step 8 / SOP Section 8).
#>

# --- Option 1: Install pending Windows updates ---
# Addresses missing-patch findings — usually the largest bucket of findings
# on a freshly deployed VM image.
Install-Module PSWindowsUpdate -Force
Get-WindowsUpdate -Install -AcceptAll

# --- Option 2: Disable TLS 1.0 and 1.1 ---
# Common Medium/High finding — outdated TLS versions are considered
# cryptographically weak and are frequently flagged by compliance scans.
New-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server' -Force
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server' -Name 'Enabled' -Value 0 -PropertyType DWORD -Force

New-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server' -Force
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server' -Name 'Enabled' -Value 0 -PropertyType DWORD -Force

# --- Option 3: Disable SMBv1 ---
# SMBv1 is deprecated and vulnerable to exploits like EternalBlue —
# one of the most frequently flagged findings by Nessus on Windows Server.
Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force

Write-Host "Remediation applied. Re-run the credentialed scan in Nessus to verify." -ForegroundColor Green

<#
    --- Optional: Linux finding on UBUNTU01 ---
    Run this bash snippet over SSH instead if you'd rather remediate and
    verify a finding on the Linux target — a nice cross-platform pair with
    the Windows remediation above for the portfolio writeup.

        ssh labadmin@<UBUNTU01_PUBLIC_IP>
        sudo apt update && sudo apt upgrade -y      # clears most missing-patch findings
        sudo reboot                                  # if a kernel update was applied
#>

