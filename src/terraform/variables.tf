# Subscription with Management resource(s) (Jumpboxes, Key vault, LAW) (S1)
variable "mgmt_subsc_id" {}
variable "main_region_hub_kv_id" {}
variable "main_region_logdiag_storacct_id" {}
variable "main_region_hub_law_id" {}
# Set a value to wire to Hub Jumpboxes VNet
variable "hub_jumpboxes_rg_name" { default = null }

# Subscription with Connectivity resource(s) (Public DNS Zone) (S2)
variable "conn_subsc_id" {}
variable "conn_client_id" {}
variable "conn_client_secret" {}
variable "public_dns_zone_id" {}
variable "main_region_hub_vnet_id" {}
variable "hub_privdns_pe_rg_name" {}
variable "peer_to_hub_vnet" {
  default     = false
  type        = bool
  description = "Set to TRUE to wire to Hub VNet"
}
variable "use_hub_privdns" {
  default     = false
  type        = bool
  description = "Set to TRUE to wire to Hub Private DNS PE VNet & DNS Servers"
}

###########   Workload settings   ###########

# Subscription to deploy to
variable "tenant_id" {}
variable "subsc_id" {}
variable "client_id" {}
variable "client_secret" {}
variable "aks_admins_group" {}

# Base settings
variable "res_suffix" {}
variable "loc_sub" {}
variable "location" {}

variable "vnet_address_space" {}
variable "azure_tags_json_file_path" {
  type        = string
  description = "Location of the downloaded file from this URL: https://www.microsoft.com/en-us/download/details.aspx?id=56519"
}

# # TLS Certificate
# variable "pfx_cert_name" {}
# variable "pfx_cert_password" {}

