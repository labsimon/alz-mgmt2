output "dns_server_ip_address" {
  value = local.connectivity_enabled ? (local.connectivity_hub_and_spoke_vnet_enabled ? module.hub_and_spoke_vnet[0].dns_server_ip_addresses : module.virtual_wan[0].dns_server_ip_address) : null
}

output "hub_and_spoke_vnet_virtual_network_resource_ids" {
  value = local.connectivity_hub_and_spoke_vnet_enabled ? module.hub_and_spoke_vnet[0].virtual_network_resource_ids : null
}

output "hub_and_spoke_vnet_virtual_network_resource_names" {
  value = local.connectivity_hub_and_spoke_vnet_enabled ? module.hub_and_spoke_vnet[0].virtual_network_resource_names : null
}

output "hub_and_spoke_vnet_bastion_host_public_ip_address" {
  value = local.connectivity_hub_and_spoke_vnet_enabled ? module.hub_and_spoke_vnet[0].bastion_host_public_ip_address : null
}

output "hub_and_spoke_vnet_bastion_host_resource_ids" {
  value = local.connectivity_hub_and_spoke_vnet_enabled ? module.hub_and_spoke_vnet[0].bastion_host_resource_ids : null
}

output "hub_and_spoke_vnet_bastion_host_dns_names" {
  value = local.connectivity_hub_and_spoke_vnet_enabled ? module.hub_and_spoke_vnet[0].bastion_host_dns_names : null
}

output "hub_and_spoke_vnet_firewall_resource_ids" {
  value = local.connectivity_hub_and_spoke_vnet_enabled ? module.hub_and_spoke_vnet[0].firewall_resource_ids : null
}

output "hub_and_spoke_vnet_firewall_resource_names" {
  value = local.connectivity_hub_and_spoke_vnet_enabled ? module.hub_and_spoke_vnet[0].firewall_resource_names : null
}

output "hub_and_spoke_vnet_firewall_private_ip_address" {
  value = local.connectivity_hub_and_spoke_vnet_enabled ? module.hub_and_spoke_vnet[0].firewall_private_ip_addresses : null
}

output "hub_and_spoke_vnet_firewall_public_ip_addresses" {
  value = local.connectivity_hub_and_spoke_vnet_enabled ? module.hub_and_spoke_vnet[0].firewall_public_ip_addresses : null
}

output "hub_and_spoke_vnet_firewall_policies" {
  value = local.connectivity_hub_and_spoke_vnet_enabled ? module.hub_and_spoke_vnet[0].firewall_policies : null
}

output "hub_and_spoke_vnet_route_tables_firewall" {
  value = local.connectivity_hub_and_spoke_vnet_enabled ? module.hub_and_spoke_vnet[0].route_tables_firewall : null
}

output "hub_and_spoke_vnet_route_tables_user_subnets" {
  value = local.connectivity_hub_and_spoke_vnet_enabled ? module.hub_and_spoke_vnet[0].route_tables_user_subnets : null
}

output "hub_and_spoke_vnet_route_tables_gateway_resource_ids" {
  value = local.connectivity_hub_and_spoke_vnet_enabled ? module.hub_and_spoke_vnet[0].route_tables_gateway_resource_ids : null
}

output "hub_and_spoke_vnet_ddos_protection_plan_resource_id" {
  value = local.connectivity_hub_and_spoke_vnet_enabled ? module.hub_and_spoke_vnet[0].ddos_protection_plan_resource_id : null
}

output "hub_and_spoke_vnet_nat_gateway_resource_ids" {
  value = local.connectivity_hub_and_spoke_vnet_enabled ? module.hub_and_spoke_vnet[0].nat_gateway_resource_ids : null
}

output "hub_and_spoke_vnet_nat_gateways" {
  value = local.connectivity_hub_and_spoke_vnet_enabled ? module.hub_and_spoke_vnet[0].nat_gateways : null
}

output "hub_and_spoke_vnet_virtual_network_gateway_resource_ids" {
  value = local.connectivity_hub_and_spoke_vnet_enabled ? module.hub_and_spoke_vnet[0].virtual_network_gateway_resource_ids : null
}

output "hub_and_spoke_vnet_virtual_network_gateway_public_ip_addresses" {
  value = local.connectivity_hub_and_spoke_vnet_enabled ? module.hub_and_spoke_vnet[0].virtual_network_gateway_public_ip_addresses : null
}

output "hub_and_spoke_vnet_virtual_network_gateway_public_ip_resource_ids" {
  value = local.connectivity_hub_and_spoke_vnet_enabled ? module.hub_and_spoke_vnet[0].virtual_network_gateway_public_ip_resource_ids : null
}

output "hub_and_spoke_vnet_virtual_network_gateway_local_network_gateway_resource_ids" {
  value = local.connectivity_hub_and_spoke_vnet_enabled ? module.hub_and_spoke_vnet[0].virtual_network_gateway_local_network_gateway_resource_ids : null
}

output "hub_and_spoke_vnet_virtual_network_gateway_local_network_gateway_connection_resource_ids" {
  value = local.connectivity_hub_and_spoke_vnet_enabled ? module.hub_and_spoke_vnet[0].virtual_network_gateway_local_network_gateway_connection_resource_ids : null
}

output "fortigate_vm_ids" {
  value = local.fortigate_enabled ? { for k, v in azurerm_linux_virtual_machine.fortigate : k => v.id } : {}
}

output "fortigate_vm_private_ip_addresses" {
  value = local.fortigate_enabled ? {
    for k, v in azurerm_network_interface.fgt_internal :
    k => try(v.ip_configuration[0].private_ip_address, null)
  } : {}
}

output "fortigate_vm_public_ip_addresses" {
  value = local.fortigate_enabled && try(var.fortigate.management_create_public_ip, true) ? {
    for k, v in azurerm_public_ip.fgt_mgmt :
    k => v.ip_address
  } : {}
}

output "fortigate_subnet_id" {
  value = local.fortigate_enabled ? data.azurerm_subnet.fgt_internal[0].id : null
}

output "fortigate_ilb_id" {
  value = local.fortigate_enabled && try(var.fortigate.ilb_enabled, true) ? azurerm_lb.fortigate[0].id : null
}

output "fortigate_ilb_private_ip_address" {
  value = local.connectivity_hub_and_spoke_vnet_enabled && local.fortigate_enabled && try(var.fortigate.ilb_enabled, true) ? try(azurerm_lb.fortigate[0].frontend_ip_configuration[0].private_ip_address, null) : null
}

output "fortigate_elb_id" {
  value = local.fortigate_enabled && try(var.fortigate.elb_enabled, true) ? azurerm_lb.fortigate_external[0].id : null
}

output "fortigate_elb_public_ip_address" {
  value = local.fortigate_enabled && try(var.fortigate.elb_enabled, true) ? try(azurerm_public_ip.fgt_elb[0].ip_address, null) : null
}

output "hub_and_spoke_vnet_virtual_network_gateway_express_route_circuit_connection_resource_ids" {
  value = local.connectivity_hub_and_spoke_vnet_enabled ? module.hub_and_spoke_vnet[0].virtual_network_gateway_express_route_circuit_connection_resource_ids : null
}

output "hub_and_spoke_vnet_bastion_host_public_ip_resource_ids" {
  value = local.connectivity_hub_and_spoke_vnet_enabled ? module.hub_and_spoke_vnet[0].bastion_host_public_ip_resource_ids : null
}

output "hub_and_spoke_vnet_dns_resolver_resource_ids" {
  value = local.connectivity_hub_and_spoke_vnet_enabled ? module.hub_and_spoke_vnet[0].dns_resolver_resource_ids : null
}

output "hub_and_spoke_vnet_dns_resolver_inbound_endpoint_ip_addresses" {
  value = local.connectivity_hub_and_spoke_vnet_enabled ? module.hub_and_spoke_vnet[0].dns_resolver_inbound_endpoint_ip_addresses : null
}

output "hub_and_spoke_vnet_private_dns_zone_resource_ids" {
  value = local.connectivity_hub_and_spoke_vnet_enabled ? module.hub_and_spoke_vnet[0].private_dns_zone_resource_ids : null
}

output "hub_and_spoke_vnet_private_dns_zone_auto_registration_resource_ids" {
  value = local.connectivity_hub_and_spoke_vnet_enabled ? module.hub_and_spoke_vnet[0].private_dns_zone_auto_registration_resource_ids : null
}

output "hub_and_spoke_vnet_private_link_private_dns_zones_maps" {
  value = local.connectivity_hub_and_spoke_vnet_enabled ? module.hub_and_spoke_vnet[0].private_link_private_dns_zones_maps : null
}

output "hub_and_spoke_vnet_full_output" {
  value = local.connectivity_hub_and_spoke_vnet_enabled ? module.hub_and_spoke_vnet[0] : null
}

output "virtual_wan_resource_id" {
  value = local.connectivity_virtual_wan_enabled ? module.virtual_wan[0].resource_id : null
}

output "virtual_wan_name" {
  value = local.connectivity_virtual_wan_enabled ? module.virtual_wan[0].name : null
}

output "virtual_wan_virtual_hub_resource_ids" {
  value = local.connectivity_virtual_wan_enabled ? module.virtual_wan[0].virtual_hub_resource_ids : null
}

output "virtual_wan_virtual_hub_resource_names" {
  value = local.connectivity_virtual_wan_enabled ? module.virtual_wan[0].virtual_hub_resource_names : null
}

output "virtual_wan_firewall_resource_ids" {
  value = local.connectivity_virtual_wan_enabled ? module.virtual_wan[0].firewall_resource_ids : null
}

output "virtual_wan_firewall_resource_names" {
  value = local.connectivity_virtual_wan_enabled ? module.virtual_wan[0].firewall_resource_names : null
}

output "virtual_wan_firewall_private_ip_address" {
  value = local.connectivity_virtual_wan_enabled ? module.virtual_wan[0].firewall_private_ip_address : null
}

output "virtual_wan_firewall_public_ip_addresses" {
  value = local.connectivity_virtual_wan_enabled ? module.virtual_wan[0].firewall_public_ip_addresses : null
}

output "virtual_wan_firewall_policy_ids" {
  value = local.connectivity_virtual_wan_enabled ? module.virtual_wan[0].firewall_policy_resource_ids : null
}

output "virtual_wan_express_route_gateway_resource_ids" {
  value = local.connectivity_virtual_wan_enabled ? module.virtual_wan[0].express_route_gateway_resource_ids : null
}

output "virtual_wan_bastion_host_public_ip_address" {
  value = local.connectivity_virtual_wan_enabled ? module.virtual_wan[0].bastion_host_public_ip_address : null
}

output "virtual_wan_bastion_host_resource_ids" {
  value = local.connectivity_virtual_wan_enabled ? module.virtual_wan[0].bastion_host_resource_ids : null
}

output "virtual_wan_bastion_host_dns_names" {
  value = local.connectivity_virtual_wan_enabled ? module.virtual_wan[0].bastion_host_dns_names : null
}

output "virtual_wan_private_dns_resolver_resource_ids" {
  value = local.connectivity_virtual_wan_enabled ? module.virtual_wan[0].private_dns_resolver_resource_ids : null
}

output "virtual_wan_private_dns_resolver_resources" {
  value = local.connectivity_virtual_wan_enabled ? module.virtual_wan[0].private_dns_resolver_resources : null
}

output "virtual_wan_sidecar_virtual_network_resource_ids" {
  value = local.connectivity_virtual_wan_enabled ? module.virtual_wan[0].sidecar_virtual_network_resource_ids : null
}

output "virtual_wan_sidecar_virtual_network_resources" {
  value = local.connectivity_virtual_wan_enabled ? module.virtual_wan[0].sidecar_virtual_network_resources : null
}

output "virtual_wan_virtual_hub_bgp_connection_resource_ids" {
  value = local.connectivity_virtual_wan_enabled ? module.virtual_wan[0].virtual_hub_bgp_connection_resource_ids : null
}

output "virtual_wan_express_route_gateway_resources" {
  value = local.connectivity_virtual_wan_enabled ? module.virtual_wan[0].express_route_gateway_resources : null
}

output "virtual_wan_private_dns_zone_resource_ids" {
  value = local.connectivity_virtual_wan_enabled ? module.virtual_wan[0].private_dns_zone_resource_ids : null
}

output "virtual_wan_private_link_private_dns_zones_maps" {
  value = local.connectivity_virtual_wan_enabled ? module.virtual_wan[0].private_link_private_dns_zones_maps : null
}

output "virtual_wan_full_output" {
  value = local.connectivity_virtual_wan_enabled ? module.virtual_wan[0] : null
}

output "templated_inputs" {
  value = module.config.outputs
}
