terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.80.0"
    }
  }
}

# Managed AKS cluster with:
#  - Azure CNI networking placed in the provided subnet
#  - calico/azure network policy for pod-level isolation
#  - AKS-managed Azure AD integration with Azure RBAC for Kubernetes authz
#  - system-assigned managed identity + workload identity / OIDC issuer
#  - autoscaling system node pool
resource "azurerm_kubernetes_cluster" "this" {
  name                = "${var.name_prefix}-aks"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version
  tags                = var.tags

  # Enforce local-account disablement so all access flows through Azure AD.
  local_account_disabled = true
  oidc_issuer_enabled    = true
  workload_identity_enabled = true

  default_node_pool {
    name                 = "system"
    vm_size              = var.system_node_vm_size
    vnet_subnet_id       = var.aks_subnet_id
    orchestrator_version = var.kubernetes_version
    auto_scaling_enabled = true
    min_count            = var.system_node_min_count
    max_count            = var.system_node_max_count
    os_disk_size_gb      = 64
    max_pods             = 50
    only_critical_addons_enabled = true

    upgrade_settings {
      max_surge = "33%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  # Azure AD integration with Kubernetes Azure RBAC.
  azure_active_directory_role_based_access_control {
    azure_rbac_enabled     = true
    admin_group_object_ids = var.admin_group_object_ids
  }

  network_profile {
    network_plugin = "azure"
    network_policy = var.network_policy
    service_cidr   = var.service_cidr
    dns_service_ip = var.dns_service_ip
    load_balancer_sku = "standard"
  }

  # Enable the Key Vault secrets provider (CSI) for secure secret injection.
  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  lifecycle {
    ignore_changes = [
      # Node counts are managed by the cluster autoscaler at runtime.
      default_node_pool[0].node_count,
    ]
  }
}

# Dedicated user node pool for application workloads, kept separate from the
# system pool so platform add-ons are not resource-starved by app pods.
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "app"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = var.user_node_vm_size
  orchestrator_version  = var.kubernetes_version
  vnet_subnet_id        = var.aks_subnet_id
  auto_scaling_enabled  = true
  min_count             = var.user_node_min_count
  max_count             = var.user_node_max_count
  os_disk_size_gb       = 64
  max_pods              = 50
  mode                  = "User"
  tags                  = var.tags

  node_labels = {
    "workload-type" = "application"
  }

  lifecycle {
    ignore_changes = [node_count]
  }
}
