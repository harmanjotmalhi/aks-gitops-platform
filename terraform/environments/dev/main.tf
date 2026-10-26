locals {
  name_prefix = "${var.project}-${var.environment}"
  tags = merge(var.tags, {
    environment = var.environment
    project     = var.project
    managed_by  = "terraform"
  })
}

resource "azurerm_resource_group" "main" {
  name     = "${local.name_prefix}-rg"
  location = var.location
  tags     = local.tags
}

module "networking" {
  source = "../../modules/networking"

  name_prefix         = local.name_prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  vnet_address_space  = var.vnet_address_space
  aks_subnet_prefixes = var.aks_subnet_prefixes
  tags                = local.tags
}

module "aks" {
  source = "../../modules/aks"

  name_prefix         = local.name_prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = local.name_prefix
  kubernetes_version  = var.kubernetes_version
  aks_subnet_id       = module.networking.aks_subnet_id

  system_node_min_count = var.system_node_min_count
  system_node_max_count = var.system_node_max_count
  system_node_vm_size   = var.system_node_vm_size

  user_node_min_count = var.user_node_min_count
  user_node_max_count = var.user_node_max_count
  user_node_vm_size   = var.user_node_vm_size

  network_policy         = var.network_policy
  admin_group_object_ids = var.admin_group_object_ids
  tags                   = local.tags
}
