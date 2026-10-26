output "resource_group_name" {
  description = "Name of the environment resource group."
  value       = azurerm_resource_group.main.name
}

output "cluster_name" {
  description = "AKS cluster name — use with 'az aks get-credentials'."
  value       = module.aks.cluster_name
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL for workload identity federation."
  value       = module.aks.oidc_issuer_url
}

output "get_credentials_command" {
  description = "Convenience command to fetch the kubeconfig."
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${module.aks.cluster_name}"
}
