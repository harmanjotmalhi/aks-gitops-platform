terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.80.0"
    }
  }

  # Remote state in Azure Blob Storage created by terraform/bootstrap.
  # Values can be overridden with -backend-config at init time in CI.
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-aksplat"
    storage_account_name = "sttfstateaksplat01"
    container_name       = "tfstate-dev"
    key                  = "aks-platform.tfstate"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}
