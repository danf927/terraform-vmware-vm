# LINUX-PROD.TFVARS
# =================================================
# Deployment spec: Linux Production ("Linux-Production" customization spec, "Linux-GOLD"
# template). Fill in the per-deployment values marked SET_FROM_SCRIPT below for each
# new build ticket. Spec-level values (timezone, hw clock, etc.) should already match
# the vCenter spec - only update them here if the spec itself changes.
#
# PREREQUISITES:
# Requires TF_VAR_vsphere_user / TF_VAR_vsphere_password set as environment
# variables - see the Provider / Connection section below.
#
# USAGE:  terraform apply -var-file="linux-prod.tfvars"
# =================================================
# Author:  Dan Fereday
# Date Last Modified: 09/10/2026

# --- Provider / Connection ---

vsphere_server = "vsphere.example.com"

# vsphere_user / vsphere_password (sensitive) - supply via environment variable instead:
# $env:TF_VAR_vsphere_user="your-username@example.com"
# $env:TF_VAR_vsphere_password="your-password-goes-here"

vsphere_allow_unverified_ssl = false

# --- Placement ---

datacenter = "Primary-DC"

# vsphere_folder: the folder in vsphere where the VM will land
vsphere_folder = "SET_FROM_SCRIPT_vsphere_folder"

# target_cluster: must be one of Cluster-General, Cluster-Production, Cluster-Development, Cluster-Analytics, Cluster-Database
target_cluster = "Cluster-Production"

# target_datastore_cluster: must be one of Datastore-Analytics, Datastore-General, Datastore-Development, Datastore-Database, Datastore-Linux
target_datastore_cluster = "Datastore-Linux"

# target_virtual_port_group: Production network for this spec
target_virtual_port_group = "Network-Production"

# --- Template / Customization (spec-level, do not change per deployment) ---

vm_template      = "Linux-GOLD"
vm_customization = "Linux-Production"

# --- Linux customization spec settings ---
# Sourced from: Get-OSCustomizationSpec -Name "Linux-Production" | Select-Object *
vm_linux_timezone = null # blank in spec, will use template default
vm_hw_clock_utc   = true

# --- VM Identity / Sizing (per-deployment - update for each build ticket) ---

# vm_name: 15 characters or less
vm_name = "SET_FROM_SCRIPT_vm_name"

vm_cpus = 0
vm_ram  = 0

# vm_main_disk: root disk size in GB (number) - leave as null to default to template size
vm_main_disk = null

# additional_disks: list of extra disks, e.g.
# additional_disks = [
#   { size_gb = 100, label = "disk1" },
#   { size_gb = 50,  label = "disk2" }
# ]
# SET_FROM_SCRIPT: additional_disks - comment out if no extra disks needed
# additional_disks = [
#   { size_gb = 100, label = "disk1" },
#   { size_gb = 50,  label = "disk2" }
# ]
additional_disks = []

# --- Networking (per-deployment) ---

vm_ip_address  = "SET_FROM_SCRIPT_vm_ip_address"
vm_subnet_mask = 20
vm_default_gw  = "SET_FROM_SCRIPT_vm_default_gw"
vm_dns_server  = "SET_FROM_SCRIPT_vm_dns_server"

# --- Notes / Metadata (per-deployment) ---

ticket_id  = "SET_FROM_SCRIPT_ticket_id"
owner_dept = "SET_FROM_SCRIPT_owner_dept"
vm_notes   = "SET_FROM_SCRIPT_vm_notes"
