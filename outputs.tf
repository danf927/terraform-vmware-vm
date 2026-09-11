# VMWARE VM DEPLOYMENT MODULE - OUTPUTS
# =================================================
# Defines output values exposed by the module for use in other configurations,
# integrations with configuration management tools, and infrastructure tracking.
#
# These outputs enable downstream Terraform modules, Ansible playbooks,
# monitoring systems, and CMDB tools to reference and operate on deployed VMs.
# =================================================
# Author:  Dan Fereday
# Date Last Modified: 09/10/2026

# --- VM Identity ---

output "vm_id" {
  value       = vsphere_virtual_machine.vm.id
  description = "vSphere unique identifier (UUID) of the deployed VM"
}

output "vm_name" {
  value       = vsphere_virtual_machine.vm.name
  description = "Name of the deployed VM"
}

output "vm_fqdn" {
  value       = "${vsphere_virtual_machine.vm.name}.${var.vm_domain}"
  description = "Fully qualified domain name of the VM"
}

# --- Network Configuration ---

output "vm_ip_address" {
  value       = var.vm_ip_address
  description = "IPv4 address assigned to the VM"
}

output "vm_gateway" {
  value       = var.vm_default_gw
  description = "Default gateway for the VM"
}

output "vm_subnet_mask" {
  value       = var.vm_subnet_mask
  description = "Subnet mask in CIDR notation (e.g., 24 for /24)"
}

output "vm_subnet_mask_dotted" {
  value       = cidrhost("${var.vm_ip_address}/${var.vm_subnet_mask}", 0) != "" ? "255.255.255.0" : "0.0.0.0"
  description = "Subnet mask in dotted decimal notation (e.g., 255.255.255.0)"
}

output "vm_dns_server" {
  value       = var.vm_dns_server
  description = "Primary DNS server configured on the VM"
}

output "vm_domain" {
  value       = var.vm_domain
  description = "DNS domain suffix configured on the VM"
}

# --- Infrastructure Metadata ---

output "resource_pool_id" {
  value       = data.vsphere_compute_cluster.cluster.resource_pool_id
  description = "vSphere resource pool ID where VM is placed"
}

output "datastore_cluster_id" {
  value       = data.vsphere_datastore_cluster.datastore_cluster.id
  description = "vSphere datastore cluster ID where VM storage is allocated"
}

output "network_id" {
  value       = data.vsphere_network.virtual_port_group.id
  description = "vSphere network ID (port group) the VM is connected to"
}

output "datacenter_id" {
  value       = data.vsphere_datacenter.dc.id
  description = "vSphere datacenter ID"
}

# --- VM Configuration ---

output "vm_cpus" {
  value       = vsphere_virtual_machine.vm.num_cpus
  description = "Number of virtual CPU cores assigned to the VM"
}

output "vm_memory_gb" {
  value       = var.vm_ram
  description = "Memory in GB assigned to the VM"
}

output "vm_memory_mb" {
  value       = vsphere_virtual_machine.vm.memory
  description = "Memory in MB assigned to the VM (computed from GB input)"
}

output "vm_main_disk_size_gb" {
  value       = vsphere_virtual_machine.vm.disk[0].size
  description = "Size in GB of the primary OS disk"
}

output "vm_additional_disk_count" {
  value       = length(var.additional_disks)
  description = "Number of additional disks attached to the VM"
}

# --- OS Configuration ---

output "vm_os_type" {
  value       = data.vsphere_guest_os_customization.custom_spec.type
  description = "Operating system type (Windows or Linux)"
}

output "vm_customization_spec" {
  value       = var.vm_customization
  description = "vCenter customization spec name applied to the VM"
}

output "vm_template_used" {
  value       = var.vm_template
  description = "VM template name used as the source for cloning"
}

# --- Deployment Metadata ---

output "ticket_id" {
  value       = var.ticket_id
  description = "Ticket ID associated with the deployment"
}

output "owner_department" {
  value       = var.owner_dept
  description = "Department that owns and manages the VM"
}

output "vm_notes" {
  value       = var.vm_notes
  description = "Function/purpose notes for the VM"
}

# --- Composite Output for Configuration Management Integration ---

output "connection_info" {
  value = {
    host            = var.vm_ip_address
    hostname        = vsphere_virtual_machine.vm.name
    fqdn            = "${vsphere_virtual_machine.vm.name}.${var.vm_domain}"
    user            = data.vsphere_guest_os_customization.custom_spec.type == "Windows" ? "Administrator" : "root"
    os_type         = data.vsphere_guest_os_customization.custom_spec.type == "Windows" ? "windows" : "linux"
    gateway         = var.vm_default_gw
    dns_server      = var.vm_dns_server
    subnet_mask     = var.vm_subnet_mask
  }
  description = "Connection and configuration information for use with Ansible, Puppet, or other configuration management tools. Contains host IP, hostname, FQDN, SSH/RDP user, and OS type."
  sensitive   = false
}

# --- Composite Output for Infrastructure Tracking ---

output "vm_metadata" {
  value = {
    vm_id              = vsphere_virtual_machine.vm.id
    vm_name            = vsphere_virtual_machine.vm.name
    vm_fqdn            = "${vsphere_virtual_machine.vm.name}.${var.vm_domain}"
    ip_address         = var.vm_ip_address
    cpu_count          = vsphere_virtual_machine.vm.num_cpus
    memory_gb          = var.vm_ram
    os_type            = data.vsphere_guest_os_customization.custom_spec.type
    cluster            = var.target_cluster
    datastore_cluster  = var.target_datastore_cluster
    network            = var.target_virtual_port_group
    ticket_id          = var.ticket_id
    owner_department   = var.owner_dept
    vm_notes           = var.vm_notes
  }
  description = "Complete VM metadata for CMDB, monitoring systems, and infrastructure inventory. Suitable for export to JSON/YAML for documentation and tracking."
  sensitive   = false
}
