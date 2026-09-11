# VMWARE VM DEPLOYMENT MODULE - PROVIDERS
# =================================================
# Pins the required Terraform and vsphere provider versions, and configures the
# vsphere provider connection.
#
# PREREQUISITES:
# Requires TF_VAR_vsphere_user / TF_VAR_vsphere_password set as environment variables.
# =================================================
# Author:  Dan Fereday
# Date Last Modified: 09/10/2026

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "~> 2.8"
    }
  }
}

provider "vsphere" {
  user                 = var.vsphere_user
  password             = var.vsphere_password
  vsphere_server       = var.vsphere_server
  allow_unverified_ssl = var.vsphere_allow_unverified_ssl
}
