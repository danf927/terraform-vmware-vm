# VMware VM Deployment Module - Technical Documentation

## Table of Contents

1. [Module Architecture](#module-architecture)
2. [Variable Organization](#variable-organization)
3. [Provider Configuration](#provider-configuration)
4. [Data Sources](#data-sources)
5. [Resource Definition](#resource-definition)
6. [OS Customization](#os-customization)
7. [Networking Configuration](#networking-configuration)
8. [Credential Handling](#credential-handling)
9. [Lifecycle Management](#lifecycle-management)
10. [Deployment Workflows](#deployment-workflows)

## Module Architecture

### Design Principles

1. **Separation of Concerns**: Variables organized into logical groups (connection, placement, sizing, networking, customization)
2. **Immutable Deployments**: Post-deployment infrastructure changes are ignored via lifecycle rules, enforcing IaC principles
3. **Flexible Configuration**: Both template-based specs and per-deployment customization supported
4. **Secure Credentials**: All sensitive values supplied via environment variables, never stored in tfvars files
5. **Validation at Input**: Cluster, datastore, network, and template names validated at apply time

### Module Flow

```
1. Provider Connection
   └─→ Connect to vSphere server with user/password
       
2. Data Source Lookups
   └─→ Resolve infrastructure names to IDs
       ├─→ Datacenter
       ├─→ Compute cluster → Resource pool
       ├─→ Datastore cluster
       ├─→ Virtual port group (network)
       ├─→ VM template
       └─→ OS customization spec

3. VM Resource Definition
   └─→ Create VM from template clone
       ├─→ Attach to resource pool and datastore cluster
       ├─→ Configure CPU, memory, disks
       ├─→ Connect to network
       └─→ Apply OS customization (Windows or Linux)

4. Post-Deployment
   └─→ Terraform state locked to template configuration
       (subsequent infrastructure changes ignored)
```

## Variable Organization

### Section 1: Provider / Connection

Controls vSphere connectivity and deployment folder location.

| Variable | Type | Required | Default | Purpose |
|----------|------|----------|---------|---------|
| `vsphere_server` | string | Yes | vsphere.example.com | vCenter hostname/IP |
| `vsphere_allow_unverified_ssl` | bool | No | false | Skip SSL verification (testing only) |
| `vsphere_folder` | string | Yes | — | vSphere folder path for VM placement |

**Example**:
```hcl
vsphere_server = "vsphere.example.com"
vsphere_folder = "VMs/Production/WebServers"
vsphere_allow_unverified_ssl = false
```

### Section 2: Credentials & Authentication

**All sensitive values must be supplied via environment variables.**

| Variable | Type | Sensitive | Required | Default | Purpose |
|----------|------|-----------|----------|---------|---------|
| `vsphere_user` | string | Yes | Yes | — | vCenter username |
| `vsphere_password` | string | Yes | Yes | — | vCenter password |
| `vm_admin_password` | string | Yes | No | null | Windows local admin password |
| `vm_domain_user` | string | Yes | No | null | Domain account for Windows join |
| `vm_domain_password` | string | Yes | No | null | Domain account password |

**Environment Variable Setup**:
```bash
export TF_VAR_vsphere_user="username@example.com"
export TF_VAR_vsphere_password="password123"
export TF_VAR_vm_admin_password="winpass123"
export TF_VAR_vm_domain_user="domain-user@example.com"
export TF_VAR_vm_domain_password="domainpass123"
```

**Never include in tfvars files**:
```hcl
# ❌ WRONG - Never do this
vsphere_user = "username@example.com"
vsphere_password = "password123"

# ✓ CORRECT - Use environment variables instead
# $env:TF_VAR_vsphere_user = "username@example.com"
```

### Section 3: Placement

Determines where the VM will be deployed in the vSphere infrastructure.

| Variable | Type | Required | Validation | Purpose |
|----------|------|----------|-----------|---------|
| `datacenter` | string | Yes | Must exist in vCenter | vSphere datacenter name |
| `target_cluster` | string | Yes | One of: Cluster-General, Cluster-Production, Cluster-Development, Cluster-Analytics, Cluster-Database | Compute cluster |
| `target_datastore_cluster` | string | Yes | One of: Datastore-Analytics, Datastore-General, Datastore-Development, Datastore-Database, Datastore-Linux | Storage cluster |
| `target_virtual_port_group` | string | Yes | One of: Network-Production, Network-Development, Network-Staging, Network-Management | Virtual network |

**Example**:
```hcl
datacenter = "Primary-DC"
target_cluster = "Cluster-Production"
target_datastore_cluster = "Datastore-Linux"
target_virtual_port_group = "Network-Production"
```

**Adding New Clusters/Networks**: To support additional clusters or networks, update the validation rules in `variables.tf` for all three placement variables.

### Section 4: Template / Customization

Specifies which VM template to clone and which OS customization spec to apply.

| Variable | Type | Required | Validation | Purpose |
|----------|------|----------|-----------|---------|
| `vm_template` | string | Yes | One of: Linux-GOLD, Windows-2025-GOLD | VM template to clone |
| `vm_customization` | string | Yes | One of: Windows-2025, Linux-Production, Linux-Staging, Linux-Dev | vCenter customization spec |

**Example**:
```hcl
vm_template = "Linux-GOLD"
vm_customization = "Linux-Production"
```

**Template Prerequisites**:
- Template must exist in vCenter
- Template must have a valid guest OS type (Linux or Windows)
- Template snapshot should be taken after configuration for consistency

**Customization Spec Prerequisites**:
- Spec must be created in vCenter (PowerCLI or vSphere Client)
- Spec type must match OS (Linux specs for Linux deployments, Windows specs for Windows)
- Network settings in the spec are overridden by `vm_ip_address` and DNS variables

### Section 5: Windows Customization Settings

Applied when `vm_customization` resolves to a Windows spec.

| Variable | Type | Default | Purpose | Notes |
|----------|------|---------|---------|-------|
| `vm_full_name` | string | null | Full name in Windows guest customization | Copy from vCenter spec |
| `vm_org_name` | string | null | Organization name in Windows guest customization | Copy from vCenter spec |
| `vm_windows_timezone` | number | null | Windows timezone code (e.g., 10 for Mountain) | See timezone reference below |
| `vm_auto_logon_count` | number | 1 | Auto-logon count after sysprep | Copy from vCenter spec |

**Timezone Codes** (Common):
- 2: Greenwich Mean Time (GMT/UTC)
- 10: Mountain Standard Time (MST/MDT)
- 15: Pacific Standard Time (PST/PDT)
- 20: GMT+01:00 (Central European)

For a complete list, check the vCenter customization spec in PowerShell or vSphere Client.

**Windows Domain Join**:
- If `vm_domain_user` is null, domain join is skipped
- If `vm_domain_user` is provided, the VM joins the domain specified in `vm_domain`
- Domain join occurs during initial sysprep
- **Limitation**: vCenter customization specs do not support OU specification; VMs join to the default Computers container and must be moved manually if needed

**Example**:
```hcl
vm_full_name = "Example Organization"
vm_org_name = "Example Organization"
vm_windows_timezone = 10
vm_auto_logon_count = 1
```

### Section 6: Linux Customization Settings

Applied when `vm_customization` resolves to a Linux spec.

| Variable | Type | Default | Purpose | Notes |
|----------|------|---------|---------|-------|
| `vm_linux_timezone` | string | null | Linux timezone identifier | Examples: America/Denver, America/New_York, UTC |
| `vm_hw_clock_utc` | bool | true | Whether hardware clock is set to UTC | Almost always true in cloud/VM environments |

**Linux Timezone Examples**:
- UTC
- America/Denver (Mountain Time)
- America/Chicago (Central Time)
- America/New_York (Eastern Time)
- Europe/London
- Asia/Tokyo

**Example**:
```hcl
vm_linux_timezone = "America/Denver"
vm_hw_clock_utc = true
```

### Section 7: VM Identity / Sizing

Defines the VM's name, resources, and storage.

| Variable | Type | Required | Validation | Default | Purpose |
|----------|------|----------|-----------|---------|---------|
| `vm_name` | string | Yes | Max 15 characters | — | VM hostname (also used as vSphere VM name) |
| `vm_cpus` | number | Yes | — | — | Virtual CPU cores to assign |
| `vm_ram` | number | Yes | — | — | Memory in GB to assign |
| `vm_main_disk` | number | No | — | null | Root/C: disk size in GB (null = use template size) |
| `additional_disks` | list(object) | No | — | [] | List of additional disks to attach |

**Disk Object Structure**:
```hcl
additional_disks = [
  {
    size_gb = 100
    label   = "data-disk"
  },
  {
    size_gb = 50
    label   = "logs-disk"
  }
]
```

**Example**:
```hcl
vm_name = "app-server-01"
vm_cpus = 4
vm_ram = 8
vm_main_disk = 100
additional_disks = [
  { size_gb = 200, label = "data" }
]
```

**Sizing Considerations**:
- Minimum recommended: 2 CPUs, 2 GB RAM for Linux; 2 CPUs, 4 GB RAM for Windows
- Production deployments: 4+ CPUs, 8+ GB RAM
- Disks are thin-provisioned by default (actual space consumed grows with data)

### Section 8: Networking

Configures IP addressing and DNS resolution.

| Variable | Type | Required | Example | Purpose |
|----------|------|----------|---------|---------|
| `vm_ip_address` | string | Yes | 10.0.1.100 | IPv4 address for the VM |
| `vm_subnet_mask` | number | No | 24 | Subnet mask in CIDR bits (default: 20) |
| `vm_default_gw` | string | Yes | 10.0.1.1 | Default gateway IP |
| `vm_dns_server` | string | No | 10.0.0.10 | DNS server IP (default: 10.0.0.10) |
| `vm_domain` | string | No | example.com | DNS domain suffix (default: example.com) |

**CIDR Subnet Mask Examples**:
- /24 = 255.255.255.0 (254 usable hosts per subnet)
- /25 = 255.255.255.128 (126 usable hosts per subnet)
- /20 = 255.255.240.0 (4094 usable hosts per subnet)

**Example**:
```hcl
vm_ip_address = "10.0.1.100"
vm_subnet_mask = 24
vm_default_gw = "10.0.1.1"
vm_dns_server = "10.0.0.10"
vm_domain = "example.com"
```

**DHCP vs. Static IP**:
- This module implements **static IP assignment** via customization specs
- For DHCP deployments, the `vm_ip_address` variable should be set to a placeholder (customization spec will override)
- Confirm with your vCenter customization spec how it handles IP assignment

### Section 9: Metadata

Administrative information for tracking and documentation.

| Variable | Type | Required | Purpose |
|----------|------|----------|---------|
| `ticket_id` | string | Yes | Ticket/case ID for the VM deployment request |
| `owner_dept` | string | Yes | Department that owns/manages the VM |
| `vm_notes` | string | Yes | VM function/purpose (application, database, etc.) |

These values are stored in the VM's vSphere annotation for future reference and auditing.

**Example**:
```hcl
ticket_id = "TKT-12345"
owner_dept = "Applications"
vm_notes = "Production web application server"
```

## Provider Configuration

### Terraform Required Version
```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "~> 2.8"
    }
  }
}
```

### Provider Block
```hcl
provider "vsphere" {
  user           = var.vsphere_user
  password       = var.vsphere_password
  vsphere_server = var.vsphere_server
  allow_unverified_ssl = var.vsphere_allow_unverified_ssl
}
```

**SSL Certificate Verification**:
- Production: Always use `allow_unverified_ssl = false` (default)
- Testing/Lab: Set to `true` only if vCenter uses self-signed certificates
- Never disable in production environments

## Data Sources

The module uses data sources to resolve infrastructure names to their vSphere IDs. This approach ensures compatibility across different vSphere environments without hardcoding IDs.

### 1. Datacenter Data Source
```hcl
data "vsphere_datacenter" "dc" {
  name = var.datacenter
}
```
Resolves the datacenter name to its UUID.

### 2. Compute Cluster Data Source
```hcl
data "vsphere_compute_cluster" "cluster" {
  name          = var.target_cluster
  datacenter_id = data.vsphere_datacenter.dc.id
}
```
Resolves the cluster name and extracts its resource pool ID (used for VM placement).

### 3. Datastore Cluster Data Source
```hcl
data "vsphere_datastore_cluster" "datastore_cluster" {
  name          = var.target_datastore_cluster
  datacenter_id = data.vsphere_datacenter.dc.id
}
```
Resolves the datastore cluster for storage resource allocation.

### 4. Network Data Source
```hcl
data "vsphere_network" "virtual_port_group" {
  name          = var.target_virtual_port_group
  datacenter_id = data.vsphere_datacenter.dc.id
}
```
Resolves the virtual port group (network) for VM networking.

### 5. VM Template Data Source
```hcl
data "vsphere_virtual_machine" "template" {
  name          = var.vm_template
  datacenter_id = data.vsphere_datacenter.dc.id
}
```
Resolves the template VM and extracts its configuration (guest ID, firmware, network interface types, disk sizes).

### 6. Customization Spec Data Source
```hcl
data "vsphere_guest_os_customization" "custom_spec" {
  name = var.vm_customization
}
```
Resolves the customization spec and determines its type (Windows or Linux).

## Resource Definition

### VM Resource Structure

```hcl
resource "vsphere_virtual_machine" "vm" {
  # Identity
  name = var.vm_name
  
  # Placement
  resource_pool_id     = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_cluster_id = data.vsphere_datastore_cluster.datastore_cluster.id
  folder               = var.vsphere_folder
  
  # Hardware Configuration
  num_cpus               = var.vm_cpus
  memory                 = var.vm_ram * 1024  # Convert GB to MB
  memory_hot_add_enabled = true               # Allow memory hot-add
  cpu_hot_add_enabled    = true               # Allow CPU hot-add
  
  # Template Inheritance
  guest_id = data.vsphere_virtual_machine.template.guest_id
  firmware = data.vsphere_virtual_machine.template.firmware
  
  # Annotation (metadata stored in vSphere)
  annotation = <<-EOT
    New VM
    Ticket ID: ${var.ticket_id}
    Dept: ${var.owner_dept}
    Function/Purpose: ${var.vm_notes}
  EOT
  
  # Networking
  network_interface {
    network_id   = data.vsphere_network.virtual_port_group.id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }
  
  # Primary OS Disk
  disk {
    label            = "disk0"
    size             = var.vm_main_disk != null ? var.vm_main_disk : data.vsphere_virtual_machine.template.disks[0].size
    thin_provisioned = true
  }
  
  # Additional Disks (dynamic)
  dynamic "disk" {
    for_each = var.additional_disks
    content {
      label            = disk.value.label
      size             = disk.value.size_gb
      thin_provisioned = true
      unit_number      = disk.key + 1  # Unit numbers start at 1 for additional disks
    }
  }
  
  # Clone Configuration
  clone {
    template_uuid = data.vsphere_virtual_machine.template.id
    
    customize {
      # Windows Customization (applied if spec type is Windows)
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
      
      # Linux Customization (applied if spec type is Linux)
      dynamic "linux_options" {
        for_each = data.vsphere_guest_os_customization.custom_spec.type == "Linux" ? [1] : []
        content {
          host_name    = var.vm_name
          domain       = var.vm_domain
          hw_clock_utc = var.vm_hw_clock_utc
          time_zone    = var.vm_linux_timezone
        }
      }
      
      # Network Configuration (applies to both Windows and Linux)
      network_interface {
        ipv4_address = var.vm_ip_address
        ipv4_netmask = var.vm_subnet_mask
      }
      ipv4_gateway    = var.vm_default_gw
      dns_server_list = [var.vm_dns_server]
    }
  }
  
  # Lifecycle: Ignore post-deployment infrastructure changes
  lifecycle {
    ignore_changes = all
  }
}
```

### Key Design Decisions

1. **Dynamic Customization Blocks**: Only one (Windows or Linux) customization block executes, determined by the customization spec type. This ensures OS-appropriate settings are applied.

2. **Memory Conversion**: `memory = var.vm_ram * 1024` converts GB input to MB (vSphere internal format).

3. **Hot-Add Enabled**: Both CPU and memory hot-add are enabled, allowing runtime resource increases (where guest OS supports it).

4. **Thin Provisioning**: All disks are thin-provisioned (logical size defined, physical space consumed on-demand). Change to `thin_provisioned = false` for thick provisioning if needed.

5. **Network Interface Adapter Type**: Inherited from template (`network_interface_types[0]`) to ensure compatibility with the OS type and vSphere version.

6. **Unit Number Allocation**: Primary disk is `disk0` (unit 0), additional disks start at unit 1 (`disk.key + 1`). Unit numbers must be sequential and unique per VM.

7. **Lifecycle Rule**: `ignore_changes = all` locks the VM configuration to the template state. Post-deployment infrastructure changes (CPU/memory hot-add, additional disk attachment, network modifications) must be made directly in vCenter or via Terraform-external scripts. This enforces immutable infrastructure principles.

## OS Customization

### Windows Customization Flow

1. **Sysprep Execution**: vCenter runs Windows System Preparation (Sysprep) during clone
2. **Customization Spec Application**: Settings from the selected spec are applied
3. **Network Configuration**: Static IP, DNS, gateway are set post-spec
4. **Domain Join** (if enabled): Computer joins the domain with provided credentials
5. **Auto-Logon**: VM automatically logs in N times post-deployment (for initial provisioning tasks)

### Linux Customization Flow

1. **Cloud-Init** (if template uses it): Processes customization data
2. **Customization Spec Application**: Settings from the selected spec are applied
3. **Network Configuration**: Static IP, DNS, gateway are set
4. **Hostname/Domain**: VM hostname and DNS domain are configured
5. **Hardware Clock**: Set to UTC or local time based on spec

### Creating a Customization Spec in vCenter

**PowerCLI Example** (Windows):
```powershell
$spec = New-OSCustomizationSpec -Name "Windows-2025" `
  -OSType Windows `
  -FullName "Example Organization" `
  -OrgName "Example Organization" `
  -AutoLogonCount 1 `
  -TimeZone "Mountain Standard Time" `
  -Workgroup WORKGROUP

$ipSettings = New-OSCustomizationNicMapping -IpMode UseStaticIP `
  -IpAddress "10.0.0.1" `
  -SubnetMask "255.255.255.0" `
  -DefaultGateway "10.0.0.1" `
  -Dns "10.0.0.10"

Get-OSCustomizationNicMapping -OSCustomizationSpec $spec | `
  Set-OSCustomizationNicMapping -IpMode UseStaticIP -IpSettings $ipSettings
```

**PowerCLI Example** (Linux):
```powershell
$spec = New-OSCustomizationSpec -Name "Linux-Production" `
  -OSType Linux `
  -TimeZone "America/Denver"

$ipSettings = New-OSCustomizationNicMapping -IpMode UseStaticIP `
  -IpAddress "10.0.0.1" `
  -SubnetMask "255.255.255.0" `
  -DefaultGateway "10.0.0.1" `
  -Dns "10.0.0.10"

Get-OSCustomizationNicMapping -OSCustomizationSpec $spec | `
  Set-OSCustomizationNicMapping -IpMode UseStaticIP -IpSettings $ipSettings
```

## Networking Configuration

### Static IP Assignment Process

1. **Customization Spec IP Mode**: Set to "Use Static IP" in the spec
2. **Network Interface Block**: Module provides IP, subnet, gateway at clone time
3. **vCenter Application**: vCenter applies these settings during guest customization
4. **VM Boot**: Guest OS boots with configured IP address

### DHCP Configuration

For DHCP deployments:
1. Create a customization spec with "Use DHCP" mode
2. Set `vm_ip_address` to a placeholder (e.g., "0.0.0.0") or a dummy value
3. Module variables still require a value, but customization spec setting takes precedence
4. VM will receive IP from DHCP server during boot

### DNS Configuration

- Primary DNS server provided via `vm_dns_server` variable
- Secondary DNS servers not currently supported (modify customization spec in vCenter if needed)
- DNS domain suffix set via `vm_domain` variable
- Linux VMs populate `/etc/resolv.conf`; Windows VMs use DHCP/static DNS settings

### Network Port Group Considerations

- Port group must exist in vSphere and be accessible from the target cluster
- VLAN ID must match the port group configuration
- Virtual switch attached to the port group must have uplink ports active
- Multiple network interfaces: Currently, module supports one NIC; for multi-NIC VMs, extend the `network_interface` block in `main.tf`

## Credential Handling

### Best Practices

1. **Environment Variables Only**: Never hardcode credentials in tfvars files
2. **Temporary Sessions**: Export credentials in a shell session, then unset after deployment
3. **Secrets Manager Integration**: Use HashiCorp Vault, AWS Secrets Manager, or similar for automated deployments
4. **State File Encryption**: Terraform state contains sensitive data; store in an encrypted backend (Terraform Cloud, S3 with encryption, etc.)
5. **Audit Logging**: Enable vCenter audit logging to track deployments made with service accounts

### Manual Credential Supply (Development/Testing)

```bash
# Set credentials in shell session
export TF_VAR_vsphere_user="admin@example.com"
export TF_VAR_vsphere_password="password123"
export TF_VAR_vm_admin_password="winpass123"

# Run Terraform
terraform plan
terraform apply

# Unset credentials
unset TF_VAR_vsphere_user
unset TF_VAR_vsphere_password
unset TF_VAR_vm_admin_password
```

### Vault Integration (Production Example)

```bash
# Retrieve credentials from Vault and set as environment variables
export TF_VAR_vsphere_user=$(vault kv get -field=username secret/vmware/credentials)
export TF_VAR_vsphere_password=$(vault kv get -field=password secret/vmware/credentials)
export TF_VAR_vm_admin_password=$(vault kv get -field=admin_password secret/vmware/credentials)
export TF_VAR_vm_domain_user=$(vault kv get -field=domain_user secret/vmware/credentials)
export TF_VAR_vm_domain_password=$(vault kv get -field=domain_password secret/vmware/credentials)

terraform apply -var-file="linux-prod.tfvars"

# Credentials automatically unset when shell exits
```

## Output Values

The module exposes comprehensive outputs to enable integration with other systems, configuration management tools, and infrastructure platforms. Outputs define the module's contract with consumers and support 12-factor application principles.

### Output Categories

#### VM Identity Outputs

```hcl
output "vm_id" {
  value = vsphere_virtual_machine.vm.id
  description = "vSphere unique identifier (UUID) of the deployed VM"
}

output "vm_name" {
  value = vsphere_virtual_machine.vm.name
  description = "Name of the deployed VM"
}

output "vm_fqdn" {
  value = "${vsphere_virtual_machine.vm.name}.${var.vm_domain}"
  description = "Fully qualified domain name of the VM"
}
```

**Use Cases**:
- Reference VMs in other Terraform modules
- Pass to monitoring systems for alerting
- Generate DNS records
- CMDB integration

#### Network Configuration Outputs

```hcl
output "vm_ip_address" {
  value = var.vm_ip_address
  description = "IPv4 address assigned to the VM"
}

output "vm_gateway" {
  value = var.vm_default_gw
  description = "Default gateway for the VM"
}

output "vm_subnet_mask" {
  value = var.vm_subnet_mask
  description = "Subnet mask in CIDR notation (e.g., 24 for /24)"
}

output "vm_dns_server" {
  value = var.vm_dns_server
  description = "Primary DNS server configured on the VM"
}

output "vm_domain" {
  value = var.vm_domain
  description = "DNS domain suffix configured on the VM"
}
```

**Use Cases**:
- Create DNS records (Route53, Infoblox, etc.)
- Configure firewall rules
- Build network topology documentation
- Subnet planning and IP management

#### Infrastructure Metadata Outputs

```hcl
output "resource_pool_id" {
  value = data.vsphere_compute_cluster.cluster.resource_pool_id
  description = "vSphere resource pool ID where VM is placed"
}

output "datastore_cluster_id" {
  value = data.vsphere_datastore_cluster.datastore_cluster.id
  description = "vSphere datastore cluster ID where VM storage is allocated"
}

output "network_id" {
  value = data.vsphere_network.virtual_port_group.id
  description = "vSphere network ID (port group) the VM is connected to"
}

output "datacenter_id" {
  value = data.vsphere_datacenter.dc.id
  description = "vSphere datacenter ID"
}
```

**Use Cases**:
- Reference infrastructure IDs in nested modules
- Build resource dependency graphs
- Infrastructure audit trails

#### VM Configuration Outputs

```hcl
output "vm_cpus" {
  value = vsphere_virtual_machine.vm.num_cpus
  description = "Number of virtual CPU cores assigned to the VM"
}

output "vm_memory_gb" {
  value = var.vm_ram
  description = "Memory in GB assigned to the VM"
}

output "vm_memory_mb" {
  value = vsphere_virtual_machine.vm.memory
  description = "Memory in MB assigned to the VM (computed from GB input)"
}

output "vm_main_disk_size_gb" {
  value = vsphere_virtual_machine.vm.disk[0].size
  description = "Size in GB of the primary OS disk"
}

output "vm_additional_disk_count" {
  value = length(var.additional_disks)
  description = "Number of additional disks attached to the VM"
}
```

**Use Cases**:
- Capacity planning and trending
- Cost allocation (CPU/memory per department)
- Performance baseline documentation
- Compliance audits

#### OS Configuration Outputs

```hcl
output "vm_os_type" {
  value = data.vsphere_guest_os_customization.custom_spec.type
  description = "Operating system type (Windows or Linux)"
}

output "vm_customization_spec" {
  value = var.vm_customization
  description = "vCenter customization spec name applied to the VM"
}

output "vm_template_used" {
  value = var.vm_template
  description = "VM template name used as the source for cloning"
}
```

**Use Cases**:
- Inventory management (which OS versions deployed)
- Patch management system integration
- Configuration management tool routing (Ansible for Linux, Puppet for Windows, etc.)

#### Deployment Metadata Outputs

```hcl
output "ticket_id" {
  value = var.ticket_id
  description = "Ticket ID associated with the deployment"
}

output "owner_department" {
  value = var.owner_dept
  description = "Department that owns and manages the VM"
}

output "vm_notes" {
  value = var.vm_notes
  description = "Function/purpose notes for the VM"
}
```

**Use Cases**:
- CMDB records
- Billing/chargeback allocation
- Change management tracking
- Governance and compliance

### Composite Outputs

#### connection_info Output

```hcl
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
  description = "Connection and configuration information for use with configuration management tools"
  sensitive   = false
}
```

**Designed for**: Configuration management tools (Ansible, Puppet, Chef, SaltStack)

**Example Usage**:

```hcl
# Ansible playbook provisioning
resource "null_resource" "provision_vm" {
  triggers = {
    vm_ip = module.vmware_vm.connection_info.host
  }

  provisioner "local-exec" {
    command = <<-EOT
      ansible-playbook \
        -i '${module.vmware_vm.connection_info.host},' \
        -u '${module.vmware_vm.connection_info.user}' \
        playbooks/configure-${module.vmware_vm.connection_info.os_type}.yml
    EOT
  }
}

# Access individual fields
output "ssh_command" {
  value = "ssh ${module.vmware_vm.connection_info.user}@${module.vmware_vm.connection_info.fqdn}"
}

output "rdp_host" {
  value = module.vmware_vm.connection_info.os_type == "windows" ? module.vmware_vm.connection_info.host : null
}
```

#### vm_metadata Output

```hcl
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
  description = "Complete VM metadata for CMDB, monitoring systems, and infrastructure inventory"
  sensitive   = false
}
```

**Designed for**: CMDB, inventory systems, reporting tools

**Example Usage**:

```hcl
# Export to JSON for CMDB
resource "local_file" "vm_cmdb_record" {
  content  = jsonencode(module.vmware_vm.vm_metadata)
  filename = "inventory/cmdb/${module.vmware_vm.vm_metadata.vm_name}.json"
}

# Export to YAML for docs
resource "local_file" "vm_inventory" {
  content  = yamlencode(module.vmware_vm.vm_metadata)
  filename = "inventory/vms/${module.vmware_vm.vm_metadata.vm_name}.yaml"
}

# Feed to monitoring system
resource "datadog_host" "vm" {
  name = module.vmware_vm.vm_metadata.vm_fqdn
  tags = [
    "environment:${var.environment}",
    "owner:${module.vmware_vm.vm_metadata.owner_department}",
    "ticket:${module.vmware_vm.vm_metadata.ticket_id}"
  ]
}

# Feed to service catalog
resource "servicenow_cmdb_ci_server" "vm" {
  name            = module.vmware_vm.vm_metadata.vm_name
  fqdn            = module.vmware_vm.vm_metadata.vm_fqdn
  ip_address      = module.vmware_vm.vm_metadata.ip_address
  os_type         = module.vmware_vm.vm_metadata.os_type
  cpu_count       = module.vmware_vm.vm_metadata.cpu_count
  memory_gb       = module.vmware_vm.vm_metadata.memory_gb
  managed_by      = module.vmware_vm.vm_metadata.owner_department
  assignment_code = module.vmware_vm.vm_metadata.ticket_id
}
```

### Integration Examples

#### Example 1: Multi-Module Deployment with DNS

```hcl
module "vmware_vm" {
  source = "./vmware-vm-module"
  # ... variables ...
}

# Create Route53 DNS record
resource "aws_route53_record" "vm" {
  zone_id = var.route53_zone_id
  name    = module.vmware_vm.vm_fqdn
  type    = "A"
  ttl     = 300
  records = [module.vmware_vm.vm_ip_address]
}

# Output for user
output "vm_connection_string" {
  value = "ssh ${module.vmware_vm.connection_info.user}@${module.vmware_vm.vm_fqdn}"
}
```

#### Example 2: Ansible Provisioning Chain

```hcl
module "vmware_vm" {
  source = "./vmware-vm-module"
  # ... variables ...
}

# Generate Ansible inventory
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tpl", {
    host     = module.vmware_vm.connection_info.host
    hostname = module.vmware_vm.connection_info.hostname
    user     = module.vmware_vm.connection_info.user
    os_type  = module.vmware_vm.connection_info.os_type
  })
  filename = "inventory/hosts"
}

# Wait for VM to boot, then provision
resource "null_resource" "wait_and_provision" {
  depends_on = [module.vmware_vm]

  provisioner "local-exec" {
    command = "sleep 30"  # Wait for VM boot and network connectivity
  }

  provisioner "local-exec" {
    command = "ansible-playbook -i inventory/hosts playbooks/main.yml"
  }
}
```

#### Example 3: Monitoring System Integration

```hcl
module "vmware_vm" {
  source = "./vmware-vm-module"
  # ... variables ...
}

# Register with Prometheus
resource "null_resource" "prometheus_config" {
  triggers = {
    vm_id = module.vmware_vm.vm_id
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "- targets: ['${module.vmware_vm.vm_ip_address}:9100']" >> prometheus/targets.yml
      systemctl reload prometheus
    EOT
  }
}

# Register with CloudWatch
resource "aws_cloudwatch_metric_alarm" "vm_cpu" {
  alarm_name          = "${module.vmware_vm.vm_name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"  # For vSphere, use custom metrics
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alert when ${module.vmware_vm.vm_fqdn} CPU exceeds 80%"
  treat_missing_data  = "notBreaching"
}
```

#### Example 4: Bulk Export to CMDB

```hcl
# Deploy multiple VMs
module "vmware_vm" {
  for_each = var.vm_specs

  source = "./vmware-vm-module"
  # ... variables ...
}

# Export all VMs as single JSON file for CMDB import
resource "local_file" "cmdb_export" {
  content = jsonencode({
    for vm_key, vm_module in module.vmware_vm : vm_module.vm_name => vm_module.vm_metadata
  })
  filename = "exports/cmdb_${formatdate("YYYY-MM-DD_hhmm", timestamp())}.json"
}

# Export for reporting
output "deployment_summary" {
  value = {
    total_vms      = length(module.vmware_vm)
    total_cpus     = sum([for vm in module.vmware_vm : vm.vm_cpus])
    total_memory   = sum([for vm in module.vmware_vm : vm.vm_memory_gb])
    deployments    = { for k, vm in module.vmware_vm : vm.vm_name => vm.ticket_id }
  }
}
```

### Output Best Practices

1. **Don't Output Secrets**: Outputs are logged and displayed; never output passwords or credentials
   - ✓ Output: `connection_info.user` (username for reference)
   - ✗ Output: `connection_info.password` (never)

2. **Use Composite Outputs**: Group related fields into objects for easier consumption
   - ✓ One `connection_info` object with 6 fields
   - ✗ Six separate outputs for connection details

3. **Document Use Cases**: Add descriptions explaining where each output should be used
   - ✓ `vm_id` - "Reference in other Terraform modules, monitoring systems, CMDB"
   - ✗ `vm_id` - "The VM ID"

4. **Version Outputs Carefully**: If you add, rename, or remove outputs, consider backward compatibility
   - Removing outputs breaks downstream modules
   - Renaming outputs requires consumer updates
   - Adding outputs is always safe

## Lifecycle Management

### Immutable Infrastructure via ignore_changes

```hcl
lifecycle {
  ignore_changes = all
}
```

**Effect**: Once a VM is deployed, Terraform ignores any changes to vSphere configuration. This enforces immutable infrastructure principles:

- **Pro**: Prevents accidental overwrites of manual vSphere changes
- **Con**: Terraform cannot detect/track post-deployment modifications

**Implications**:

| Change Type | Ignored? | How to Apply | When to Use |
|------------|----------|--------------|-----------|
| CPU hot-add | Yes | Direct in vSphere; mark VM as "manually updated" | Runtime scaling |
| Memory hot-add | Yes | Direct in vSphere; mark VM as "manually updated" | Runtime scaling |
| Additional disk attachment | Yes | Direct in vSphere or Terraform module re-run with `taint` | Storage expansion |
| Network reconfiguration | Yes | Direct in vSphere; redeploy if major network changes | Network maintenance |
| Snapshot creation | Yes | Direct in vSphere; not tracked in Terraform | Backups/testing |

**To Re-Apply Template Changes**:

If the template is updated and you want to reapply its configuration to an existing VM:

```bash
# Taint the VM to force re-creation on next apply
terraform taint vsphere_virtual_machine.vm

# Apply to re-create the VM (will delete and recreate)
terraform apply -var-file="linux-prod.tfvars"
```

**Warning**: `terraform taint` followed by `apply` will delete and recreate the VM, destroying all post-deployment changes.

## Deployment Workflows

### Workflow 1: One-Off Deployment (Manual)

```bash
# 1. Set credentials in shell
export TF_VAR_vsphere_user="admin@example.com"
export TF_VAR_vsphere_password="password123"
export TF_VAR_vm_admin_password="winpass123"

# 2. Review the deployment spec
cat linux-prod.tfvars

# 3. Customize per-deployment values in a local copy
cp linux-prod.tfvars my-deployment.tfvars
vim my-deployment.tfvars  # Edit vm_name, ticket_id, owner_dept, etc.

# 4. Plan the deployment
terraform plan -var-file="my-deployment.tfvars"

# 5. Apply the deployment
terraform apply -var-file="my-deployment.tfvars"

# 6. Verify the VM in vSphere
# ...

# 7. Unset credentials
unset TF_VAR_vsphere_user
unset TF_VAR_vsphere_password
unset TF_VAR_vm_admin_password
```

### Workflow 2: Bulk Deployment (CI/CD Pipeline)

```hcl
# Store deployment specs in a CI/CD system (Git, artifact repository)
# Retrieve credentials from secrets manager (Vault, GitHub Secrets, etc.)
# Run terraform apply in the CI/CD runner

# Example: GitHub Actions
name: Deploy VMs
on:
  push:
    paths:
      - 'terraform/vm-deployments/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.5.0
      
      - name: Retrieve Secrets
        env:
          VAULT_ADDR: ${{ secrets.VAULT_ADDR }}
          VAULT_TOKEN: ${{ secrets.VAULT_TOKEN }}
        run: |
          export TF_VAR_vsphere_user=$(vault kv get -field=username secret/vmware)
          export TF_VAR_vsphere_password=$(vault kv get -field=password secret/vmware)
          # ... other credentials ...
      
      - name: Terraform Init
        run: terraform init
      
      - name: Terraform Plan
        run: terraform plan -var-file="deployments/linux-prod.tfvars"
      
      - name: Terraform Apply
        run: terraform apply -auto-approve -var-file="deployments/linux-prod.tfvars"
      
      - name: Notify Deployment
        run: |
          # Send notification to Slack, email, ticket system, etc.
          echo "VM deployment completed"
```

### Workflow 3: Multi-Environment Deployment

```bash
# Maintain separate tfvars files per environment
linux-dev.tfvars     # Development environment
linux-staging.tfvars # Staging environment
linux-prod.tfvars    # Production environment

# Deploy to development first
terraform apply -var-file="linux-dev.tfvars"

# After testing, deploy to staging
terraform apply -var-file="linux-staging.tfvars"

# After staging validation, deploy to production
terraform apply -var-file="linux-prod.tfvars"
```

### Workflow 4: Adding New Clusters/Networks

To support new clusters or networks:

1. **Update validation in `variables.tf`**:
```hcl
variable "target_cluster" {
  validation {
    condition = contains([
      "Cluster-General",
      "Cluster-Production",
      "Cluster-Development",
      "Cluster-Analytics",
      "Cluster-Database",
      "Cluster-NewCluster"  # Add new cluster
    ], var.target_cluster)
    error_message = "Invalid cluster name specified. Must be: ..."
  }
}
```

2. **Create a new deployment spec**:
```bash
cp linux-prod.tfvars linux-newenv.tfvars
# Edit cluster, network, customization values
```

3. **Test the new cluster**:
```bash
terraform plan -var-file="linux-newenv.tfvars"
terraform apply -var-file="linux-newenv.tfvars"
```

## Troubleshooting & Advanced Topics

### Debugging

**Enable verbose logging**:
```bash
export TF_LOG=DEBUG
terraform apply -var-file="linux-prod.tfvars"
unset TF_LOG
```

**Inspect Terraform state**:
```bash
terraform state show vsphere_virtual_machine.vm
```

**Check vSphere events** (vCenter UI):
- Administration > Events and Alarms
- Search for VM name
- Review customization progress and any errors

### Common Issues

1. **Customization Timeout**: If customization takes >30 min, vCenter may timeout. Check guest OS customization logs on the VM.
2. **Network Unreachable**: Verify the port group is active and VM has physical connectivity to the configured gateway.
3. **Domain Join Failure**: Confirm domain credentials have permission to add computers and that the domain is reachable from the VM.
4. **Template Clone Failure**: Verify the template exists, is not a running VM, and the resource pool has available capacity.

### Extending the Module

**Add output values**:
```hcl
output "vm_id" {
  value = vsphere_virtual_machine.vm.id
  description = "vSphere UUID of the deployed VM"
}

output "vm_ip" {
  value = var.vm_ip_address
  description = "IP address assigned to the VM"
}
```

**Add locals for computed values**:
```hcl
locals {
  vm_hostname = "${var.vm_name}.${var.vm_domain}"
  vm_memory_mb = var.vm_ram * 1024
}
```

**Support multiple NICs** (extend main.tf):
```hcl
variable "additional_networks" {
  type = list(string)
  default = []
}

# In vsphere_virtual_machine resource:
dynamic "network_interface" {
  for_each = var.additional_networks
  content {
    network_id = data.vsphere_network.additional[network_interface.key].id
  }
}
```

---

**Last Updated**: September 10, 2026  
**Author**: Dan Fereday
