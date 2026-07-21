variable "fortigate" {
  type = object({
    enabled                            = optional(bool, false)
    target_hub_key                     = optional(string, "primary")
    subnet_key                         = optional(string, "nva")
    name_prefix                        = optional(string, "fgt")
    vm_size                            = optional(string, "Standard_D8ds_v5")
    instances                          = optional(list(string), ["01", "02"])
    admin_username                     = optional(string, "azureadmin")
    disable_password_authentication    = optional(bool, false)
    admin_ssh_public_key               = optional(string, null)
    admin_ssh_public_key_path          = optional(string, null)
    create_public_ip                   = optional(bool, true)
    public_ip_sku                      = optional(string, "Standard")
    private_ip_address_allocation      = optional(string, "Dynamic")
    ilb_enabled                        = optional(bool, true)
    ilb_name                           = optional(string, null)
    ilb_sku                            = optional(string, "Standard")
    ilb_frontend_ip_configuration_name = optional(string, "frontend")
    ilb_backend_address_pool_name      = optional(string, "backend")
    ilb_private_ip_address             = optional(string, null)
    ilb_probe_name                     = optional(string, "probe-tcp")
    ilb_probe_port                     = optional(number, 8008)
    ilb_ha_ports_rule_enabled          = optional(bool, true)
    ilb_ha_ports_rule_name             = optional(string, "ha-ports")
    accelerated_networking_enabled     = optional(bool, true)
    accelerated_connections_enabled    = optional(bool, false)
    accelerated_connections_sku        = optional(string, "A1")
    accelerated_connections_tags       = optional(map(string), {})
    accept_marketplace_agreement       = optional(bool, true)
    marketplace_publisher              = optional(string, "fortinet")
    marketplace_offer                  = optional(string, "fortinet_fortigate-vm_v5")
    marketplace_sku                    = optional(string, "fortinet_fg-vm_payg_2023")
    marketplace_version                = optional(string, "latest")
    marketplace_plan                   = optional(string, "fortinet_fg-vm_payg_2023")
    custom_data                        = optional(string, null)
    custom_script_extension_enabled    = optional(bool, false)
    custom_script_extension_file_uris  = optional(list(string), [])
    custom_script_extension_command    = optional(string, null)
    custom_script_extension_protected  = optional(string, null)
    tags                               = optional(map(string), null)
  })
  default     = {}
  nullable    = false
  description = <<DESCRIPTION
FortiGate NVA deployment options for hub-and-spoke connectivity.

This configuration deploys a pair of FortiGate VMs into an existing hub subnet
(e.g., subnet key "nva") and uses a Marketplace image by default.

Important:
- Marketplace publisher/offer/sku/plan can change over time. Verify availability
  in your target Azure region and update these values if needed.
- For production, use robust HA design and route convergence/failover controls.
- You can provide SSH key content directly or provide a local file path with
  fortigate.admin_ssh_public_key_path.
DESCRIPTION

  validation {
    condition     = length(try(var.fortigate.instances, [])) == 0 || length(distinct(try(var.fortigate.instances, []))) == length(try(var.fortigate.instances, []))
    error_message = "fortigate.instances must contain unique identifiers."
  }

  validation {
    condition     = contains(["Basic", "Standard"], try(var.fortigate.public_ip_sku, "Standard"))
    error_message = "fortigate.public_ip_sku must be either 'Basic' or 'Standard'."
  }

  validation {
    condition     = contains(["Dynamic", "Static"], try(var.fortigate.private_ip_address_allocation, "Dynamic"))
    error_message = "fortigate.private_ip_address_allocation must be either 'Dynamic' or 'Static'."
  }

  validation {
    condition     = contains(["Basic", "Standard"], try(var.fortigate.ilb_sku, "Standard"))
    error_message = "fortigate.ilb_sku must be either 'Basic' or 'Standard'."
  }

  validation {
    condition     = contains(["A1", "A2", "A4", "A8", "None"], try(var.fortigate.accelerated_connections_sku, "A1"))
    error_message = "fortigate.accelerated_connections_sku must be one of 'A1', 'A2', 'A4', 'A8', or 'None'."
  }
}

variable "fortigate_admin_password" {
  type        = string
  default     = null
  sensitive   = true
  description = "Admin password for FortiGate VMs. Required when fortigate.enabled=true and password auth is enabled."
}
