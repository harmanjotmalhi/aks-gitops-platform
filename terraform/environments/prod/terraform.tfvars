environment = "prod"
location    = "eastus2"

kubernetes_version = "1.29"

# Networking — distinct address space to allow future VNet peering
vnet_address_space  = ["10.40.0.0/16"]
aks_subnet_prefixes = ["10.40.1.0/24"]
network_policy      = "calico"

# Node pools — sized for availability and headroom in prod
system_node_min_count = 3
system_node_max_count = 5
system_node_vm_size   = "Standard_D4s_v5"

user_node_min_count = 3
user_node_max_count = 10
user_node_vm_size   = "Standard_D4s_v5"

# REQUIRED in prod: restrict cluster-admin to a dedicated Azure AD group
admin_group_object_ids = []

tags = {
  cost_center = "platform-prod"
  owner       = "platform-team"
  compliance  = "required"
}
