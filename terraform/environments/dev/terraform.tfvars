environment = "dev"
location    = "eastus2"

kubernetes_version = "1.29"

# Networking
vnet_address_space  = ["10.20.0.0/16"]
aks_subnet_prefixes = ["10.20.1.0/24"]
network_policy      = "calico"

# Node pools — small/cost-optimized for dev
system_node_min_count = 1
system_node_max_count = 2
system_node_vm_size   = "Standard_D2s_v5"

user_node_min_count = 1
user_node_max_count = 3
user_node_vm_size   = "Standard_D2s_v5"

# Populate with your Azure AD admin group object ID(s)
admin_group_object_ids = []

tags = {
  cost_center = "platform-dev"
  owner       = "platform-team"
}
