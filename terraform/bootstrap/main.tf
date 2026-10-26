terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.80.0"
    }
  }
  # Bootstrap uses local state (chicken-and-egg): it CREATES the remote backend
  # that every other configuration then consumes.
}

provider "azurerm" {
  features {}
}

variable "location" {
  description = "Azure region for the state storage account."
  type        = string
  default     = "eastus2"
}

variable "state_resource_group_name" {
  description = "Resource group that holds the Terraform state storage account."
  type        = string
  default     = "rg-tfstate-aksplat"
}

variable "state_storage_account_name" {
  description = "Globally-unique name of the storage account that stores Terraform state."
  type        = string
  # Must be 3-24 lowercase alphanumeric chars and globally unique.
  default     = "sttfstateaksplat01"
}

resource "azurerm_resource_group" "state" {
  name     = var.state_resource_group_name
  location = var.location
}

resource "azurerm_storage_account" "state" {
  name                            = var.state_storage_account_name
  resource_group_name             = azurerm_resource_group.state.name
  location                        = azurerm_resource_group.state.location
  account_tier                    = "Standard"
  account_replication_type        = "GRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 30
    }
  }
}

# One container per environment keeps dev/prod state files isolated.
resource "azurerm_storage_container" "dev" {
  name                  = "tfstate-dev"
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "prod" {
  name                  = "tfstate-prod"
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
}

output "state_storage_account_name" {
  description = "Use this value as 'storage_account_name' in each environment backend."
  value       = azurerm_storage_account.state.name
}

output "state_resource_group_name" {
  value = azurerm_resource_group.state.name
}
