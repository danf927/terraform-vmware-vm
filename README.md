# VMware VM Deployment Module

A Terraform module for automating virtual machine provisioning on VMware vSphere infrastructure. Supports both Windows and Linux deployments with flexible configuration options for network settings, storage, and OS customization.

## Features

- **Multi-OS Support**: Deploy Windows Server 2025 or Linux (RHEL/CentOS) VMs
- **Flexible Customization**: Guest OS customization specs for both Windows and Linux
- **Dynamic Disk Management**: Define additional disks beyond the OS disk
- **Domain Join**: Automatic Windows domain joining during provisioning
- **Network Configuration**: DHCP or static IP assignment with customizable DNS settings
- **Infrastructure as Code**: Reproducible, version-controlled deployments
- **Modular Design**: Clean separation of connection, placement, sizing, and networking concerns

## AI Disclosure

This project was made with the assistance of generative AI tools (Claude Code).  AI was utilized for the following portions of the project:
- General project planning.
- Authoring all included technical documentation and standardation of in-code comments.
- Assistance with troubleshooting specific errors encountered during testing.
- Anonymization of included values.
- Reorganization of contents in the variables.tf file to improve readability.
- Suggestion of outputs to include in the outputs.tf file.

## Prerequisites

### Software
- Terraform >= 1.5.0
- vSphere provider ~> 2.8

### Infrastructure
- vSphere 6.0+ environment
- Access to vCenter with appropriate credentials
- Existing VM templates (Linux-GOLD, Windows-2025-GOLD)
- Pre-configured OS customization specs in vCenter
- Network port groups and datastore clusters configured

### Credentials
All sensitive values **must** be supplied via environment variables—never commit them to tfvars files:

```bash
# vSphere access
export TF_VAR_vsphere_user="your-username@example.com"
export TF_VAR_vsphere_password="your-password"

# Windows VM admin (required for Windows builds)
export TF_VAR_vm_admin_password="windows-admin-password"

# Domain join credentials (optional, for Windows domain join)
export TF_VAR_vm_domain_user="domain-account@example.com"
export TF_VAR_vm_domain_password="domain-password"
```

## Quick Start

### 1. Clone or reference this module

```hcl
module "vmware_vm" {
  source = "path/to/vmware-vm-module"
  
  # vSphere connection
  vsphere_server = "vsphere.example.com"
  vsphere_folder = "VMs/Production"
  
  # Placement
  target_cluster             = "Cluster-Production"
  target_datastore_cluster   = "Datastore-Linux"
  target_virtual_port_group  = "Network-Production"
  
  # VM configuration
  vm_template      = "Linux-GOLD"
  vm_customization = "Linux-Production"
  vm_name          = "web-server-01"
  vm_cpus          = 4
  vm_ram           = 8
  
  # Networking
  vm_ip_address = "10.0.1.100"
  vm_subnet_mask = 24
  vm_default_gw = "10.0.1.1"
  vm_dns_server = "10.0.0.10"
  
  # Metadata
  ticket_id  = "TICKET-12345"
  owner_dept = "Infrastructure"
  vm_notes   = "Production web server"
}
```

### 2. Use provided deployment specs

Deployment specifications are pre-configured for common scenarios:

```bash
# Deploy a Linux development VM
terraform apply -var-file="linux-dev.tfvars"

# Deploy a Linux production VM
terraform apply -var-file="linux-prod.tfvars"

# Deploy a Linux staging VM
terraform apply -var-file="linux-staging.tfvars"

# Deploy a Windows Server 2025 VM
terraform apply -var-file="windows-2025.tfvars"
```

## Deployment Specs

Each `.tfvars` file pre-configures networking, clusters, and customization specs for a specific deployment scenario:

| Spec | OS | Template | Network | Cluster | Customization |
|------|-----|----------|---------|---------|---------------|
| `linux-dev.tfvars` | Linux | Linux-GOLD | Network-Development | Cluster-Development | Linux-Dev |
| `linux-prod.tfvars` | Linux | Linux-GOLD | Network-Production | Cluster-Production | Linux-Production |
| `linux-staging.tfvars` | Linux | Linux-GOLD | Network-Staging | Cluster-Production | Linux-Staging |
| `windows-2025.tfvars` | Windows | Windows-2025-GOLD | Network-Development | Cluster-Development | Windows-2025 |

## Variable Organization

Variables are organized into logical sections for ease of use:

- **Provider / Connection**: vSphere server and SSL settings
- **Credentials & Authentication**: All user accounts and passwords
- **Placement**: Datacenter, cluster, datastore, and network selection
- **Template / Customization**: OS template and customization spec selection
- **Windows/Linux Customization Settings**: OS-specific configuration options
- **VM Identity / Sizing**: VM name, CPU, RAM, and disk configuration
- **Networking**: IP, DNS, gateway, and domain settings
- **Metadata**: Ticket ID, department, and notes

See [TECHNICAL.md](TECHNICAL.md) for detailed variable descriptions and advanced configuration options.

## Input Variables

### Required
- `vm_name`: Name of the VM (max 15 characters)
- `vm_cpus`: Number of virtual CPU cores
- `vm_ram`: Memory in GB
- `vm_ip_address`: IPv4 address for the VM
- `vm_default_gw`: Default gateway IP
- `ticket_id`: Ticket ID for tracking
- `owner_dept`: Department owning the server
- `vm_notes`: VM purpose/function
- `target_cluster`: Compute cluster for placement
- `target_datastore_cluster`: Datastore cluster for storage
- `target_virtual_port_group`: Network/VLAN assignment
- `vm_template`: VM template to clone
- `vm_customization`: OS customization spec

### Optional
- `vsphere_folder`: vSphere folder path
- `vm_main_disk`: Root disk size (defaults to template size)
- `additional_disks`: List of additional disk definitions
- `vm_subnet_mask`: Subnet mask in CIDR bits (default: 20)
- `vm_dns_server`: DNS server IP (default: 10.0.0.10)
- `vm_domain`: DNS domain (default: example.com)
- `vm_admin_password`: Windows admin password (Windows only)
- `vm_domain_user`: Domain account for Windows joining (optional)
- `vm_domain_password`: Password for domain account (optional)

## Outputs

The module exposes comprehensive outputs for integration with other systems, configuration management tools, monitoring platforms, and infrastructure tracking:

| Output | Type | Description |
|--------|------|-------------|
| `vm_id` | string | vSphere UUID of the deployed VM |
| `vm_name` | string | Name of the deployed VM |
| `vm_fqdn` | string | Fully qualified domain name |
| `vm_ip_address` | string | IP address assigned to the VM |
| `vm_gateway` | string | Default gateway for the VM |
| `vm_subnet_mask` | number | Subnet mask in CIDR notation |
| `vm_dns_server` | string | Primary DNS server |
| `connection_info` | object | Composite connection details for Ansible/Puppet |
| `vm_metadata` | object | Complete VM metadata for CMDB/inventory |

**Example: Using outputs in another module**

```hcl
module "vmware_vm" {
  source = "./vmware-vm-module"
  # ... variables ...
}

# Use in Ansible provisioning
resource "null_resource" "configure_vm" {
  provisioner "local-exec" {
    command = "ansible-playbook -i '${module.vmware_vm.vm_ip_address},' playbooks/configure.yml"
  }
}

# Export to JSON for CMDB
resource "local_file" "vm_inventory" {
  content  = jsonencode(module.vmware_vm.vm_metadata)
  filename = "inventory/${module.vmware_vm.vm_name}.json"
}

# Access connection info
output "ssh_command" {
  value = "ssh ${module.vmware_vm.connection_info.user}@${module.vmware_vm.connection_info.fqdn}"
}
```

See [TECHNICAL.md](TECHNICAL.md) for detailed output documentation and integration examples.

## Examples

### Example 1: Linux Development VM

```hcl
terraform apply \
  -var-file="linux-dev.tfvars" \
  -var="vm_name=app-dev-01" \
  -var="vm_cpus=2" \
  -var="vm_ram=4" \
  -var="vm_ip_address=10.0.2.50" \
  -var="vm_default_gw=10.0.2.1" \
  -var="ticket_id=TKT-5678" \
  -var="owner_dept=Applications"
```

### Example 2: Windows Server with Additional Disks

Create a `deploy.tfvars` file:

```hcl
vsphere_server          = "vsphere.example.com"
vsphere_folder          = "VMs/Production"
vm_name                 = "db-server-01"
vm_cpus                 = 8
vm_ram                  = 32
vm_main_disk            = 100
additional_disks = [
  { size_gb = 500, label = "data-disk" },
  { size_gb = 200, label = "log-disk" }
]

vm_ip_address           = "10.0.1.200"
vm_default_gw           = "10.0.1.1"
vm_dns_server           = "10.0.0.10"

vm_template             = "Windows-2025-GOLD"
vm_customization        = "Windows-2025"
vm_full_name            = "Example Organization"
vm_org_name             = "Example Organization"

ticket_id               = "TKT-9999"
owner_dept              = "Database"
vm_notes                = "SQL Server database"
```

Then apply:

```bash
terraform apply -var-file="deploy.tfvars"
```

## Security Considerations

1. **Never commit credentials**: Sensitive variables (vsphere_user, passwords, domain credentials) must be supplied via environment variables only
2. **Environment variable handling**: Use a secure secrets manager (HashiCorp Vault, AWS Secrets Manager, etc.) in production
3. **State file security**: Terraform state may contain sensitive information; store in a secure backend with encryption and access controls
4. **Windows domain join**: Domain credentials are passed during deployment; ensure vCenter and the deployment network are on a secure connection
5. **SSL verification**: The module defaults to SSL verification (`allow_unverified_ssl = false`); only disable for testing environments

## Troubleshooting

### "Invalid cluster name specified"
Ensure the `target_cluster` value matches one of: Cluster-General, Cluster-Production, Cluster-Development, Cluster-Analytics, Cluster-Database

### "Template not found"
Verify the VM template exists in vCenter and is named exactly as specified in `vm_template`

### "Customization spec not found"
Confirm the OS customization spec exists in vCenter and matches the name in `vm_customization`

### "Network not found"
Check that the network port group name in `target_virtual_port_group` exists and is accessible from the target cluster

### Domain join fails
- Verify domain credentials are correct and have permission to join computers
- Ensure the VM can reach domain controllers on the network
- Note: vCenter customization specs do not support OU specification; VMs join to the default Computers container and must be moved manually if needed

## Module Structure

```
.
├── main.tf              # VM resource definition and data sources
├── providers.tf         # Provider configuration
├── variables.tf         # All input variables with validation
├── outputs.tf           # Output values for module consumers
├── linux-dev.tfvars     # Linux development deployment spec
├── linux-prod.tfvars    # Linux production deployment spec
├── linux-staging.tfvars # Linux staging deployment spec
├── windows-2025.tfvars  # Windows Server 2025 deployment spec
├── README.md            # This file
└── TECHNICAL.md         # Detailed technical documentation
```

## Advanced Configuration

See [TECHNICAL.md](TECHNICAL.md) for:
- Customization spec setup and validation
- Lifecycle rules and state management
- Network configuration details
- Windows domain join considerations
- Linux timezone and clock settings
- Complete output reference and integration patterns
- Integration with Ansible, monitoring systems, and CMDB tools
- Multi-module deployments

## Contributing

When contributing improvements to this module:
1. Maintain the logical organization of variables
2. Keep validation messages clear and actionable
3. Update both README.md and TECHNICAL.md
4. Test with both Windows and Linux deployments
5. Ensure credentials are never exposed in examples or defaults

## License

This module is provided as-is for reference and educational purposes.

## Support

For issues or questions:
1. Check [TECHNICAL.md](TECHNICAL.md) for detailed information
2. Review the Terraform vSphere provider documentation: https://registry.terraform.io/providers/hashicorp/vsphere/latest/docs
3. Consult VMware vSphere customization documentation for spec setup
