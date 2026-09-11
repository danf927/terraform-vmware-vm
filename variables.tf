# VMWARE VM DEPLOYMENT MODULE - VARIABLES
# =================================================
# Declares all input variables for the vmware-vm module: connection, placement,
# sizing, networking, and OS customization (Windows and Linux) settings.
#
# USAGE:  Supply values via a spec-specific tfvars file (windows-2025.tfvars,
# linux-dev.tfvars, linux-prod.tfvars, linux-staging.tfvars).
# =================================================
# Author:  Dan Fereday
# Date Last Modified: 09/10/2026

# --- Provider / Connection ---

variable "vsphere_server" {
  description = "vsphere server to build a VM on (e.g. vsphere.example.com)"
  type        = string
  default     = "vsphere.example.com"

}

variable "vsphere_allow_unverified_ssl" {
  description = "Whether or not unverified SSL will be allowed - default is not allowed (false)"
  type        = bool
  default     = false
}

variable "vsphere_folder" {
  description = "The folder in vsphere where the VM will land"
  type        = string
}

# --- Credentials & Authentication ---

variable "vsphere_user" {
  description = "The username you will use to deploy the VM into vsphere - sensitive."
  type        = string
  sensitive   = true
}

variable "vsphere_password" {
  description = "The password for the account used to deploy the VM into vsphere - sensitive."
  type        = string
  sensitive   = true
}

variable "vm_admin_password" {
  description = "Local administrator password for Windows guest customization (sensitive) - copy from the vCenter spec, or supply via TF_VAR_vm_admin_password"
  type        = string
  sensitive   = true
  default     = null
}

variable "vm_domain_user" {
  description = "Domain account (with rights to join computers) used for Windows domain join during sysprep - sensitive. Leave null to skip domain join."
  type        = string
  sensitive   = true
  default     = null
}

variable "vm_domain_password" {
  description = "Password for vm_domain_user - sensitive. Supply via TF_VAR_vm_domain_password."
  type        = string
  sensitive   = true
  default     = null
}

# --- Placement ---

variable "datacenter" {
  description = "The name of the VMWare datacenter (e.g. Primary-DC)"
  type        = string
  default     = "Primary-DC"
}

variable "target_cluster" {
  description = "Target VMWare cluster where the VM will land"
  type        = string

  validation {
    condition     = contains(["Cluster-General", "Cluster-Production", "Cluster-Development", "Cluster-Analytics", "Cluster-Database"], var.target_cluster)
    error_message = "Invalid cluster name specified.  Must be:  Cluster-General, Cluster-Production, Cluster-Development, Cluster-Analytics, or Cluster-Database"
  }
}

variable "target_datastore_cluster" {
  description = "Target VMWare datastore cluster where the VM will land"
  type        = string

  validation {
    condition     = contains(["Datastore-Analytics", "Datastore-General", "Datastore-Development", "Datastore-Database", "Datastore-Linux"], var.target_datastore_cluster)
    error_message = "Invalid datastore cluster name specified.  Must be:  Datastore-Analytics, Datastore-General, Datastore-Development, Datastore-Database, Datastore-Linux"
  }
}

variable "target_virtual_port_group" {
  description = "The virtual network the VM will be connected to (vxlan dev, prod, or cert, DHCP subnet)"
  type        = string

  validation {
    condition     = contains(["Network-Production", "Network-Development", "Network-Staging", "Network-Management"], var.target_virtual_port_group)
    error_message = "Invalid Virtual Port Group specified.  Must be:  Network-Production, Network-Development, Network-Staging, Network-Management"
  }
}

# --- Template / Customization ---

variable "vm_template" {
  description = "VM Template to be used for the deployment (Linux-GOLD, Windows-2025-GOLD)"
  type        = string

  validation {
    condition     = contains(["Linux-GOLD", "Windows-2025-GOLD"], var.vm_template)
    error_message = "Invalid VM template designated.  Must be:  Linux-GOLD, Windows-2025-GOLD"
  }
}

variable "vm_customization" {
  description = "OS Customization Spec from VMWare that will be used to customize the VM (Windows:  Windows-2025, Linux:  Linux-Dev, Linux-Production, or Linux-Staging)"
  type        = string

  validation {
    condition     = contains(["Windows-2025", "Linux-Production", "Linux-Staging", "Linux-Dev"], var.vm_customization)
    error_message = "Invalid OS Customization Spec designated.  Must be:  Windows-2025, Linux-Dev, Linux-Production, or Linux-Staging"
  }
}

# --- OS Customization Spec settings (Windows) ---
# Copy these from the actual vCenter customization spec (Get-OSCustomizationSpec in PowerCLI)
# so the deployed VM matches the spec exactly. Only used when vm_customization resolves to a Windows spec.

variable "vm_full_name" {
  description = "Full name field for Windows guest customization - copy from the vCenter spec's FullName property"
  type        = string
  default     = null
}

variable "vm_org_name" {
  description = "Organization name field for Windows guest customization - copy from the vCenter spec's OrgName property"
  type        = string
  default     = null
}

variable "vm_windows_timezone" {
  description = "Windows timezone code for guest customization - copy from the vCenter spec's TimeZone property"
  type        = number
  default     = null
}

variable "vm_auto_logon_count" {
  description = "Number of automatic logons after Windows sysprep - copy from the vCenter spec's AutoLogonCount property"
  type        = number
  default     = 1
}

# --- OS Customization Spec settings (Linux) ---
# Copy these from the actual vCenter customization spec so the deployed VM matches the spec exactly.
# Only used when vm_customization resolves to a Linux spec.

variable "vm_linux_timezone" {
  description = "Linux timezone identifier for guest customization (e.g. America/Denver) - copy from the vCenter spec"
  type        = string
  default     = null
}

variable "vm_hw_clock_utc" {
  description = "Whether the Linux hardware clock is set to UTC - copy from the vCenter spec"
  type        = bool
  default     = true
}

# --- VM Identity / Sizing ---

variable "vm_name" {
  description = "The name of the VM that will be created - must be 15 characters or less."
  type        = string

  validation {
    condition     = length(var.vm_name) <= 15
    error_message = "VM name provided exceeds the character limit.  Must be:  15 characters or less"
  }
}

variable "vm_cpus" {
  description = "The number of virtual CPU cores the VM will be assigned"
  type        = number
}

variable "vm_ram" {
  description = "The amount of memory (in GB) the VM will be assigned"
  type        = number
}

variable "vm_main_disk" {
  description = "The size of the VM's C/Root disk in GB (defaults to template size if not specified)"
  type        = number
  default     = null
}

variable "additional_disks" {
  description = "List of additional disks to add to the VM (separate from the main OS disk)"
  type = list(object({
    size_gb = number
    label   = string
  }))
  default = []
}

# --- Networking ---

variable "vm_ip_address" {
  description = "IPv4 address for the VM"
  type        = string
}

variable "vm_subnet_mask" {
  description = "Subnet mask for the VM, expressed as CIDR prefix length in bits (e.g. 20 for 255.255.240.0)"
  type        = number
  default     = 20

}

variable "vm_default_gw" {
  description = "Default gateway for the VM"
  type        = string
}

variable "vm_dns_server" {
  description = "DNS server IP"
  type        = string
  default     = "10.0.0.10"
}

variable "vm_domain" {
  description = "DNS domain to assign the VM during guest customization"
  type        = string
  default     = "example.com"
}

# --- Metadata ---

variable "ticket_id" {
  description = "Ticket ID associated with the server build request"
  type        = string
}

variable "owner_dept" {
  description = "Department that will own the server"
  type        = string
}

variable "vm_notes" {
  description = "The function/purpose field from the build ticket"
  type        = string
}
