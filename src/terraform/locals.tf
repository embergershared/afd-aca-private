locals {
  public_ip = chomp(data.http.icanhazip.response_body)

  # Extracting s1-management subscription Id from Hub Key vault Id
  management_subsc_id = split("/", var.main_region_hub_kv_id)[2]
  hub_vms_cidr        = var.peer_to_hub_vnet && (var.hub_jumpboxes_rg_name != null) ? data.azurerm_virtual_network.hub_jumpboxes_vnet[0].address_space[0] : null

  # Extracting s2-connectivity subscription Id from Hub VNet Id
  connectivity_subsc_id = split("/", var.main_region_hub_vnet_id)[2]
  hub_privdns_pe_cidr   = var.peer_to_hub_vnet && var.use_hub_privdns ? data.azurerm_virtual_network.hub_pdns_vnet[0].address_space[0] : null

  # Getting Private DNS Forwarders IPs
  dns_forwarders_ips = try(concat(
    [for k, v in data.azurerm_virtual_machine_scale_set.hub_pdns_vmsss[0].instances : v.private_ip_address],
    # ["168.63.129.16"], # Azure default = "168.63.129.16"
  ), null)


  # Base resources Tags
  UTC_to_TZ      = "-5h" # Careful to factor DST
  TZ_suffix      = "EST"
  created_TZtime = timeadd(local.created_now, local.UTC_to_TZ)
  created_now    = time_static.this.rfc3339
  created_nowTZ  = "${formatdate("YYYY-MM-DD hh:mm", local.created_TZtime)} ${local.TZ_suffix}" # 2020-06-16 14:44 EST

  base_tags = tomap({
    "Created_with"     = "Terraform v1.8.2 on windows_amd64",
    "Created_on"       = "${local.created_nowTZ}",
    "Initiated_by"     = "Manually",
    "GiHub_repo"       = "https://github.com/embergershared/aks-aca-private",
    "Subscription"     = "s4",
    "Terraform_state"  = "tfstates-s4-spokes/aks-aca-private",
    "Terraform_plan"   = "embergershared/aks-aca-private/src/terraform/main.tf",
    "Terraform_values" = "embergershared/aks-aca-private/src/terraform/secret.auto.tfvars",
  })

  # Get Azure Service Tags IPs for "AzureFrontDoor.Backend"
  az_service_tags  = jsondecode(file("${var.azure_tags_json_file_path}"))
  afd_ip_ranges    = [for el in local.az_service_tags.values : el.properties.addressPrefixes if el.name == "AzureFrontDoor.Backend"][0]
  afd_ip_v4_ranges = [for cidr in local.afd_ip_ranges : cidr if can(cidrnetmask(cidr))] # OR can(regex("^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$",cidr))
}
