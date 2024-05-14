# Get public IP
# https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http
data "http" "icanhazip" {
  url = "http://icanhazip.com"
}

#--------------------------------------------------------------
#   Data collection of Hub Landing Zone resources (ST, LAW, KV)
#--------------------------------------------------------------
#   ===========   From Management subscription   ===========
#   / s1-hub-sharedsvc | Key Vaults
data "azurerm_key_vault" "main_region_hub_kv" {
  provider = azurerm.s1-management

  name                = split("/", var.main_region_hub_kv_id)[8]
  resource_group_name = split("/", var.main_region_hub_kv_id)[4]
}
#   / s1-hub-logsdiag | Logs/Diag Storage Account Main region
data "azurerm_storage_account" "main_region_logdiag_stacct" {
  provider = azurerm.s1-management

  name                = split("/", var.main_region_logdiag_storacct_id)[8]
  resource_group_name = split("/", var.main_region_logdiag_storacct_id)[4]
}
#   / s1-hub-logsdiag | Log Analytics Workspace Main region
data "azurerm_log_analytics_workspace" "main_region_logdiag_law" {
  provider = azurerm.s1-management

  name                = split("/", var.main_region_hub_law_id)[8]
  resource_group_name = split("/", var.main_region_hub_law_id)[4]
}

#   / s1-hub-jumpboxes  | Jumpboxes Resource Group
data "azurerm_resource_group" "hub_jumpboxes_rg" {
  provider = azurerm.s1-management

  count = var.peer_to_hub_vnet && (var.hub_jumpboxes_rg_name != null) ? 1 : 0

  name = var.hub_jumpboxes_rg_name
}
#   / s1-hub-jumpboxes  | Jumpboxes Route Tables
data "azurerm_resources" "hub_jumpboxes_routetables" {
  provider = azurerm.s1-management

  count = var.peer_to_hub_vnet && (var.hub_jumpboxes_rg_name != null) ? 1 : 0

  resource_group_name = data.azurerm_resource_group.hub_jumpboxes_rg[0].name
  type                = "Microsoft.Network/routeTables"
}

#   / s1-hub-jumpboxes  | Jumpboxes VNet
data "azurerm_resources" "hub_jumpboxes_vnet" {
  provider = azurerm.s1-management

  count = var.peer_to_hub_vnet && (var.hub_jumpboxes_rg_name != null) ? 1 : 0

  resource_group_name = data.azurerm_resource_group.hub_jumpboxes_rg[0].name
  type                = "Microsoft.Network/virtualNetworks"
}
data "azurerm_virtual_network" "hub_jumpboxes_vnet" {
  provider = azurerm.s1-management

  count = var.peer_to_hub_vnet && (var.hub_jumpboxes_rg_name != null) ? 1 : 0

  name                = data.azurerm_resources.hub_jumpboxes_vnet[0].resources[0].name
  resource_group_name = data.azurerm_resource_group.hub_jumpboxes_rg[0].name
}


#   ===========   From Connectivity subscription   ===========
#   / s2-hub-networking | Resource Group
data "azurerm_resource_group" "hub_vnet_rg" {
  provider = azurerm.s2-connectivity

  count = var.peer_to_hub_vnet ? 1 : 0

  name = split("/", var.main_region_hub_vnet_id)[4]
}
#   / s2-hub-networking | Hub VNet
data "azurerm_virtual_network" "main_region_hub_vnet" {
  provider = azurerm.s2-connectivity

  count = var.peer_to_hub_vnet ? 1 : 0

  name                = split("/", var.main_region_hub_vnet_id)[8]
  resource_group_name = split("/", var.main_region_hub_vnet_id)[4]
}
#   / s2-hub-privdns-pe | Private DNS Resource Group
data "azurerm_resource_group" "hub_pdns_rg" {
  provider = azurerm.s2-connectivity

  count = var.peer_to_hub_vnet && var.use_hub_privdns ? 1 : 0

  name = var.hub_privdns_pe_rg_name
}
#   / s2-hub-privdns-pe | Private DNS Virtual Machine Scale Sets
data "azurerm_resources" "hub_pdns_vmsss" {
  provider = azurerm.s2-connectivity

  count = var.peer_to_hub_vnet && var.use_hub_privdns ? 1 : 0

  resource_group_name = data.azurerm_resource_group.hub_pdns_rg[0].name
  type                = "Microsoft.Compute/virtualMachineScaleSets"
}
#   / s2-hub-privdns-pe | Private DNS Virtual Machine Scale Set
data "azurerm_virtual_machine_scale_set" "hub_pdns_vmsss" {
  provider = azurerm.s2-connectivity

  count = var.peer_to_hub_vnet && var.use_hub_privdns ? 1 : 0

  name                = data.azurerm_resources.hub_pdns_vmsss[0].resources[0].name
  resource_group_name = data.azurerm_resource_group.hub_pdns_rg[0].name
}
#   / s2-hub-privdns-pe | Private DNS Route Tables
data "azurerm_resources" "hub_pdns_routetables" {
  provider = azurerm.s2-connectivity

  count = var.peer_to_hub_vnet && var.use_hub_privdns ? 1 : 0

  resource_group_name = data.azurerm_resource_group.hub_pdns_rg[0].name
  type                = "Microsoft.Network/routeTables"
}
#   / s2-hub-privdns-pe | VNet
data "azurerm_resources" "hub_pdns_vnet" {
  provider = azurerm.s2-connectivity

  count = var.peer_to_hub_vnet && var.use_hub_privdns ? 1 : 0

  resource_group_name = data.azurerm_resource_group.hub_pdns_rg[0].name
  type                = "Microsoft.Network/virtualNetworks"
}
data "azurerm_virtual_network" "hub_pdns_vnet" {
  provider = azurerm.s2-connectivity

  count = var.peer_to_hub_vnet && var.use_hub_privdns ? 1 : 0

  name                = data.azurerm_resources.hub_pdns_vnet[0].resources[0].name
  resource_group_name = data.azurerm_resource_group.hub_pdns_rg[0].name
}

