variable "project" {
  description = "Short project identifier used in resource names."
  type        = string
  default     = "aksplat"
}

variable "environment" {
  description = "Environment name (dev, prod, ...)."
  type        = string
}

variable "location" {
  description = "Azure region for all resources in this environment."
  type        = string
  default     = "eastus2"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster."
  type        = string
  default     = "1.29"
}

# ---- Networking -------------------------------------------------------------
variable "vnet_address_space" {
  description = "Address space for the virtual network."
  type        = list(string)
}

variable "aks_subnet_prefixes" {
  description = "CIDR prefixes for the AKS node subnet."
  type        = list(string)
}

variable "network_policy" {
  description = "Network policy engine (azure or calico)."
  type        = string
  default     = "calico"
}

# ---- Node pools -------------------------------------------------------------
variable "system_node_min_count" {
  type    = number
  default = 2
}

variable "system_node_max_count" {
  type    = number
  default = 3
}

variable "system_node_vm_size" {
  type    = string
  default = "Standard_D2s_v5"
}

variable "user_node_min_count" {
  type    = number
  default = 1
}

variable "user_node_max_count" {
  type    = number
  default = 3
}

variable "user_node_vm_size" {
  type    = string
  default = "Standard_D2s_v5"
}

# ---- Access -----------------------------------------------------------------
variable "admin_group_object_ids" {
  description = "Azure AD group object IDs granted cluster-admin."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Base tags applied to all resources."
  type        = map(string)
  default     = {}
}
