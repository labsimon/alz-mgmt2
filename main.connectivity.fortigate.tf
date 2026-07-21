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

  fortigate_subnet_name = local.fortigate_enabled ? try(
    local.fortigate_hub.hub_virtual_network.subnets[var.fortigate.subnet_key].name,
    null
  ) : null

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
}

data "azurerm_subnet" "fortigate" {
  count = local.fortigate_enabled ? 1 : 0

  provider             = azurerm.connectivity
  name                 = local.fortigate_subnet_name
  resource_group_name  = local.fortigate_resource_group_name
  virtual_network_name = local.fortigate_vnet_name
}

resource "azurerm_marketplace_agreement" "fortigate" {
  count = local.fortigate_enabled && try(var.fortigate.accept_marketplace_agreement, true) ? 1 : 0

  provider  = azurerm.connectivity
  publisher = var.fortigate.marketplace_publisher
  offer     = var.fortigate.marketplace_offer
  plan      = var.fortigate.marketplace_plan
}

resource "azurerm_public_ip" "fortigate" {
  for_each = local.fortigate_enabled && try(var.fortigate.create_public_ip, true) ? local.fortigate_instances : toset([])

  provider            = azurerm.connectivity
  name                = "${var.fortigate.name_prefix}-${var.fortigate.target_hub_key}-${each.value}-pip"
  location            = local.fortigate_hub.location
  resource_group_name = local.fortigate_resource_group_name
  allocation_method   = "Static"
  sku                 = var.fortigate.public_ip_sku
  tags                = local.fortigate_effective_tags
}

resource "azurerm_network_interface" "fortigate" {
  for_each = local.fortigate_instances

  provider                       = azurerm.connectivity
  name                           = "${var.fortigate.name_prefix}-${var.fortigate.target_hub_key}-${each.value}-nic"
  location                       = local.fortigate_hub.location
  resource_group_name            = local.fortigate_resource_group_name
  ip_forwarding_enabled          = true
  accelerated_networking_enabled = try(var.fortigate.accelerated_networking_enabled, true)
  auxiliary_mode                 = try(var.fortigate.accelerated_connections_enabled, false) ? "AcceleratedConnections" : "None"
  auxiliary_sku                  = try(var.fortigate.accelerated_connections_enabled, false) ? var.fortigate.accelerated_connections_sku : "None"
  tags                           = local.fortigate_effective_tags

  ip_configuration {
    name                          = "primary"
    subnet_id                     = data.azurerm_subnet.fortigate[0].id
    private_ip_address_allocation = var.fortigate.private_ip_address_allocation
    public_ip_address_id          = try(var.fortigate.create_public_ip, true) ? azurerm_public_ip.fortigate[each.value].id : null
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
      condition     = local.fortigate_subnet_name != null
      error_message = "fortigate.subnet_key was not found in the target hub virtual network subnets map."
    }
  }
}

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
    subnet_id                     = data.azurerm_subnet.fortigate[0].id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.fortigate.ilb_private_ip_address
  }

  lifecycle {
    precondition {
      condition     = try(var.fortigate.ilb_private_ip_address, null) != null
      error_message = "fortigate.ilb_private_ip_address must be set when fortigate.ilb_enabled is true."
    }
  }
}

resource "azurerm_lb_backend_address_pool" "fortigate" {
  count = local.fortigate_enabled && try(var.fortigate.ilb_enabled, true) ? 1 : 0

  provider        = azurerm.connectivity
  name            = var.fortigate.ilb_backend_address_pool_name
  loadbalancer_id = azurerm_lb.fortigate[0].id
}

resource "azurerm_network_interface_backend_address_pool_association" "fortigate" {
  for_each = local.fortigate_enabled && try(var.fortigate.ilb_enabled, true) ? local.fortigate_instances : toset([])

  provider                = azurerm.connectivity
  network_interface_id    = azurerm_network_interface.fortigate[each.value].id
  ip_configuration_name   = "primary"
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

resource "azurerm_linux_virtual_machine" "fortigate" {
  for_each = local.fortigate_instances

  provider              = azurerm.connectivity
  name                  = "${var.fortigate.name_prefix}-${var.fortigate.target_hub_key}-${each.value}-vm"
  location              = local.fortigate_hub.location
  resource_group_name   = local.fortigate_resource_group_name
  network_interface_ids = [azurerm_network_interface.fortigate[each.value].id]
  size                  = var.fortigate.vm_size

  admin_username                  = var.fortigate.admin_username
  admin_password                  = try(var.fortigate.disable_password_authentication, false) ? null : var.fortigate_admin_password
  disable_password_authentication = var.fortigate.disable_password_authentication

  source_image_reference {
    publisher = var.fortigate.marketplace_publisher
    offer     = var.fortigate.marketplace_offer
    sku       = var.fortigate.marketplace_sku
    version   = var.fortigate.marketplace_version
  }

  plan {
    publisher = var.fortigate.marketplace_publisher
    product   = var.fortigate.marketplace_offer
    name      = var.fortigate.marketplace_plan
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
