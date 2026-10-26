variable "name_prefix" {
  description = "Prefix applied to all networking resource names (e.g. aksplat-dev)."
  type        = string
}

variable "location" {
  description = "Azure region where networking resources are created."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group that will contain the networking resources."
  type        = string
}

variable "vnet_address_space" {
  description = "Address space (CIDR blocks) for the virtual network."
  type        = list(string)
  default     = ["10.20.0.0/16"]
}

variable "aks_subnet_prefixes" {
  description = "CIDR prefixes for the AKS node subnet."
  type        = list(string)
  default     = ["10.20.1.0/24"]
}

variable "ingress_subnet_prefixes" {
  description = "CIDR prefixes for the ingress / application gateway subnet."
  type        = list(string)
  default     = ["10.20.2.0/24"]
}

variable "tags" {
  description = "Tags applied to all networking resources."
  type        = map(string)
  default     = {}
}
