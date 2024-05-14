# Description   : This Terraform creates an ACA in an Application Landing Zone
#                 It deploys:
#                   - 1 App Resource Group,
#                   - 1 VNet + 2 subnets
#                   - VNet peerings to Hub (if set to true)
#                   - Routing to Hub Private DNS Forwarders (if var.hub_privdns_pe_rg_name != null)
#                   - Routing to Hub Jumpboxes (if var.hub_jumpboxes_rg_name != null)
#                   - 1 Azure Container App Environment External
#                   - 1 Azure Container App Environment Internal
#                   - 1 Azure Container App in each
#                   - 1 Azure Front Door Profile with 1 Endpoint, 1 Origin Group, 1 Origin, and 1 Route


# Folder/File   : 
# Terraform     : 1.0.+
# Providers     : azurerm 3.+
# Plugins       : none
# Modules       : none
#
# Created on    : 2024-05-09
# Created by    : Emmanuel
# Last Modified : 2024-05-13
# Last Modif by : Emmanuel
# Modif desc.   : Added the Azure Front Door resources + testing


#--------------------------------------------------------------
#   Basics
#--------------------------------------------------------------
# Random string for resources
resource "random_string" "this" {
  length    = 4
  lower     = true
  upper     = false
  numeric   = false
  special   = false
  min_lower = 4
}
# Timestamp for the Created_on tag
resource "time_static" "this" {}

#--------------------------------------------------------------
#   App Landing Zone
#--------------------------------------------------------------
#   App Landing Zone Main resources
#   / Main region App LZ Resource Group
resource "azurerm_resource_group" "this" {
  name     = "rg-${var.loc_sub}-${var.res_suffix}"
  location = var.location

  tags = local.base_tags
}
#   / Main region App LZ VNet
resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.loc_sub}-${var.res_suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.vnet_address_space]

  tags = azurerm_resource_group.this.tags
}
#   / Subnets
#     / For ACA Environments
resource "azurerm_subnet" "acaenv_pub_subnet" {
  name                                          = "acaenv-pub-snet"
  resource_group_name                           = azurerm_resource_group.this.name
  virtual_network_name                          = azurerm_virtual_network.this.name
  private_endpoint_network_policies             = "Disabled"
  private_link_service_network_policies_enabled = false
  address_prefixes                              = [replace(var.vnet_address_space, "0/25", "0/27")]

  service_endpoints = [
    "Microsoft.KeyVault",
  ]
  delegation {
    name = "Microsoft.App.environments"
    service_delegation {
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
      name = "Microsoft.App/environments"
    }
  }
}
resource "azurerm_subnet" "acaenv_priv_subnet" {
  name                                          = "acaenv-priv-snet"
  resource_group_name                           = azurerm_resource_group.this.name
  virtual_network_name                          = azurerm_virtual_network.this.name
  private_endpoint_network_policies             = "Disabled"
  private_link_service_network_policies_enabled = false
  address_prefixes                              = [replace(var.vnet_address_space, "0/25", "32/27")]

  service_endpoints = [
    "Microsoft.KeyVault",
  ]
  delegation {
    name = "Microsoft.App.environments"
    service_delegation {
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
      name = "Microsoft.App/environments"
    }
  }
}
#     / For Private Endpoints
resource "azurerm_subnet" "pe_subnet" {
  name                                          = "pe-snet"
  resource_group_name                           = azurerm_resource_group.this.name
  virtual_network_name                          = azurerm_virtual_network.this.name
  private_endpoint_network_policies             = "Enabled"
  private_link_service_network_policies_enabled = false
  address_prefixes                              = [replace(var.vnet_address_space, "0/25", "64/28")]
}
#   / NSGs
#     / For ACA Environment public subnet
resource "azurerm_network_security_group" "acaenv_pub_subnet_nsg" {
  name = lower("nsg-${azurerm_subnet.acaenv_pub_subnet.name}")

  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  tags = azurerm_resource_group.this.tags
}
#     / Association to ACA Environment public subnet
resource "azurerm_subnet_network_security_group_association" "acaenv_pub_subnet_to_nsg_association" {
  subnet_id                 = azurerm_subnet.acaenv_pub_subnet.id
  network_security_group_id = azurerm_network_security_group.acaenv_pub_subnet_nsg.id
}
#     / For ACA Environment private subnet
resource "azurerm_network_security_group" "acaenv_priv_subnet_nsg" {
  name = lower("nsg-${azurerm_subnet.acaenv_priv_subnet.name}")

  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  tags = azurerm_resource_group.this.tags
}
#     / Association to ACA Environment private subnet
resource "azurerm_subnet_network_security_group_association" "acaenv_priv_subnet_to_nsg_association" {
  subnet_id                 = azurerm_subnet.acaenv_priv_subnet.id
  network_security_group_id = azurerm_network_security_group.acaenv_priv_subnet_nsg.id
}
#     / For Private Endpoints' subnet
resource "azurerm_network_security_group" "pe_subnet_nsg" {
  name = lower("nsg-${azurerm_subnet.pe_subnet.name}")

  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  tags = azurerm_resource_group.this.tags
}
#     / Association to Private Endpoints' subnet
resource "azurerm_subnet_network_security_group_association" "pe_subnet_to_nsg_association" {
  subnet_id                 = azurerm_subnet.pe_subnet.id
  network_security_group_id = azurerm_network_security_group.pe_subnet_nsg.id
}

#   App Landing Zone Peering to Hub
#   / Main region App LZ VNet peering to Hub VNet
resource "azurerm_virtual_network_peering" "main_region_applz_vnet_to_hub_peering" {
  count = var.peer_to_hub_vnet ? 1 : 0

  name = lower("peering-to-s2-hub-networking")

  # From
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name

  # To
  remote_virtual_network_id = data.azurerm_virtual_network.main_region_hub_vnet[0].id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = true
}
resource "azurerm_virtual_network_peering" "hub_to_main_region_applz_vnet_peering" {
  provider = azurerm.s2-connectivity

  count = var.peer_to_hub_vnet ? 1 : 0

  name = lower("peering-to-s4-${replace("${azurerm_virtual_network.this.name}", "vnet-${var.loc_sub}-", "")}")

  # From
  resource_group_name  = data.azurerm_virtual_network.main_region_hub_vnet[0].resource_group_name
  virtual_network_name = data.azurerm_virtual_network.main_region_hub_vnet[0].name

  # To
  remote_virtual_network_id = azurerm_virtual_network.this.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  use_remote_gateways          = false
}
#   / Main region App LZ VNet Route Table
resource "azurerm_route_table" "applz_wkld_subnet_rt" {
  count = var.peer_to_hub_vnet ? 1 : 0

  name                          = replace(azurerm_resource_group.this.name, "rg", "rt")
  location                      = azurerm_resource_group.this.location
  resource_group_name           = azurerm_resource_group.this.name
  disable_bgp_route_propagation = false

  tags = azurerm_resource_group.this.tags
}
resource "azurerm_subnet_route_table_association" "applz_wkld_subnet_rt_association" {
  count = var.peer_to_hub_vnet ? 1 : 0

  subnet_id      = azurerm_subnet.acaenv_pub_subnet.id
  route_table_id = azurerm_route_table.applz_wkld_subnet_rt[0].id
}
#   / Main region App LZ Routes to Hub Jumpboxes and Private DNS
resource "azurerm_route" "applz_to_jumpboxes_vnet_route" {
  count = var.peer_to_hub_vnet && (var.hub_jumpboxes_rg_name != null) ? 1 : 0

  name                = "Hub-s1-Jumpboxes-VNet"
  resource_group_name = azurerm_resource_group.this.name
  route_table_name    = azurerm_route_table.applz_wkld_subnet_rt[0].name
  address_prefix      = local.hub_vms_cidr
  next_hop_type       = "VirtualNetworkGateway"
}
resource "azurerm_route" "applz_to_pdns_vnet_route" {
  count = var.peer_to_hub_vnet && var.use_hub_privdns ? 1 : 0

  name                = "Hub-s2-PrivateDNS-VNet"
  resource_group_name = azurerm_resource_group.this.name
  route_table_name    = azurerm_route_table.applz_wkld_subnet_rt[0].name
  address_prefix      = local.hub_privdns_pe_cidr
  next_hop_type       = "VirtualNetworkGateway"
}
#   / Main region App LZ VNet to use Private DNS Forwarders servers
resource "azurerm_virtual_network_dns_servers" "hub_vms_vnet_dns_servers" {
  count = var.peer_to_hub_vnet && var.use_hub_privdns ? 1 : 0

  virtual_network_id = azurerm_virtual_network.this.id
  dns_servers        = local.dns_forwarders_ips
}

#   / Main region Hub Private DNS Route to App LZ
resource "azurerm_route" "hub_pdns_to_applz_vnet_route" {
  provider = azurerm.s2-connectivity

  count = var.peer_to_hub_vnet && var.use_hub_privdns ? 1 : 0

  name                = "Spoke-s4-${title(replace("${azurerm_virtual_network.this.name}", "vnet-${var.loc_sub}-", ""))}-VNet"
  resource_group_name = data.azurerm_resource_group.hub_pdns_rg[0].name
  route_table_name    = data.azurerm_resources.hub_pdns_routetables[0].resources[0].name
  address_prefix      = var.vnet_address_space
  next_hop_type       = "VirtualNetworkGateway"
}
#   / Main region Hub Jumpboxes Route to App LZ
resource "azurerm_route" "hub_jumpboxes_to_applz_vnet_route" {
  provider = azurerm.s1-management

  count = var.peer_to_hub_vnet && (var.hub_jumpboxes_rg_name != null) ? 1 : 0

  name                = "Spoke-s4-${title(replace("${azurerm_virtual_network.this.name}", "vnet-${var.loc_sub}-", ""))}-VNet"
  resource_group_name = data.azurerm_resource_group.hub_jumpboxes_rg[0].name
  route_table_name    = data.azurerm_resources.hub_jumpboxes_routetables[0].resources[0].name
  address_prefix      = var.vnet_address_space
  next_hop_type       = "VirtualNetworkGateway"
}


#--------------------------------------------------------------
#   Azure Container App resources
#--------------------------------------------------------------
/*
###  External Azure Container App (default networking)
resource "azurerm_container_app_environment" "pub_def_env" {
  name                = "aca-env-pub-def-${var.res_suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  infrastructure_resource_group_name = "${azurerm_resource_group.this.name}-infra-pub-def"
  internal_load_balancer_enabled     = null
  infrastructure_subnet_id           = null
  zone_redundancy_enabled            = null
  docker_bridge_cidr                 = null
  platform_reserved_cidr             = null
  platform_reserved_dns_ip_address   = null
  log_analytics_workspace_id         = data.azurerm_log_analytics_workspace.main_region_logdiag_law.id

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }

  tags = azurerm_resource_group.this.tags
  # Id Format: "/subscriptions/<sub number>/resourceGroups/<rg name>/providers/Microsoft.App/managedEnvironments/aca-env-pub"
}
resource "azurerm_container_app" "pub_def_app" {
  name                         = substr("aca-app-pub-def-${var.res_suffix}", 0, 32)
  container_app_environment_id = azurerm_container_app_environment.pub_def_env.id
  resource_group_name          = azurerm_resource_group.this.name
  revision_mode                = "Multiple"

  workload_profile_name = "Consumption"

  template {
    min_replicas = 1
    # revision_suffix = "fixv8qj" # Must NOT be set during creation
    container {
      name   = "simple-hello-world-container"
      image  = "mcr.microsoft.com/k8se/quickstart:latest"
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }

  ingress {
    allow_insecure_connections = false
    external_enabled           = true
    target_port                = 80
    transport                  = "http" # "auto"

    traffic_weight {
      latest_revision = true # required during creation
      # latest_revision = false
      # revision_suffix = "fixv8qj" # Must NOT be set during creation
      percentage = 100
    }

    dynamic "ip_security_restriction" {
      for_each = local.afd_ip_v4_ranges
      content {
        action           = "Allow"
        description      = "ServiceTags_Public_20240506.json"
        ip_address_range = ip_security_restriction.value
        name             = "AzureFrontDoor.Backend"
      }
    }
  }
}
/*
resource "azurerm_container_app_job" "pub_def_job" {
  # In PR: https://github.com/hashicorp/terraform-provider-azurerm/pull/23871
  # Requires "hashicorp/azurerm >= 3.103"
  name                         = "aca-pub-job-s4-${var.res_suffix}"
  container_app_environment_id = azurerm_container_app_environment.pub_def_env.id
  resource_group_name          = azurerm_resource_group.this.name
  location                     = azurerm_resource_group.this.location

  workload_profile_name      = "Consumption"
  replica_timeout_in_seconds = 1800

  manual_trigger_config {
    parallelism              = 1
    replica_completion_count = 1
  }

  template {
    container {
      name    = "aca-job-s4-afd-aca-priv-01"
      image   = "docker.io/hello-world:latest"
      cpu     = 0.5
      memory  = "1Gi"
      command = ["/bin/bash", "-c", "echo hello; sleep 100000"]
    }
  }
}
#*/

###  External Azure Container App with custom VNet
resource "azurerm_container_app_environment" "pub_vnet_env" {
  name                = "aca-env-pub-vnet-${var.res_suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  infrastructure_resource_group_name = "${azurerm_resource_group.this.name}-infra-pub-vnet"
  internal_load_balancer_enabled     = false
  infrastructure_subnet_id           = azurerm_subnet.acaenv_pub_subnet.id
  zone_redundancy_enabled            = false
  docker_bridge_cidr                 = null
  platform_reserved_cidr             = null
  platform_reserved_dns_ip_address   = null
  log_analytics_workspace_id         = data.azurerm_log_analytics_workspace.main_region_logdiag_law.id

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }

  tags = azurerm_resource_group.this.tags
  # Id Format: "/subscriptions/<sub number>/resourceGroups/<rg name>/providers/Microsoft.App/managedEnvironments/aca-env-pub"
}
resource "azurerm_container_app" "pub_vnet_app" {
  name                         = substr("aca-app-pub-vnet-${var.res_suffix}", 0, 32)
  container_app_environment_id = azurerm_container_app_environment.pub_vnet_env.id
  resource_group_name          = azurerm_resource_group.this.name
  revision_mode                = "Multiple"

  workload_profile_name = "Consumption"

  template {
    min_replicas = 1
    # revision_suffix = "fixv8qj" # Must NOT be set during creation
    container {
      name   = "simple-hello-world-container"
      image  = "mcr.microsoft.com/k8se/quickstart:latest"
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }

  ingress {
    allow_insecure_connections = false
    external_enabled           = true
    target_port                = 80
    transport                  = "http" # "auto"

    traffic_weight {
      latest_revision = true # required during creation
      # latest_revision = false
      # revision_suffix = "fixv8qj" # Must NOT be set during creation
      percentage = 100
    }

    dynamic "ip_security_restriction" {
      for_each = local.afd_ip_v4_ranges
      content {
        action           = "Allow"
        description      = "ServiceTags_Public_20240506.json"
        ip_address_range = ip_security_restriction.value
        name             = "AzureFrontDoor.Backend"
      }
    }
  }
}
/*
resource "azurerm_container_app_job" "pub_vnet_job" {
  # In PR: https://github.com/hashicorp/terraform-provider-azurerm/pull/23871
  # Requires "hashicorp/azurerm >= 3.103"
  name                         = "aca-pub-job-s4-${var.res_suffix}"
  container_app_environment_id = azurerm_container_app_environment.pub_vnet_env.id
  resource_group_name          = azurerm_resource_group.this.name
  location                     = azurerm_resource_group.this.location

  workload_profile_name      = "Consumption"
  replica_timeout_in_seconds = 1800

  manual_trigger_config {
    parallelism              = 1
    replica_completion_count = 1
  }

  template {
    container {
      name    = "aca-job-s4-afd-aca-priv-01"
      image   = "docker.io/hello-world:latest"
      cpu     = 0.5
      memory  = "1Gi"
      command = ["/bin/bash", "-c", "echo hello; sleep 100000"]
    }
  }
}
#*/

###  Internal Azure Container App with VNet integration
resource "azurerm_container_app_environment" "priv_env" {
  name                = "aca-env-priv-${var.res_suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  infrastructure_resource_group_name = "${azurerm_resource_group.this.name}-infra-priv"
  infrastructure_subnet_id           = azurerm_subnet.acaenv_priv_subnet.id # Must be /21 or larger
  internal_load_balancer_enabled     = true
  zone_redundancy_enabled            = false
  docker_bridge_cidr                 = null
  platform_reserved_cidr             = null
  platform_reserved_dns_ip_address   = null

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }

  tags = azurerm_resource_group.this.tags
}
resource "azurerm_container_app" "priv_app" {
  name                         = substr("aca-app-priv-${var.res_suffix}", 0, 32)
  container_app_environment_id = azurerm_container_app_environment.priv_env.id
  resource_group_name          = azurerm_resource_group.this.name
  revision_mode                = "Multiple"

  workload_profile_name = "Consumption"

  template {
    min_replicas = 1
    # revision_suffix = "fixv8qj" # Must NOT be set during creation
    container {
      name   = "simple-hello-world-container"
      image  = "mcr.microsoft.com/k8se/quickstart:latest"
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }

  ingress {
    allow_insecure_connections = false
    external_enabled           = true # To allow connection from the VNet
    target_port                = 80
    transport                  = "http" # "auto"

    traffic_weight {
      latest_revision = true # required during creation
      # latest_revision = false
      # revision_suffix = "fixv8qj" # Must NOT be set during creation
      percentage = 100
    }
  }
}
/*
resource "azurerm_container_app_job" "priv_job" {
  # In PR: https://github.com/hashicorp/terraform-provider-azurerm/pull/23871
  # Requires "hashicorp/azurerm >= 3.103"
  name                         = "aca-priv-job-s4-${var.res_suffix}"
  container_app_environment_id = azurerm_container_app_environment.priv_env.id
  resource_group_name          = azurerm_resource_group.this.name
  location                     = azurerm_resource_group.this.location

  workload_profile_name      = "Consumption"
  replica_timeout_in_seconds = 1800

  manual_trigger_config {
    parallelism              = 1
    replica_completion_count = 1
  }

  template {
    container {
      name    = "aca-job-s4-afd-aca-priv-01"
      image   = "docker.io/hello-world:latest"
      cpu     = 0.5
      memory  = "1Gi"
      command = ["/bin/bash", "-c", "echo hello; sleep 100000"]
    }
  }
}
#*/

#--------------------------------------------------------------
#   Azure Front door resources
#--------------------------------------------------------------
resource "azurerm_cdn_frontdoor_profile" "this" {
  name                = "afd-s4-${var.res_suffix}"
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = "Premium_AzureFrontDoor"

  response_timeout_seconds = 60

  tags = azurerm_resource_group.this.tags
}
resource "azurerm_cdn_frontdoor_endpoint" "this" {
  name                     = "hello-aca"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id

  tags = azurerm_resource_group.this.tags

  # Id Format: "/subscriptions/<sub number>/resourceGroups/<rg name>/providers/Microsoft.Cdn/profiles/afd-s4-afd-aca-priv-01/afdEndpoints/hello-aca"
}
# "Microsoft.Cdn/profiles/origingroups"
resource "azurerm_cdn_frontdoor_origin_group" "this" {
  name                     = "default-origin-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
  session_affinity_enabled = false

  restore_traffic_time_to_healed_or_new_endpoint_in_minutes = 0

  health_probe {
    interval_in_seconds = 30
    path                = "/"
    protocol            = "Https"
    request_type        = "GET"
  }

  load_balancing {
    additional_latency_in_milliseconds = 50
    sample_size                        = 4
    successful_samples_required        = 3
  }

  # Id Format: "/subscriptions/<sub number>/resourceGroups/<rg name>/providers/Microsoft.Cdn/profiles/afd-s4-afd-aca-priv-01/originGroups/default-origin-group"
}
# Microsoft.Cdn/profiles/origingroups/origins"
resource "azurerm_cdn_frontdoor_origin" "aca" {
  name                          = "aca-pub-aca"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.this.id
  enabled                       = true

  certificate_name_check_enabled = true

  host_name          = azurerm_container_app.pub_vnet_app.ingress[0].fqdn
  origin_host_header = azurerm_container_app.pub_vnet_app.ingress[0].fqdn
  http_port          = 80
  https_port         = 443
  priority           = 1
  weight             = 1000

  # Id format: "/subscriptions/<sub number>/resourceGroups/<rg name>/providers/Microsoft.Cdn/profiles/afd-s4-afd-aca-priv-01/originGroups/default-origin-group/origins/aca-pub"
}
# "Microsoft.Cdn/profiles/afdendpoints/routes" / hello-aca/default-route
resource "azurerm_cdn_frontdoor_route" "this" {
  name                          = "default-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.this.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.this.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.aca.id, ]
  cdn_frontdoor_rule_set_ids    = []
  enabled                       = true

  forwarding_protocol    = "MatchRequest"
  https_redirect_enabled = true
  patterns_to_match      = ["/*"]
  supported_protocols    = ["Http", "Https"]

  link_to_default_domain = true
}
#*/

