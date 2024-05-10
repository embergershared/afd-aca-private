# Subscription to deploy to
variable "tenant_id" {}
variable "subsc_id" {}
variable "client_id" {}
variable "client_secret" {}
variable "aks_admins_group" {}


# Subscription with the Management resource(s) (Jumpboxes, Key vault, LAW) (S1)
variable "mgmt_subsc_id" {}
variable "main_region_hub_kv_id" {}
variable "main_region_logdiag_storacct_id" {}

# Subscription with the connectivity resource(s) (Public DNS Zone) (S2)
variable "conn_subsc_id" {}
variable "conn_client_id" {}
variable "conn_client_secret" {}
variable "public_dns_zone_id" {}
variable "main_region_hub_vnet_id" {}
variable "hub_privdns_pe_rg_name" {}



# Set to TRUE to wire to Hub VNet
variable "peer_to_hub_vnet" {
  default = false
  type    = bool
}

# Set a value to wire to Hub Jumpboxes VNet
variable "hub_jumpboxes_rg_name" { default = null }

# Set to TRUE to wire to Hub Private DNS PE VNet & DNS Servers
variable "use_hub_privdns" {
  default = false
  type    = bool
}

variable "vnet_address_space" {}



# # 2 steps deployment control
# variable "is_ready_to_deploy_origins" {
#   type    = bool
#   default = false
# }

# Base settings
variable "res_suffix" {}
variable "loc_sub" {}
variable "location" {}

# # TLS Certificate
# variable "pfx_cert_name" {}
# variable "pfx_cert_password" {}

