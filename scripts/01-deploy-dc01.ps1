<#
    Lab 5 — Nessus Vulnerability Scanning

    NOTE: Infrastructure deployment moved to Terraform.

    DC01, UBUNTU01, WS01, and NESSUS01 — along with the VNet, NSG, public IPs,
    and the Key Vault holding the admin password — are now defined in the
    repo root:
        main.tf                    resource group, network, NSG, all 4 VMs
        variables.tf                inputs
        terraform.tfvars.example    template — copy to terraform.tfvars, set allowed_source_ip
        backend.tf                  remote state config (Azure Blob Storage)
        keyvault.tf                 stores the admin password securely
        outputs.tf                  prints public/private IPs after apply

    To deploy:
        cp terraform.tfvars.example terraform.tfvars
        # edit terraform.tfvars — set allowed_source_ip to your own IP

        terraform init
        terraform plan
        terraform apply

    Note: there's no password to set beforehand. Terraform generates the
    VM admin/SSH password itself and stores it in Key Vault — retrieve it
    afterward with:
        az keyvault secret show --vault-name <kv-name> --name vm-admin-password --query value -o tsv

    See SOP_Lab5_Nessus_Vulnerability_Scanning.md Section 2 for the full
    walkthrough, including the one-time remote state backend bootstrap.
#>
