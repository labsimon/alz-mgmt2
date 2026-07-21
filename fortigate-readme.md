# FortiGate Deployment Notes (deploy-forti)

## Session Goal
Deploy FortiGate as an NVA pair in the ALZ hub connectivity VNet, using Azure Marketplace image, SSH auth, and high-performance networking settings.

## Design Decisions
- Keep ALZ hub-and-spoke model and existing NVA subnet (`subnet_key = "nva"`).
- Deploy 2 FortiGate instances for appliance redundancy.
- Use Azure Marketplace image for FortiGate instead of custom binary install.
- Use SSH authentication only (`disable_password_authentication = true`).
- Read SSH public key from local path (`fortigate.admin_ssh_public_key_path`) to avoid hardcoding key content.
- Enable Accelerated Networking on NICs (`accelerated_networking_enabled = true`).
- Enable Accelerated Connections by setting NIC auxiliary mode and tier (`auxiliary_mode = "AcceleratedConnections"`, `auxiliary_sku = "A1"` by default).
- Include explicit `accelerated_connections_tags` input so Microsoft-provided limited-GA tags can be applied during deployment.
- Use a v5 VM family SKU default (`Standard_D8ds_v5`) to align with high-throughput NVA patterns and Accelerated Networking support expectations.
- Place an Internal Load Balancer (ILB) in front of FortiGate data-plane NICs and use the ILB frontend IP as the hub router next hop.
- Add explicit User Subnets UDR entries for default route and on-premises prefixes to ensure deterministic egress and hybrid pathing via FortiGate.

## Manual Prerequisites
1. Limited GA enrollment for Accelerated Connections:
- Sign up via Microsoft form: https://go.microsoft.com/fwlink/?linkid=2223706
- Without enrollment, deployments using accelerated connections can fail.
- After approval, add any required Microsoft-provided tags in `fortigate.accelerated_connections_tags`.

2. Region support check:
- Ensure your target region supports Accelerated Connections.
- Your current region is `uksouth` (South UK), which is listed in Microsoft Learn as supported, but confirm current status in tenant.

3. Marketplace image and plan availability:
- Verify Fortinet publisher/offer/sku/plan values are available in the target region and subscription.
- If different in your tenant, adjust the `fortigate.marketplace_*` values.

4. SSH key file exists on the machine running Terraform:
- Current default path in tfvars is `~/.ssh/id_rsa.pub`.
- Change to your real public key path if different.

5. Azure role permissions:
- Ensure permissions for NIC/VM/PIP creation in connectivity subscription/resource group.
- Ensure permission to accept Marketplace agreements when `accept_marketplace_agreement = true`.

## Files Added/Updated
- Added: `main.connectivity.fortigate.tf`
- Added: `variables.fortigate.tf`
- Updated: `platform-landing-zone.auto.tfvars`
- Updated: `outputs.tf`

## What the Terraform Now Does
- Resolves hub VNet and NVA subnet from ALZ hub settings.
- Creates optional public IP per FortiGate VM.
- Creates NICs with:
  - `ip_forwarding_enabled = true`
  - `accelerated_networking_enabled = true` (configurable)
  - `auxiliary_mode = "AcceleratedConnections"` when enabled
  - `auxiliary_sku` tier (A1/A2/A4/A8)
- Creates an internal Standard Load Balancer and backend association for both FortiGate NICs.
- Creates a HA-ports load-balancing rule and probe so traffic is distributed to active FortiGate instances through one stable frontend IP.
- Creates FortiGate VMs from Marketplace image + plan.
- Configures SSH authentication using either:
  - inline key content, or
  - key file path (`admin_ssh_public_key_path`), read at plan/apply time.
- Optional Custom Script Extension remains available but disabled by default.
- Updates hub router and explicit User Subnets route-table entries to point to the ILB frontend IP.

## Deployment Steps for this PR
1. Confirm branch:
- `git branch --show-current`
- Expected: `deploy-forti`

2. Confirm key path in tfvars:
- `fortigate.admin_ssh_public_key_path`

3. Initialize/refresh providers:
- `terraform init -upgrade`

4. Validate:
- `terraform validate`

5. Plan:
- `terraform plan -out tfplan`

6. Apply:
- `terraform apply tfplan`

## Manual Steps Potentially Required During Deployment
- Marketplace agreement acceptance can require permissions or tenant policy exemptions.
- Accelerated Connections can be blocked if the subscription is not enrolled for limited GA.
- If `Standard_D8ds_v5` is unavailable in region/quota, choose another Accelerated Networking-capable SKU (preferably v5 family for this scenario).

## Post-Deployment Verification
- Verify both FortiGate VMs are running.
- Confirm NIC properties show:
  - Accelerated Networking enabled
  - Auxiliary mode set to AcceleratedConnections
  - Auxiliary SKU set as configured
- Verify route tables direct intended traffic to the FortiGate next hop.
- Validate management access over SSH and FortiGate control-plane access pattern.

## Notes / Next Work
- For production-grade failover, add an Internal Load Balancer in front of FortiGate data-plane NICs and route to ILB frontend IP.
- Add explicit UDR entries for default route and on-prem prefixes if not already defined by hub routing model.
- Add health probes and failover logic consistent with Fortinet HA guidance.

## TODOs For Optional Next Step 2 (GatewaySubnet Routes Via ILB)
Required todos to steer gateway-originated traffic through FortiGate ILB:

1. Enable GatewaySubnet route-table creation in hub virtual network settings.
- In the virtual_network_gateways block, set route_table_creation_enabled = true.

2. Disable the Azure Firewall-specific default route behavior for GatewaySubnet.
- Set route_table_gateway_firewall_route_enabled = false.
- Reason: this flag is intended for Azure Firewall next-hop logic and can conflict with FortiGate ILB routing intent.

3. Add explicit GatewaySubnet custom routes to the FortiGate ILB frontend IP.
- Add route_table_custom_routes entries with next_hop_type = VirtualAppliance and next_hop_ip_address = $${primary_fortigate_ilb_ip}.
- Include at minimum:
  - default route 0.0.0.0/0 (if your design sends all gateway-originated egress through FortiGate)
  - on-prem prefixes used in your hybrid topology (for this session: 172.16.0.0/12 and 192.168.0.0/16)

4. Confirm BGP propagation behavior to avoid route asymmetry.
- Decide if route_table_bgp_route_propagation_enabled should remain false or be enabled based on your ER/VPN pathing policy.
- Validate that effective GatewaySubnet routes still prefer the intended FortiGate ILB next hop for selected prefixes.

5. Plan and validate route outcomes before apply in production windows.
- Run terraform plan and verify GatewaySubnet route table changes.
- Check for overlap/conflict with existing ER/VPN learned routes.

6. Post-apply verification checklist.
- Confirm GatewaySubnet route table exists and contains the custom routes.
- Validate effective routes on gateway-related paths and representative spoke workloads.
- Run north-south and hybrid connectivity tests to confirm symmetric forward/return path through FortiGate where required.
