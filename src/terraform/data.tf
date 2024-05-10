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
#   / s1-hub-logsdiag | Boot Diagnostics Storage Account Main region
data "azurerm_storage_account" "main_region_logdiag_stacct" {
  provider = azurerm.s1-management

  name                = split("/", var.main_region_logdiag_storacct_id)[8]
  resource_group_name = split("/", var.main_region_logdiag_storacct_id)[4]
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










# # Get the Azure Public DNS Zone to create the AFD Endpoints CNAME records
# data "azurerm_dns_zone" "public_dns_zone" {
#   provider = azurerm.s2-connectivity

#   name                = split("/", var.public_dns_zone_id)[8]
#   resource_group_name = split("/", var.public_dns_zone_id)[4]
# }

# # Gather the Diagnostic categories for the selected resources
# data "azurerm_monitor_diagnostic_categories" "diag_cat_afd" {
#   resource_id = azurerm_cdn_frontdoor_profile.this.id
# }
# data "azurerm_monitor_diagnostic_categories" "diag_cat_aks" {
#   depends_on = [azurerm_kubernetes_cluster.this]
#   count      = local.deploy_aks ? 1 : 0

#   resource_id = azurerm_kubernetes_cluster.this.0.id
# }


# # Allows to get the Public IP of the Public Ingress controller
# data "kubernetes_service_v1" "public_ingress_svc" {
#   depends_on = [helm_release.public_ingress_controller]

#   count = local.deploy_option1 ? 1 : 0

#   metadata {
#     name      = "${local.public_ingress_name}-ingress-nginx-controller"
#     namespace = local.public_ingress_name
#   }
# }

# # Allows to get the Private IP of the Internal Ingress controller on the ilb-subnet
# data "kubernetes_service_v1" "internal_ingress_svc" {
#   depends_on = [helm_release.internal_ingress_controller]

#   count = local.deploy_option2 ? 1 : 0

#   metadata {
#     name      = "${local.internal_ingress_name}-ingress-nginx-controller"
#     namespace = local.internal_ingress_name
#   }
# }
