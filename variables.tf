variable "location" {
  description = "Azure region."
  type        = string
  default     = "West US 2"
}

variable "resource_group_name" {
  description = "Resource Group name for all Lab 5 resources."
  type        = string
  default     = "rg-lab05-0826"
}

variable "vnet_name" {
  description = "Virtual Network name."
  type        = string
  default     = "lab5-nessus-vnet"
}

variable "subnet_name" {
  description = "Subnet name."
  type        = string
  default     = "lab5-subnet"
}

variable "vnet_cidr" {
  description = "Virtual Network CIDR."
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "Subnet CIDR."
  type        = string
  default     = "10.0.1.0/24"
}

variable "nsg_name" {
  description = "Network Security Group name — shared across all three VMs."
  type        = string
  default     = "lab5-nsg"
}

variable "allowed_source_ip" {
  description = "Your public IP in CIDR form (e.g. 203.0.113.5/32). Every NSG rule is scoped to this — never widen to * / Internet. Nessus scan traffic and RDP/SSH both originate from here."
  type        = string
}

variable "admin_username" {
  description = "Local administrator / SSH username on all three VMs."
  type        = string
  default     = "labadmin"
}

variable "server_vm_size" {
  description = "VM size for DC01."
  type        = string
  default     = "Standard_D2s_v3"
}

variable "linux_vm_size" {
  description = "VM size for UBUNTU01."
  type        = string
  default     = "Standard_D2s_v3"
}

variable "client_vm_size" {
  description = "VM size for WS01."
  type        = string
  default     = "Standard_D2s_v3"
}

variable "nessus_vm_size" {
  description = "VM size for NESSUS01. Tenable recommends 4GB+ RAM minimum for Nessus — Standard_D2s_v3 provides exactly that; bump to Standard_D2ms (8GB) if scans feel slow."
  type        = string
  default     = "Standard_D2s_v3"
}
