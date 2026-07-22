variable "fortigate" {
  type = object({
    enabled        = optional(bool, false)
    target_hub_key = optional(string, "primary")

    # Subnet keys (must exist in the target hub's hub_virtual_network.subnets map).
    # The A/P ELB-ILB HA design uses four dedicated subnets / NICs.
    external_subnet_key = optional(string, "fgt_external")
    internal_subnet_key = optional(string, "fgt_internal")
    hasync_subnet_key   = optional(string, "fgt_hasync")
    hamgmt_subnet_key   = optional(string, "fgt_hamgmt")

    name_prefix = optional(string, "fgt")
    # NOTE: 4 NICs require a VM size that supports >= 4 NICs. Production default is
    # Standard_F4as_v7 (AMD, 4 vCPU = FG-VM04, 4 NICs, 16 GB, no local disk, MANA).
    # Verify SKU availability/zones per subscription+region (see fortigate-readme.md).
    vm_size   = optional(string, "Standard_F4as_v7")
    instances = optional(list(string), ["01", "02"])
    # Availability Zone per instance (e.g. 01 -> zone 1, 02 -> zone 2). Empty map = no zones.
    zones = optional(map(string), { "01" = "1", "02" = "2" })

    admin_username                  = optional(string, "azureadmin")
    disable_password_authentication = optional(bool, false)
    admin_ssh_public_key            = optional(string, null)
    admin_ssh_public_key_path       = optional(string, null)

    private_ip_address_allocation = optional(string, "Dynamic")
    public_ip_sku                 = optional(string, "Standard")
    availability_zones_public_ip  = optional(list(string), ["1", "2", "3"])
    management_create_public_ip   = optional(bool, true)

    accelerated_networking_enabled  = optional(bool, true)
    accelerated_connections_enabled = optional(bool, false)
    accelerated_connections_sku     = optional(string, "A1")
    accelerated_connections_tags    = optional(map(string), {})

    # Internal Standard Load Balancer (east-west + egress from spokes; HA-ports).
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

    # External public Standard Load Balancer (north-south ingress/egress).
    elb_enabled                        = optional(bool, true)
    elb_name                           = optional(string, null)
    elb_sku                            = optional(string, "Standard")
    elb_frontend_ip_configuration_name = optional(string, "frontend")
    elb_backend_address_pool_name      = optional(string, "backend")
    elb_public_ip_name                 = optional(string, null)
    elb_probe_name                     = optional(string, "probe-tcp")
    elb_probe_port                     = optional(number, 8008)
    elb_outbound_rule_enabled          = optional(bool, true)
    elb_outbound_rule_name             = optional(string, "outbound")
    elb_outbound_allocated_ports       = optional(number, 8000)

    accept_marketplace_agreement = optional(bool, true)
    # Image/license selection: "byol" (production, incl. Free Trial licensing) or "payg".
    license_model         = optional(string, "byol")
    marketplace_publisher = optional(string, null)
    marketplace_offer     = optional(string, null)
    marketplace_sku       = optional(string, null)
    marketplace_version   = optional(string, null)
    marketplace_plan      = optional(string, null)

    custom_data                       = optional(string, null)
    custom_script_extension_enabled   = optional(bool, false)
    custom_script_extension_file_uris = optional(list(string), [])
    custom_script_extension_command   = optional(string, null)
    custom_script_extension_protected = optional(string, null)

    tags = optional(map(string), null)
  })
  default     = {}
  nullable    = false
  description = <<DESCRIPTION
FortiGate NVA deployment options for hub-and-spoke connectivity.

Deploys a redundant pair of FortiGate-VMs from the Azure Marketplace in an
Active/Passive HA design using an external (public) and internal Azure Standard
Load Balancer (the "LB sandwich"), following Fortinet best practices:
https://docs.fortinet.com/document/fortigate-public-cloud/7.0.0/azure-administration-guide/983245

Design notes:
- Four NICs per VM are used to match the Fortinet A/P ELB-ILB reference design:
  port1 external, port2 internal, port3 HA-sync, port4 HA-management. The
  Marketplace image can boot with a single NIC, but FGCP HA (heartbeat/config
  sync) and the dedicated HA management interface require the additional NICs.
  This is a compatibility/HA requirement, not an Azure security requirement.
- The VM size must support the number of NICs (>= 4). Standard_D8ds_v5 supports 4.
- Availability Zone redundancy: place the two VMs in different zones and use
  zone-redundant Standard public IPs and load balancer frontends.
- Marketplace publisher/offer/sku/plan can change over time. Verify availability
  in your target Azure region and update these values if needed.
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
    condition     = try(var.fortigate.elb_sku, "Standard") == "Standard"
    error_message = "fortigate.elb_sku must be 'Standard' (HA ports and zone redundancy require the Standard SKU)."
  }

  validation {
    condition     = contains(["A1", "A2", "A4", "A8", "None"], try(var.fortigate.accelerated_connections_sku, "A1"))
    error_message = "fortigate.accelerated_connections_sku must be one of 'A1', 'A2', 'A4', 'A8', or 'None'."
  }

  validation {
    condition     = contains(["byol", "payg"], lower(try(var.fortigate.license_model, "byol")))
    error_message = "fortigate.license_model must be either 'byol' or 'payg'. The FortiGate-VM Free Trial uses the 'byol' image (licensed via FortiCloud)."
  }

  validation {
    condition     = alltrue([for z in values(try(var.fortigate.zones, {})) : contains(["1", "2", "3"], z)])
    error_message = "fortigate.zones values must be one of '1', '2', or '3'."
  }
}

variable "fortigate_admin_password" {
  type        = string
  default     = null
  sensitive   = true
  description = "Admin password for FortiGate VMs. Required when fortigate.enabled=true and password auth is enabled."
}
