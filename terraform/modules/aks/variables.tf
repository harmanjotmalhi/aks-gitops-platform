variable "name_prefix" {
  description = "Prefix applied to AKS resource names (e.g. aksplat-dev)."
  type        = string
}

variable "location" {
  description = "Azure region for the AKS cluster."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that will contain the AKS cluster."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the control plane and default node pool."
  type        = string
  default     = "1.29"
}

variable "dns_prefix" {
  description = "DNS prefix for the AKS API server."
  type        = string
}

variable "aks_subnet_id" {
  description = "Resource ID of the subnet where node pools are placed."
  type        = string
}

# ---- System node pool -------------------------------------------------------
variable "system_node_count" {
  description = "Node count for the system node pool when autoscaling is disabled."
  type        = number
  default     = 2
}

variable "system_node_min_count" {
  description = "Minimum nodes for the system pool when autoscaling is enabled."
  type        = number
  default     = 2
}

variable "system_node_max_count" {
  description = "Maximum nodes for the system pool when autoscaling is enabled."
  type        = number
  default     = 3
}

variable "system_node_vm_size" {
  description = "VM size for the system node pool."
  type        = string
  default     = "Standard_D2s_v5"
}

# ---- User node pool ---------------------------------------------------------
variable "user_node_min_count" {
  description = "Minimum nodes for the user (application) pool."
  type        = number
  default     = 1
}

variable "user_node_max_count" {
  description = "Maximum nodes for the user (application) pool."
  type        = number
  default     = 5
}

variable "user_node_vm_size" {
  description = "VM size for the user node pool."
  type        = string
  default     = "Standard_D2s_v5"
}

# ---- Networking -------------------------------------------------------------
variable "service_cidr" {
  description = "CIDR used for Kubernetes service IPs (must not overlap the VNet)."
  type        = string
  default     = "10.30.0.0/16"
}

variable "dns_service_ip" {
  description = "IP address within service_cidr used by kube-dns / CoreDNS."
  type        = string
  default     = "10.30.0.10"
}

variable "network_policy" {
  description = "Network policy engine (azure or calico)."
  type        = string
  default     = "calico"
}

# ---- Access control ---------------------------------------------------------
variable "admin_group_object_ids" {
  description = "Azure AD group object IDs granted cluster-admin via AKS-managed Azure AD."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to the AKS cluster."
  type        = map(string)
  default     = {}
}
