/*
--- Built-in Replacements ---
This file contains built-in replacements to avoid repeating the same hard-coded values.
Replacements are denoted by the dollar-dollar curly braces token (e.g. $${starter_location_01}). The following details each built-in replacements that you can use:
`starter_location_01`: This the primary an Azure location sourced from the `starter_locations` variable. This can be used to set the location of resources.
`starter_location_02` to `starter_location_##`: These are the secondary Azure locations sourced from the `starter_locations` variable. This can be used to set the location of resources.
`starter_location_01_short`: Short code for the primary Azure location. Defaults to the region geo_code, or short_name if no geo_code is available. Can be overridden via the starter_locations_short variable.
`starter_location_02_short` to `starter_location_##_short`: Short codes for the secondary Azure locations. Same behavior and override rules as starter_location_01_short.
`root_parent_management_group_id`: This is the id of the management group that the ALZ hierarchy will be nested under.
`subscription_id_identity`: The subscription ID of the subscription to deploy the identity resources to, sourced from the variable `subscription_ids`.
`subscription_id_connectivity`: The subscription ID of the subscription to deploy the connectivity resources to, sourced from the variable `subscription_ids`.
`subscription_id_management`: The subscription ID of the subscription to deploy the management resources to, sourced from the variable `subscription_ids`.
`subscription_id_security`: The subscription ID of the subscription to deploy the security resources to, sourced from the variable `subscription_ids`.
*/

/*
--- Starter Locations ---
You can define the Azure regions to use throughout the configuration.
The first location will be used as the primary location, the second as the secondary location, and so on.
*/
starter_locations = ["uksouth"]

/*
--- Custom Replacements ---
You can define custom replacements to use throughout the configuration.
*/
custom_replacements = {
  /*
  --- Custom Name Replacements ---
  You can define custom names and other strings to use throughout the configuration.
  You can only use the built in replacements in this section.
  NOTE: You cannot refer to another custom name in this variable.
  */
  names = {
    # Defender email security contact
    defender_email_security_contact = "simon.schwingel@gmail.com"

    # Resource group names
    management_resource_group_name               = "rg-management-$${starter_location_01}"
    connectivity_hub_primary_resource_group_name = "rg-hub-$${starter_location_01}"
    dns_resource_group_name                      = "rg-hub-dns-$${starter_location_01}"
    ddos_resource_group_name                     = "rg-hub-ddos-$${starter_location_01}"
    asc_export_resource_group_name               = "rg-asc-export-$${starter_location_01}"
    service_health_alerts_resource_group_name    = "rg-service-health-alerts-$${starter_location_01}"

    # Resource names
    log_analytics_workspace_name            = "law-management-$${starter_location_01}"
    ddos_protection_plan_name               = "ddos-$${starter_location_01}"
    ama_user_assigned_managed_identity_name = "uami-management-ama-$${starter_location_01}"
    dcr_change_tracking_name                = "dcr-change-tracking"
    dcr_defender_sql_name                   = "dcr-defender-sql"
    dcr_vm_insights_name                    = "dcr-vm-insights"

    # Resource provisioning global connectivity
    ddos_protection_plan_enabled = false

    # Resource provisioning primary connectivity
    primary_virtual_network_gateway_express_route_enabled                = false
    primary_virtual_network_gateway_express_route_hobo_public_ip_enabled = true
    primary_virtual_network_gateway_vpn_enabled                          = false
    primary_private_dns_zones_enabled                                    = true
    primary_private_dns_auto_registration_zone_enabled                   = true
    primary_private_dns_resolver_enabled                                 = true
    primary_bastion_enabled                                              = true

    # Resource names primary connectivity
    primary_virtual_network_name                                 = "vnet-hub-$${starter_location_01}"
    primary_subnet_nva_name                                      = "subnet-nva-$${starter_location_01}"
    primary_fgt_external_subnet_name                             = "subnet-fgt-ext-$${starter_location_01}"
    primary_fgt_internal_subnet_name                             = "subnet-fgt-int-$${starter_location_01}"
    primary_fgt_hasync_subnet_name                               = "subnet-fgt-hasync-$${starter_location_01}"
    primary_fgt_hamgmt_subnet_name                               = "subnet-fgt-hamgmt-$${starter_location_01}"
    primary_route_table_firewall_name                            = "rt-hub-fw-$${starter_location_01}"
    primary_route_table_user_subnets_name                        = "rt-hub-std-$${starter_location_01}"
    primary_virtual_network_gateway_express_route_name           = "vgw-hub-er-$${starter_location_01}"
    primary_virtual_network_gateway_express_route_public_ip_name = "pip-vgw-hub-er-$${starter_location_01}"
    primary_virtual_network_gateway_vpn_name                     = "vgw-hub-vpn-$${starter_location_01}"
    primary_virtual_network_gateway_vpn_public_ip_name_1         = "pip-vgw-hub-vpn-$${starter_location_01}-001"
    primary_virtual_network_gateway_vpn_public_ip_name_2         = "pip-vgw-hub-vpn-$${starter_location_01}-002"
    primary_private_dns_resolver_name                            = "pdr-hub-dns-$${starter_location_01}"
    primary_bastion_host_name                                    = "bas-hub-$${starter_location_01}"
    primary_bastion_host_public_ip_name                          = "pip-bastion-hub-$${starter_location_01}"

    # Private DNS Zones primary
    primary_auto_registration_zone_name = "$${starter_location_01}.azure.local"

    # IP Ranges Primary
    # Regional Address Space: 10.0.0.0/16
    primary_hub_address_space                 = "10.0.0.0/16"
    primary_hub_virtual_network_address_space = "10.0.0.0/22"
    primary_nva_subnet_address_prefix         = "10.0.0.0/26"
    primary_nva_ip_address                    = "10.0.0.4"
    # FortiGate A/P ELB-ILB design: four dedicated subnets in 10.0.1.0/24
    primary_fgt_external_subnet_address_prefix = "10.0.1.0/26"
    primary_fgt_internal_subnet_address_prefix = "10.0.1.64/26"
    primary_fgt_hasync_subnet_address_prefix   = "10.0.1.128/26"
    primary_fgt_hamgmt_subnet_address_prefix   = "10.0.1.192/26"
    # Internal load balancer frontend IP (spoke egress next hop) in the internal subnet
    primary_fortigate_ilb_ip                           = "10.0.1.68"
    primary_onprem_prefix_1                            = "172.16.0.0/12"
    primary_onprem_prefix_2                            = "192.168.0.0/16"
    primary_bastion_subnet_address_prefix              = "10.0.0.64/26"
    primary_gateway_subnet_address_prefix              = "10.0.0.128/27"
    primary_private_dns_resolver_subnet_address_prefix = "10.0.0.160/28"
  }

  /*
  --- Custom Resource Group Identifier Replacements ---
  You can define custom resource group identifiers to use throughout the configuration.
  You can only use the templated variables and custom names in this section.
  NOTE: You cannot refer to another custom resource group identifier in this variable.
  */
  resource_group_identifiers = {
    management_resource_group_id           = "/subscriptions/$${subscription_id_management}/resourcegroups/$${management_resource_group_name}"
    ddos_protection_plan_resource_group_id = "/subscriptions/$${subscription_id_connectivity}/resourcegroups/$${ddos_resource_group_name}"
    primary_connectivity_resource_group_id = "/subscriptions/$${subscription_id_connectivity}/resourceGroups/$${connectivity_hub_primary_resource_group_name}"
    dns_resource_group_id                  = "/subscriptions/$${subscription_id_connectivity}/resourceGroups/$${dns_resource_group_name}"
  }

  /*
  --- Custom Resource Identifier Replacements ---
  You can define custom resource identifiers to use throughout the configuration.
  You can only use the templated variables, custom names and customer resource group identifiers in this variable.
  NOTE: You cannot refer to another custom resource identifier in this variable.
  */
  resource_identifiers = {
    ama_change_tracking_data_collection_rule_id = "$${management_resource_group_id}/providers/Microsoft.Insights/dataCollectionRules/$${dcr_change_tracking_name}"
    ama_mdfc_sql_data_collection_rule_id        = "$${management_resource_group_id}/providers/Microsoft.Insights/dataCollectionRules/$${dcr_defender_sql_name}"
    ama_vm_insights_data_collection_rule_id     = "$${management_resource_group_id}/providers/Microsoft.Insights/dataCollectionRules/$${dcr_vm_insights_name}"
    ama_user_assigned_managed_identity_id       = "$${management_resource_group_id}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/$${ama_user_assigned_managed_identity_name}"
    log_analytics_workspace_id                  = "$${management_resource_group_id}/providers/Microsoft.OperationalInsights/workspaces/$${log_analytics_workspace_name}"
    ddos_protection_plan_id                     = "$${ddos_protection_plan_resource_group_id}/providers/Microsoft.Network/ddosProtectionPlans/$${ddos_protection_plan_name}"
  }
}

/*
--- Tags ---
This variable can be used to apply tags to all resources that support it. Some resources allow overriding these tags.
*/
tags = {
  deployed_by = "terraform"
  source      = "Azure Landing Zones Accelerator"
  environment = "alz-mgmt-2"
}

/*
--- Management Resources ---
You can use this section to customize the management resources that will be deployed.
*/
management_resources_enabled = true

management_resource_settings = {
  location                     = "$${starter_location_01}"
  log_analytics_workspace_name = "$${log_analytics_workspace_name}"
  resource_group_name          = "$${management_resource_group_name}"
  user_assigned_managed_identities = {
    ama = {
      name = "$${ama_user_assigned_managed_identity_name}"
    }
  }
  data_collection_rules = {
    change_tracking = {
      name = "$${dcr_change_tracking_name}"
    }
    defender_sql = {
      name = "$${dcr_defender_sql_name}"
    }
    vm_insights = {
      name = "$${dcr_vm_insights_name}"
    }
  }
}

/*
--- Management Groups and Policy ---
You can use this section to customize the management groups and policies that will be deployed.
You can further configure management groups and policy by supplying a `lib` folder. This is detailed in the Accelerator documentation.
*/
management_groups_enabled = true

management_group_settings = {
  # This is the name of the architecture that will be used to deploy the management resources.
  # It refers to the alz_custom.alz_architecture_definition.yaml file in the lib folder.
  # Do not change this value unless you have created another architecture definition
  # with the name value specified below.
  architecture_name  = "alz_custom"
  location           = "$${starter_location_01}"
  parent_resource_id = "$${root_parent_management_group_id}"
  policy_default_values = {
    ama_change_tracking_data_collection_rule_id = "$${ama_change_tracking_data_collection_rule_id}"
    ama_mdfc_sql_data_collection_rule_id        = "$${ama_mdfc_sql_data_collection_rule_id}"
    ama_vm_insights_data_collection_rule_id     = "$${ama_vm_insights_data_collection_rule_id}"
    ama_user_assigned_managed_identity_id       = "$${ama_user_assigned_managed_identity_id}"
    ama_user_assigned_managed_identity_name     = "$${ama_user_assigned_managed_identity_name}"
    log_analytics_workspace_id                  = "$${log_analytics_workspace_id}"
    ddos_protection_plan_id                     = "$${ddos_protection_plan_id}"
    private_dns_zone_subscription_id            = "$${subscription_id_connectivity}"
    private_dns_zone_region                     = "$${starter_location_01}"
    private_dns_zone_resource_group_name        = "$${dns_resource_group_name}"
    resource_group_name_service_health_alerts   = "$${service_health_alerts_resource_group_name}"
    resource_group_name_mdfc                    = "$${asc_export_resource_group_name}"
    resource_group_location                     = "$${starter_location_01}"
    email_security_contact                      = "$${defender_email_security_contact}"
    /*
    # Example of allowed locations for Sovereign Landing Zones policies
    allowed_locations = [
      "$${starter_location_01}"
    ]
    */
  }
  subscription_placement = {
    # identity = {
    #   subscription_id       = "$${subscription_id_identity}"
    #   management_group_name = "identity"
    # }
    connectivity = {
      subscription_id       = "$${subscription_id_connectivity}"
      management_group_name = "connectivity"
    }
    management = {
      subscription_id       = "$${subscription_id_management}"
      management_group_name = "management"
    }
    # security = {
    #   subscription_id       = "$${subscription_id_security}"
    #   management_group_name = "security"
    # }
  }
  policy_assignments_to_modify = {
    alz = {
      policy_assignments = {
        Deploy-MDFC-Config-H224 = {
          parameters = {
            enableAscForServers                         = "DeployIfNotExists"
            enableAscForServersVulnerabilityAssessments = "DeployIfNotExists"
            enableAscForSql                             = "DeployIfNotExists"
            enableAscForAppServices                     = "DeployIfNotExists"
            enableAscForStorage                         = "DeployIfNotExists"
            enableAscForContainers                      = "DeployIfNotExists"
            enableAscForKeyVault                        = "DeployIfNotExists"
            enableAscForSqlOnVm                         = "DeployIfNotExists"
            enableAscForArm                             = "DeployIfNotExists"
            enableAscForOssDb                           = "DeployIfNotExists"
            enableAscForCosmosDbs                       = "DeployIfNotExists"
            enableAscForCspm                            = "DeployIfNotExists"
          }
        }
      }
    }
    landingzones = {
      policy_assignments = {
        # Force all spoke egress through the FortiGate NVA (ILB frontend IP).
        Deploy-Spoke-RT-NVA = {
          parameters = {
            nvaIpAddress = "$${primary_fortigate_ilb_ip}"
            effect       = "DeployIfNotExists"
          }
        }
      }
    }
  }
  /*
  # Example of how to add management group role assignments
  management_group_role_assignments = {
    root_owner_role_assignment = {
      management_group_name      = "root"
      role_definition_id_or_name = "Owner"
      principal_id               = "00000000-0000-0000-0000-000000000000"
    }
  }
  */
  # role_assignment_name_use_random_uuid = false  # Uncomment this for backwards compatibility with previous naming convention
}

/*
--- Connectivity - Hub and Spoke Virtual Network ---
You can use this section to customize the hub virtual networking that will be deployed.
*/
connectivity_type = "hub_and_spoke_vnet"

connectivity_resource_groups = {
  ddos = {
    name     = "$${ddos_resource_group_name}"
    location = "$${starter_location_01}"
    settings = {
      enabled = "$${ddos_protection_plan_enabled}"
    }
  }
  vnet_primary = {
    name     = "$${connectivity_hub_primary_resource_group_name}"
    location = "$${starter_location_01}"
    settings = {
      enabled = true
    }
  }
  dns = {
    name     = "$${dns_resource_group_name}"
    location = "$${starter_location_01}"
    settings = {
      enabled = "$${primary_private_dns_zones_enabled}"
    }
  }
}

hub_and_spoke_networks_settings = {
  enabled_resources = {
    ddos_protection_plan = "$${ddos_protection_plan_enabled}"
  }
  ddos_protection_plan = {
    name                = "$${ddos_protection_plan_name}"
    resource_group_name = "$${ddos_resource_group_name}"
    location            = "$${starter_location_01}"
  }
}

hub_virtual_networks = {
  primary = {
    location          = "$${starter_location_01}"
    default_parent_id = "$${primary_connectivity_resource_group_id}"
    enabled_resources = {
      firewall                              = false
      bastion                               = "$${primary_bastion_enabled}"
      virtual_network_gateway_express_route = "$${primary_virtual_network_gateway_express_route_enabled}"
      virtual_network_gateway_vpn           = "$${primary_virtual_network_gateway_vpn_enabled}"
      private_dns_zones                     = "$${primary_private_dns_zones_enabled}"
      private_dns_resolver                  = "$${primary_private_dns_resolver_enabled}"
    }
    hub_virtual_network = {
      name                          = "$${primary_virtual_network_name}"
      address_space                 = ["$${primary_hub_virtual_network_address_space}"]
      routing_address_space         = ["$${primary_hub_address_space}"]
      hub_router_ip_address         = "$${primary_fortigate_ilb_ip}"
      route_table_name_firewall     = "$${primary_route_table_firewall_name}"
      route_table_name_user_subnets = "$${primary_route_table_user_subnets_name}"
      route_table_entries_user_subnets = [
        {
          name                = "default-via-fortigate-ilb"
          address_prefix      = "0.0.0.0/0"
          next_hop_type       = "VirtualAppliance"
          next_hop_ip_address = "$${primary_fortigate_ilb_ip}"
        },
        {
          name                = "onprem-172-via-fortigate-ilb"
          address_prefix      = "$${primary_onprem_prefix_1}"
          next_hop_type       = "VirtualAppliance"
          next_hop_ip_address = "$${primary_fortigate_ilb_ip}"
        },
        {
          name                = "onprem-192-via-fortigate-ilb"
          address_prefix      = "$${primary_onprem_prefix_2}"
          next_hop_type       = "VirtualAppliance"
          next_hop_ip_address = "$${primary_fortigate_ilb_ip}"
        }
      ]
      subnets = {
        fgt_external = {
          name             = "$${primary_fgt_external_subnet_name}"
          address_prefixes = ["$${primary_fgt_external_subnet_address_prefix}"]
        }
        fgt_internal = {
          name             = "$${primary_fgt_internal_subnet_name}"
          address_prefixes = ["$${primary_fgt_internal_subnet_address_prefix}"]
        }
        fgt_hasync = {
          name             = "$${primary_fgt_hasync_subnet_name}"
          address_prefixes = ["$${primary_fgt_hasync_subnet_address_prefix}"]
        }
        fgt_hamgmt = {
          name             = "$${primary_fgt_hamgmt_subnet_name}"
          address_prefixes = ["$${primary_fgt_hamgmt_subnet_address_prefix}"]
        }
      }
    }
    virtual_network_gateways = {
      subnet_address_prefix = "$${primary_gateway_subnet_address_prefix}"
      express_route = {
        name                                  = "$${primary_virtual_network_gateway_express_route_name}"
        hosted_on_behalf_of_public_ip_enabled = "$${primary_virtual_network_gateway_express_route_hobo_public_ip_enabled}"
        ip_configurations = {
          default = {
            # name = "vnetGatewayConfigdefault"  # For backwards compatibility with previous naming, uncomment this line
            public_ip = {
              name = "$${primary_virtual_network_gateway_express_route_public_ip_name}"
            }
          }
        }
      }
      vpn = {
        name = "$${primary_virtual_network_gateway_vpn_name}"
        ip_configurations = {
          active_active_1 = {
            # name = "vnetGatewayConfigactive_active_1"  # For backwards compatibility with previous naming, uncomment this line
            public_ip = {
              name = "$${primary_virtual_network_gateway_vpn_public_ip_name_1}"
            }
          }
          active_active_2 = {
            # name = "vnetGatewayConfigactive_active_2"  # For backwards compatibility with previous naming, uncomment this line
            public_ip = {
              name = "$${primary_virtual_network_gateway_vpn_public_ip_name_2}"
            }
          }
        }
      }
    }
    private_dns_zones = {
      parent_id = "$${dns_resource_group_id}"
      private_link_private_dns_zones_regex_filter = {
        enabled = false
      }
      auto_registration_zone_enabled = "$${primary_private_dns_auto_registration_zone_enabled}"
      auto_registration_zone_name    = "$${primary_auto_registration_zone_name}"
    }
    private_dns_resolver = {
      subnet_address_prefix = "$${primary_private_dns_resolver_subnet_address_prefix}"
      name                  = "$${primary_private_dns_resolver_name}"
    }
    bastion = {
      subnet_address_prefix = "$${primary_bastion_subnet_address_prefix}"
      name                  = "$${primary_bastion_host_name}"
      bastion_public_ip = {
        name = "$${primary_bastion_host_public_ip_name}"
      }
    }
  }
}

# private_link_private_dns_zone_virtual_network_link_moved_blocks_enabled = true

enable_telemetry = true
telemetry_additional_content = {
  deployed_by    = "alz-terraform-accelerator"
  correlation_id = "00000000-0000-0000-0000-000000000000"
}

fortigate = {
  enabled             = true
  target_hub_key      = "primary"
  external_subnet_key = "fgt_external"
  internal_subnet_key = "fgt_internal"
  hasync_subnet_key   = "fgt_hasync"
  hamgmt_subnet_key   = "fgt_hamgmt"
  name_prefix         = "fgt"
  # 4 NICs require a VM size that supports >= 4 NICs (D8ds_v5 = 4 NICs).
  vm_size                         = "Standard_D8ds_v5"
  instances                       = ["01", "02"]
  zones                           = { "01" = "1", "02" = "2" }
  admin_username                  = "azureadmin"
  disable_password_authentication = true
  admin_ssh_public_key_path       = "~/.ssh/adm-simon.pub"

  accelerated_networking_enabled = true
  # accelerated_connections_enabled = true
  # accelerated_connections_sku     = "A1"

  # Per-VM management public IP on port4 (HA management).
  management_create_public_ip  = true
  availability_zones_public_ip = ["1", "2", "3"]

  # Image / license selection: "byol" (production, Salzgitter) or "payg".
  # The FortiGate-VM Free Trial runs on the BYOL image (licensed via FortiCloud),
  # so keep "byol" for the MCAPS free-trial test as well.
  license_model                = "byol"
  accept_marketplace_agreement = true
  # Optional explicit overrides (leave unset to use the license_model defaults =
  # publisher "fortinet", offer "fortinet_fortigate-vm", sku/plan "fortinet_fg-vm_byol_76"):
  # marketplace_publisher = "fortinet"
  # marketplace_offer     = "fortinet_fortigate-vm"
  # marketplace_sku       = "fortinet_fg-vm_byol_76"
  # marketplace_plan      = "fortinet_fg-vm_byol_76"
  # marketplace_version   = "latest"

  # Internal load balancer (spoke egress next hop = ilb_private_ip_address).
  ilb_enabled                        = true
  ilb_name                           = "fgt-primary-ilb"
  ilb_frontend_ip_configuration_name = "frontend"
  ilb_backend_address_pool_name      = "backend"
  ilb_private_ip_address             = "$${primary_fortigate_ilb_ip}"
  ilb_probe_name                     = "probe-tcp"
  ilb_probe_port                     = 8008
  ilb_ha_ports_rule_enabled          = true
  ilb_ha_ports_rule_name             = "ha-ports"

  # External (public) load balancer for north-south traffic.
  elb_enabled                        = true
  elb_name                           = "fgt-primary-elb"
  elb_frontend_ip_configuration_name = "frontend"
  elb_backend_address_pool_name      = "backend"
  elb_public_ip_name                 = "fgt-primary-elb-pip"
  elb_probe_name                     = "probe-tcp"
  elb_probe_port                     = 8008
  elb_outbound_rule_enabled          = true
  elb_outbound_rule_name             = "outbound"

  # Optional: bootstrap after first boot. Keep disabled unless required.
  custom_script_extension_enabled   = false
  custom_script_extension_file_uris = []
  custom_script_extension_command   = null
  custom_script_extension_protected = null
}
