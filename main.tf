# VMWARE VM DEPLOYMENT MODULE - MAIN
# =================================================
# Looks up the placement targets (datacenter, cluster, datastore cluster, network,
# template) and the OS customization spec, then defines the single VM resource that
# clones from the template. Windows vs. Linux guest customization is selected via
# dynamic blocks gated on the customization spec's type - only one of the two blocks
# will ever apply to a given VM.
#
# PREREQUISITES:
# Requires TF_VAR_vsphere_user / TF_VAR_vsphere_password set as environment variables.
# Windows builds also require TF_VAR_vm_admin_password, and domain join requires
# TF_VAR_vm_domain_user / TF_VAR_vm_domain_password.
#
# USAGE:  terraform apply -var-file=<spec>.tfvars
# =================================================
# Author:  Dan Fereday
# Date Last Modified: 09/10/2026

# Set datacenter
data "vsphere_datacenter" "dc" {
  name = var.datacenter
}

# Set target compute cluster for the VM to land on
data "vsphere_compute_cluster" "cluster" {
  name          = var.target_cluster
  datacenter_id = data.vsphere_datacenter.dc.id
}

# Set target datastore cluster for the VM to land on
data "vsphere_datastore_cluster" "datastore_cluster" {
  name          = var.target_datastore_cluster
  datacenter_id = data.vsphere_datacenter.dc.id
}

# Set target network (virtual port group) the VM will be connected to
data "vsphere_network" "virtual_port_group" {
  name          = var.target_virtual_port_group
  datacenter_id = data.vsphere_datacenter.dc.id
}

# Designate the VM template to be used to clone the new VM
data "vsphere_virtual_machine" "template" {
  name          = var.vm_template
  datacenter_id = data.vsphere_datacenter.dc.id
}

# Designate the VMWare OS Customization Spec to be used to clone the VM
data "vsphere_guest_os_customization" "custom_spec" {
  name = var.vm_customization
}


###########################################
# VM RESOURCE DEFINITION
###########################################
resource "vsphere_virtual_machine" "vm" {
  name                 = var.vm_name
  resource_pool_id     = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_cluster_id = data.vsphere_datastore_cluster.datastore_cluster.id
  folder               = var.vsphere_folder

  num_cpus               = var.vm_cpus
  memory                 = var.vm_ram * 1024
  memory_hot_add_enabled = true
  cpu_hot_add_enabled    = true
  guest_id               = data.vsphere_virtual_machine.template.guest_id
  firmware               = data.vsphere_virtual_machine.template.firmware

  annotation = <<-EOT
    New VM
    Ticket ID:  ${var.ticket_id}
    Dept:  ${var.owner_dept}
    Function/Purpose:  ${var.vm_notes}
  EOT

  network_interface {
    network_id   = data.vsphere_network.virtual_port_group.id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  disk {
    label            = "disk0"
    size             = var.vm_main_disk != null ? var.vm_main_disk : data.vsphere_virtual_machine.template.disks[0].size
    thin_provisioned = true
  }

  dynamic "disk" {
    for_each = var.additional_disks
    content {
      label            = disk.value.label
      size             = disk.value.size_gb
      thin_provisioned = true
      unit_number      = disk.key + 1
    }
  }


  clone {
    template_uuid = data.vsphere_virtual_machine.template.id

    customize {
      dynamic "linux_options" {
        for_each = data.vsphere_guest_os_customization.custom_spec.type == "Linux" ? [1] : []
        content {
          host_name    = var.vm_name
          domain       = var.vm_domain
          hw_clock_utc = var.vm_hw_clock_utc
          time_zone    = var.vm_linux_timezone
        }
      }

      dynamic "windows_options" {
        for_each = data.vsphere_guest_os_customization.custom_spec.type == "Windows" ? [1] : []
        content {
          computer_name     = var.vm_name
          full_name         = var.vm_full_name
          organization_name = var.vm_org_name
          auto_logon        = var.vm_auto_logon_count > 0
          auto_logon_count  = var.vm_auto_logon_count
          time_zone         = var.vm_windows_timezone
          admin_password    = var.vm_admin_password

          join_domain           = var.vm_domain_user != null ? var.vm_domain : null
          domain_admin_user     = var.vm_domain_user
          domain_admin_password = var.vm_domain_password
        }
      }

      network_interface {
        ipv4_address = var.vm_ip_address
        ipv4_netmask = var.vm_subnet_mask
      }
      ipv4_gateway    = var.vm_default_gw
      dns_server_list = [var.vm_dns_server]
    }
  }

  lifecycle {
    ignore_changes = all
  }
}
