locals {
  fortigate_enabled = local.connectivity_hub_and_spoke_vnet_enabled && try(var.fortigate.enabled, false)

  fortigate_hub = local.fortigate_enabled ? try(local.hub_virtual_networks[var.fortigate.target_hub_key], null) : null

  fortigate_parent_id = local.fortigate_enabled ? coalesce(
    try(local.fortigate_hub.hub_virtual_network.parent_id, null),
    try(local.fortigate_hub.default_parent_id, null)
  ) : null

  fortigate_resource_group_name = local.fortigate_enabled && local.fortigate_parent_id != null ? element(
    split("/", local.fortigate_parent_id),
    length(split("/", local.fortigate_parent_id)) - 1
  ) : null

  fortigate_vnet_name = local.fortigate_enabled ? try(local.fortigate_hub.hub_virtual_network.name, null) : null

  # Resolve the four dedicated FortiGate subnet names from the hub subnets map.
  fortigate_subnet_names = local.fortigate_enabled ? {
    external = try(local.fortigate_hub.hub_virtual_network.subnets[var.fortigate.external_subnet_key].name, null)
    internal = try(local.fortigate_hub.hub_virtual_network.subnets[var.fortigate.internal_subnet_key].name, null)
    hasync   = try(local.fortigate_hub.hub_virtual_network.subnets[var.fortigate.hasync_subnet_key].name, null)
    hamgmt   = try(local.fortigate_hub.hub_virtual_network.subnets[var.fortigate.hamgmt_subnet_key].name, null)
  } : {}

  fortigate_instances = local.fortigate_enabled ? toset(try(var.fortigate.instances, [])) : toset([])

  fortigate_admin_ssh_public_key_resolved = trimspace(coalesce(
    try(var.fortigate.admin_ssh_public_key, null),
    try(var.fortigate.admin_ssh_public_key_path, null) != null ? try(file(pathexpand(var.fortigate.admin_ssh_public_key_path)), null) : null,
    ""
  ))

  fortigate_effective_tags = merge(
    coalesce(module.config.outputs.connectivity_tags, module.config.outputs.tags, {}),
    coalesce(try(var.fortigate.tags, null), {}),
    try(var.fortigate.accelerated_connections_enabled, false) ? coalesce(try(var.fortigate.accelerated_connections_tags, {}), {}) : {}
  )

  fortigate_aux_mode = try(var.fortigate.accelerated_connections_enabled, false) ? "AcceleratedConnections" : "None"
  fortigate_aux_sku  = try(var.fortigate.accelerated_connections_enabled, false) ? var.fortigate.accelerated_connections_sku : "None"

  # Image / license selection. "byol" is used for production (Salzgitter) and also
  # for the FortiGate-VM Free Trial (the trial is a FortiCloud licensing state on the
  # BYOL image). "payg" bills the FortiGate software fee hourly via the Marketplace.
  fortigate_license_model = lower(try(var.fortigate.license_model, "byol"))
  fortigate_image_defaults = {
    byol = {
      publisher = "fortinet"
      offer     = "fortinet_fortigate-vm"
      sku       = "fortinet_fg-vm_byol_76"
      plan      = "fortinet_fg-vm_byol_76"
    }
    payg = {
      publisher = "fortinet"
      offer     = "fortinet_fortigate-vm"
      sku       = "fortinet_fg-vm_payg_76"
      plan      = "fortinet_fg-vm_payg_76"
    }
  }
  # Explicit marketplace_* inputs (if set) win over the license_model defaults.
  fortigate_image = {
    publisher = coalesce(try(var.fortigate.marketplace_publisher, null), local.fortigate_image_defaults[local.fortigate_license_model].publisher)
    offer     = coalesce(try(var.fortigate.marketplace_offer, null), local.fortigate_image_defaults[local.fortigate_license_model].offer)
    sku       = coalesce(try(var.fortigate.marketplace_sku, null), local.fortigate_image_defaults[local.fortigate_license_model].sku)
    plan      = coalesce(try(var.fortigate.marketplace_plan, null), local.fortigate_image_defaults[local.fortigate_license_model].plan)
    version   = coalesce(try(var.fortigate.marketplace_version, null), "latest")
  }
}

data "azurerm_subnet" "fgt_external" {
  count = local.fortigate_enabled ? 1 : 0

  provider             = azurerm.connectivity
  name                 = local.fortigate_subnet_names.external
  resource_group_name  = local.fortigate_resource_group_name
  virtual_network_name = local.fortigate_vnet_name
}

data "azurerm_subnet" "fgt_internal" {
  count = local.fortigate_enabled ? 1 : 0

  provider             = azurerm.connectivity
  name                 = local.fortigate_subnet_names.internal
  resource_group_name  = local.fortigate_resource_group_name
  virtual_network_name = local.fortigate_vnet_name
}

data "azurerm_subnet" "fgt_hasync" {
  count = local.fortigate_enabled ? 1 : 0

  provider             = azurerm.connectivity
  name                 = local.fortigate_subnet_names.hasync
  resource_group_name  = local.fortigate_resource_group_name
  virtual_network_name = local.fortigate_vnet_name
}

data "azurerm_subnet" "fgt_hamgmt" {
  count = local.fortigate_enabled ? 1 : 0

  provider             = azurerm.connectivity
  name                 = local.fortigate_subnet_names.hamgmt
  resource_group_name  = local.fortigate_resource_group_name
  virtual_network_name = local.fortigate_vnet_name
}

resource "azurerm_marketplace_agreement" "fortigate" {
  count = local.fortigate_enabled && try(var.fortigate.accept_marketplace_agreement, true) ? 1 : 0

  provider  = azurerm.connectivity
  publisher = local.fortigate_image.publisher
  offer     = local.fortigate_image.offer
  plan      = local.fortigate_image.plan
}

##############################################################################
# Public IPs
##############################################################################

# Per-instance management public IP (attached to port4 / HA management NIC).
resource "azurerm_public_ip" "fgt_mgmt" {
  for_each = local.fortigate_enabled && try(var.fortigate.management_create_public_ip, true) ? local.fortigate_instances : toset([])

  provider            = azurerm.connectivity
  name                = "${var.fortigate.name_prefix}-${var.fortigate.target_hub_key}-${each.value}-mgmt-pip"
  location            = local.fortigate_hub.location
  resource_group_name = local.fortigate_resource_group_name
  allocation_method   = "Static"
  sku                 = var.fortigate.public_ip_sku
  zones               = var.fortigate.availability_zones_public_ip
  tags                = local.fortigate_effective_tags
}

# External load balancer public IP (zone-redundant).
resource "azurerm_public_ip" "fgt_elb" {
  count = local.fortigate_enabled && try(var.fortigate.elb_enabled, true) ? 1 : 0

  provider            = azurerm.connectivity
  name                = coalesce(try(var.fortigate.elb_public_ip_name, null), "${var.fortigate.name_prefix}-${var.fortigate.target_hub_key}-elb-pip")
  location            = local.fortigate_hub.location
  resource_group_name = local.fortigate_resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.fortigate.availability_zones_public_ip
  tags                = local.fortigate_effective_tags
}

##############################################################################
# Network interfaces (4 per VM: port1 external, port2 internal, port3 hasync, port4 hamgmt)
##############################################################################

resource "azurerm_network_interface" "fgt_external" {
  for_each = local.fortigate_instances

  provider                       = azurerm.connectivity
  name                           = "${var.fortigate.name_prefix}-${var.fortigate.target_hub_key}-${each.value}-port1-external"
  location                       = local.fortigate_hub.location
  resource_group_name            = local.fortigate_resource_group_name
  ip_forwarding_enabled          = true
  accelerated_networking_enabled = try(var.fortigate.accelerated_networking_enabled, true)
  auxiliary_mode                 = local.fortigate_aux_mode
  auxiliary_sku                  = local.fortigate_aux_sku
  tags                           = local.fortigate_effective_tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = data.azurerm_subnet.fgt_external[0].id
    private_ip_address_allocation = var.fortigate.private_ip_address_allocation
  }

  lifecycle {
    precondition {
      condition     = local.fortigate_hub != null
      error_message = "fortigate.target_hub_key does not exist in hub_virtual_networks."
    }
    precondition {
      condition     = local.fortigate_vnet_name != null && local.fortigate_resource_group_name != null
      error_message = "Unable to resolve the target hub virtual network name or resource group."
    }
    precondition {
      condition     = alltrue([for k, v in local.fortigate_subnet_names : v != null])
      error_message = "One or more FortiGate subnet keys (external/internal/hasync/hamgmt) were not found in the target hub virtual network subnets map."
    }
  }
}

resource "azurerm_network_interface" "fgt_internal" {
  for_each = local.fortigate_instances

  provider                       = azurerm.connectivity
  name                           = "${var.fortigate.name_prefix}-${var.fortigate.target_hub_key}-${each.value}-port2-internal"
  location                       = local.fortigate_hub.location
  resource_group_name            = local.fortigate_resource_group_name
  ip_forwarding_enabled          = true
  accelerated_networking_enabled = try(var.fortigate.accelerated_networking_enabled, true)
  auxiliary_mode                 = local.fortigate_aux_mode
  auxiliary_sku                  = local.fortigate_aux_sku
  tags                           = local.fortigate_effective_tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = data.azurerm_subnet.fgt_internal[0].id
    private_ip_address_allocation = var.fortigate.private_ip_address_allocation
  }
}

resource "azurerm_network_interface" "fgt_hasync" {
  for_each = local.fortigate_instances

  provider              = azurerm.connectivity
  name                  = "${var.fortigate.name_prefix}-${var.fortigate.target_hub_key}-${each.value}-port3-hasync"
  location              = local.fortigate_hub.location
  resource_group_name   = local.fortigate_resource_group_name
  ip_forwarding_enabled = false
  tags                  = local.fortigate_effective_tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = data.azurerm_subnet.fgt_hasync[0].id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "fgt_hamgmt" {
  for_each = local.fortigate_instances

  provider              = azurerm.connectivity
  name                  = "${var.fortigate.name_prefix}-${var.fortigate.target_hub_key}-${each.value}-port4-hamgmt"
  location              = local.fortigate_hub.location
  resource_group_name   = local.fortigate_resource_group_name
  ip_forwarding_enabled = false
  tags                  = local.fortigate_effective_tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = data.azurerm_subnet.fgt_hamgmt[0].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = try(var.fortigate.management_create_public_ip, true) ? azurerm_public_ip.fgt_mgmt[each.value].id : null
  }
}

##############################################################################
# External (public) Standard Load Balancer - north-south
##############################################################################

resource "azurerm_lb" "fortigate_external" {
  count = local.fortigate_enabled && try(var.fortigate.elb_enabled, true) ? 1 : 0

  provider            = azurerm.connectivity
  name                = coalesce(try(var.fortigate.elb_name, null), "${var.fortigate.name_prefix}-${var.fortigate.target_hub_key}-elb")
  location            = local.fortigate_hub.location
  resource_group_name = local.fortigate_resource_group_name
  sku                 = "Standard"
  tags                = local.fortigate_effective_tags

  frontend_ip_configuration {
    name                 = var.fortigate.elb_frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.fgt_elb[0].id
  }
}

resource "azurerm_lb_backend_address_pool" "fortigate_external" {
  count = local.fortigate_enabled && try(var.fortigate.elb_enabled, true) ? 1 : 0

  provider        = azurerm.connectivity
  name            = var.fortigate.elb_backend_address_pool_name
  loadbalancer_id = azurerm_lb.fortigate_external[0].id
}

resource "azurerm_network_interface_backend_address_pool_association" "fgt_external" {
  for_each = local.fortigate_enabled && try(var.fortigate.elb_enabled, true) ? local.fortigate_instances : toset([])

  provider                = azurerm.connectivity
  network_interface_id    = azurerm_network_interface.fgt_external[each.value].id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.fortigate_external[0].id
}

resource "azurerm_lb_probe" "fortigate_external" {
  count = local.fortigate_enabled && try(var.fortigate.elb_enabled, true) ? 1 : 0

  provider            = azurerm.connectivity
  name                = var.fortigate.elb_probe_name
  loadbalancer_id     = azurerm_lb.fortigate_external[0].id
  protocol            = "Tcp"
  port                = var.fortigate.elb_probe_port
  interval_in_seconds = 5
  number_of_probes    = 2
}

# Egress SNAT for FortiGate outbound traffic via the external LB public IP.
resource "azurerm_lb_outbound_rule" "fortigate_external" {
  count = local.fortigate_enabled && try(var.fortigate.elb_enabled, true) && try(var.fortigate.elb_outbound_rule_enabled, true) ? 1 : 0

  provider                 = azurerm.connectivity
  name                     = var.fortigate.elb_outbound_rule_name
  loadbalancer_id          = azurerm_lb.fortigate_external[0].id
  protocol                 = "All"
  backend_address_pool_id  = azurerm_lb_backend_address_pool.fortigate_external[0].id
  allocated_outbound_ports = var.fortigate.elb_outbound_allocated_ports

  frontend_ip_configuration {
    name = var.fortigate.elb_frontend_ip_configuration_name
  }
}

##############################################################################
# Internal Standard Load Balancer - east-west + spoke egress next hop
##############################################################################

resource "azurerm_lb" "fortigate" {
  count = local.fortigate_enabled && try(var.fortigate.ilb_enabled, true) ? 1 : 0

  provider            = azurerm.connectivity
  name                = coalesce(try(var.fortigate.ilb_name, null), "${var.fortigate.name_prefix}-${var.fortigate.target_hub_key}-ilb")
  location            = local.fortigate_hub.location
  resource_group_name = local.fortigate_resource_group_name
  sku                 = var.fortigate.ilb_sku
  tags                = local.fortigate_effective_tags

  frontend_ip_configuration {
    name                          = var.fortigate.ilb_frontend_ip_configuration_name
    subnet_id                     = data.azurerm_subnet.fgt_internal[0].id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.fortigate.ilb_private_ip_address
    zones                         = var.fortigate.availability_zones_public_ip
  }

  lifecycle {
    precondition {
      condition     = try(var.fortigate.ilb_private_ip_address, null) != null
      error_message = "fortigate.ilb_private_ip_address must be set (in the internal subnet) when fortigate.ilb_enabled is true."
    }
  }
}

resource "azurerm_lb_backend_address_pool" "fortigate" {
  count = local.fortigate_enabled && try(var.fortigate.ilb_enabled, true) ? 1 : 0

  provider        = azurerm.connectivity
  name            = var.fortigate.ilb_backend_address_pool_name
  loadbalancer_id = azurerm_lb.fortigate[0].id
}

resource "azurerm_network_interface_backend_address_pool_association" "fgt_internal" {
  for_each = local.fortigate_enabled && try(var.fortigate.ilb_enabled, true) ? local.fortigate_instances : toset([])

  provider                = azurerm.connectivity
  network_interface_id    = azurerm_network_interface.fgt_internal[each.value].id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.fortigate[0].id
}

resource "azurerm_lb_probe" "fortigate" {
  count = local.fortigate_enabled && try(var.fortigate.ilb_enabled, true) ? 1 : 0

  provider            = azurerm.connectivity
  name                = var.fortigate.ilb_probe_name
  loadbalancer_id     = azurerm_lb.fortigate[0].id
  protocol            = "Tcp"
  port                = var.fortigate.ilb_probe_port
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "fortigate_ha_ports" {
  count = local.fortigate_enabled && try(var.fortigate.ilb_enabled, true) && try(var.fortigate.ilb_ha_ports_rule_enabled, true) ? 1 : 0

  provider                       = azurerm.connectivity
  name                           = var.fortigate.ilb_ha_ports_rule_name
  loadbalancer_id                = azurerm_lb.fortigate[0].id
  protocol                       = "All"
  frontend_port                  = 0
  backend_port                   = 0
  frontend_ip_configuration_name = var.fortigate.ilb_frontend_ip_configuration_name
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.fortigate[0].id]
  probe_id                       = azurerm_lb_probe.fortigate[0].id
  floating_ip_enabled            = true
  disable_outbound_snat          = true
  load_distribution              = "SourceIPProtocol"
}

##############################################################################
# FortiGate VMs (Active/Passive pair, one per Availability Zone)
##############################################################################

resource "azurerm_linux_virtual_machine" "fortigate" {
  for_each = local.fortigate_instances

  provider            = azurerm.connectivity
  name                = "${var.fortigate.name_prefix}-${var.fortigate.target_hub_key}-${each.value}-vm"
  location            = local.fortigate_hub.location
  resource_group_name = local.fortigate_resource_group_name
  size                = var.fortigate.vm_size
  zone                = lookup(try(var.fortigate.zones, {}), each.key, null)

  # NIC order maps to FortiGate ports: port1 external, port2 internal, port3 hasync, port4 hamgmt.
  network_interface_ids = [
    azurerm_network_interface.fgt_external[each.value].id,
    azurerm_network_interface.fgt_internal[each.value].id,
    azurerm_network_interface.fgt_hasync[each.value].id,
    azurerm_network_interface.fgt_hamgmt[each.value].id,
  ]

  admin_username                  = var.fortigate.admin_username
  admin_password                  = try(var.fortigate.disable_password_authentication, false) ? null : var.fortigate_admin_password
  disable_password_authentication = var.fortigate.disable_password_authentication

  source_image_reference {
    publisher = local.fortigate_image.publisher
    offer     = local.fortigate_image.offer
    sku       = local.fortigate_image.sku
    version   = local.fortigate_image.version
  }

  plan {
    publisher = local.fortigate_image.publisher
    product   = local.fortigate_image.offer
    name      = local.fortigate_image.plan
  }

  os_disk {
    name                 = "${var.fortigate.name_prefix}-${var.fortigate.target_hub_key}-${each.value}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  custom_data = try(var.fortigate.custom_data, null) != null ? base64encode(var.fortigate.custom_data) : null

  dynamic "admin_ssh_key" {
    for_each = local.fortigate_admin_ssh_public_key_resolved != "" ? [local.fortigate_admin_ssh_public_key_resolved] : []
    content {
      username   = var.fortigate.admin_username
      public_key = admin_ssh_key.value
    }
  }

  tags = local.fortigate_effective_tags

  lifecycle {
    precondition {
      condition = (
        try(var.fortigate.disable_password_authentication, false) && local.fortigate_admin_ssh_public_key_resolved != ""
        ) || (
        !try(var.fortigate.disable_password_authentication, false) && var.fortigate_admin_password != null
      )
      error_message = "Provide fortigate.admin_ssh_public_key or fortigate.admin_ssh_public_key_path when password auth is disabled, or fortigate_admin_password when password auth is enabled."
    }
    precondition {
      condition = !try(var.fortigate.accelerated_connections_enabled, false) || (
        try(var.fortigate.accelerated_networking_enabled, true) &&
        var.fortigate.accelerated_connections_sku != "None"
      )
      error_message = "When accelerated connections are enabled, accelerated networking must also be enabled and accelerated_connections_sku must not be 'None'."
    }
  }

  depends_on = [azurerm_marketplace_agreement.fortigate]
}

resource "azurerm_virtual_machine_extension" "fortigate_custom_script" {
  for_each = local.fortigate_enabled && try(var.fortigate.custom_script_extension_enabled, false) ? local.fortigate_instances : toset([])

  provider                   = azurerm.connectivity
  name                       = "${var.fortigate.name_prefix}-${var.fortigate.target_hub_key}-${each.value}-cse"
  virtual_machine_id         = azurerm_linux_virtual_machine.fortigate[each.value].id
  publisher                  = "Microsoft.Azure.Extensions"
  type                       = "CustomScript"
  type_handler_version       = "2.1"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    fileUris = try(var.fortigate.custom_script_extension_file_uris, [])
  })

  protected_settings = jsonencode({
    commandToExecute = try(var.fortigate.custom_script_extension_command, null)
    script           = try(var.fortigate.custom_script_extension_protected, null)
  })

  lifecycle {
    precondition {
      condition     = try(var.fortigate.custom_script_extension_command, null) != null || try(var.fortigate.custom_script_extension_protected, null) != null
      error_message = "Enable custom script extension only when a command or protected script payload is provided."
    }
  }
}
