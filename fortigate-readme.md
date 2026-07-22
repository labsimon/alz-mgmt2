# FortiGate Deployment Notes (deploy-forti)

## Session Goal
Deploy FortiGate as an NVA pair in the ALZ hub connectivity VNet, using Azure Marketplace image, SSH auth, and high-performance networking settings.

## Design Decisions
- Keep ALZ hub-and-spoke model with dedicated FortiGate subnets in the hub VNet.
- Deploy 2 FortiGate instances in an **Active/Passive HA** design using the Fortinet **external + internal Standard Load Balancer** ("LB sandwich") pattern — NOT the SDN-connector failover variant.
- Use Azure Marketplace image for FortiGate instead of custom binary install.
- **Four NICs per VM** (port1 external, port2 internal, port3 HA-sync, port4 HA-management) to match Fortinet's A/P ELB-ILB reference. The Marketplace image can boot with a single NIC, but FGCP HA (heartbeat/config sync) and the dedicated HA management interface require the extra NICs. This is a compatibility/HA requirement, not an Azure security requirement (Azure SDN already isolates traffic).
- VM size `Standard_D8ds_v5` because 4 NICs require a size supporting >= 4 NICs (D4ds_v5 supports only 2).
- **Availability Zone redundancy**: VM 01 -> Zone 1, VM 02 -> Zone 2; zone-redundant Standard public IPs and load-balancer frontends (99.99% SLA target).
- Use SSH authentication only (`disable_password_authentication = true`) with a local key path (`fortigate.admin_ssh_public_key_path`).
- Internal LB frontend IP (`10.0.1.68`, in the internal subnet) is the spoke egress next hop (`hub_router_ip_address` + spoke enforcement policy `nvaIpAddress`).
- External public LB provides north-south ingress/egress; egress SNAT via an outbound rule; per-VM management public IPs on port4.
- Enable Accelerated Networking on the data NICs; Accelerated Connections optional (disabled by default).
- Force all spoke egress through the FortiGate via an ALZ policy (see below).

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
- Current path in tfvars is `~/.ssh/adm-simon.pub` (`fortigate.admin_ssh_public_key_path`).
- Change to your real public key path if different. The file must exist at plan/apply time (it is read with `file(pathexpand(...))`).

5. Azure role permissions:
- Ensure permissions for NIC/VM/PIP/LB creation in the connectivity subscription/resource group.
- Ensure permission to accept Marketplace agreements when `accept_marketplace_agreement = true`.

6. FortiGate licensing model:
- Current config uses a PAYG plan (`fortinet_fg-vm_payg_2023`) — no license file required.
- For BYOL/FortiFlex, change the marketplace plan/SKU and inject the license via `custom_data` (bootstrap) or FortiManager after boot.

7. Redundancy placement (Availability Zones):
- For a truly redundant pair, the two FortiGate VMs should be placed in different Availability Zones (or an Availability Set). The current code does not set `zone` on the VMs/PIPs/ILB — see "Redundancy Requirements" below.

## Files Added/Updated
- Added: `main.connectivity.fortigate.tf`
- Added: `variables.fortigate.tf`
- Added: `fortigate-readme.md`
- Added: `lib/policy_definitions/Deploy-Spoke-RouteTable-NVA.alz_policy_definition.json`
- Added: `lib/policy_assignments/Deploy-Spoke-RouteTable-NVA.alz_policy_assignment.json`
- Updated: `lib/archetype_definitions/landing_zones_custom.alz_archetype_override.yaml`
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

## Forcing ALL Spoke Egress Through FortiGate (REQUIRED)
Goal: every packet that leaves a spoke VNet must be forwarded to the FortiGate ILB (`10.0.0.5`) as next hop `VirtualAppliance`.

Why the current hub config is NOT sufficient on its own:
- The `route_table_entries_user_subnets` and `hub_router_ip_address` settings in `hub_virtual_networks.primary` apply ONLY to route tables associated with subnets INSIDE the hub VNet.
- Spoke VNets are separate networks (typically their own landing-zone subscriptions). They are NOT covered by the hub route tables. Without an explicit spoke UDR, spoke traffic uses default system routes and BYPASSES the FortiGate.

Required to force spoke egress (choose ONE implementation approach):

1. Define the spoke route table (UDR) content. Each spoke subnet must have a route table containing at least:
- `0.0.0.0/0` -> next_hop_type `VirtualAppliance` -> next_hop_ip `10.0.0.5` (default egress via FortiGate)
- `172.16.0.0/12` -> `VirtualAppliance` -> `10.0.0.5` (on-prem / RFC1918)
- `192.168.0.0/16` -> `VirtualAppliance` -> `10.0.0.5`
- `10.0.0.0/8` (or your enterprise RFC1918 supernet) -> `VirtualAppliance` -> `10.0.0.5` so spoke-to-spoke and spoke-to-hub also traverse FortiGate.
- Set `disableBgpRoutePropagation = true` (BGP route propagation disabled) on the spoke route table, so ER/VPN gateway routes cannot override the `0.0.0.0/0` route to the NVA.

2. Apply the UDR to EVERY spoke subnet. Options:
- (a) Azure Policy (DINE) at the Landing Zones management group that deploys/associates a route table with `0.0.0.0/0` -> FortiGate ILB IP to every spoke subnet. THIS IS NOW IMPLEMENTED in this repo — see "Route Enforcement Policy (Implemented)" below.
- (b) Subscription/subnet vending: define the route table centrally and reference its ID in each spoke subnet definition when spokes are provisioned.
- (c) Manual per-spoke UDR (only acceptable for a small, fixed number of spokes).

3. Ensure return-path symmetry on FortiGate:
- FortiGate must know all spoke/hub prefixes (static routes or SDN connector) and must SNAT or have matching return routes to avoid asymmetric routing/black-holing.
- Confirm intra-region and hybrid (ER/VPN) return traffic also lands on the FortiGate.

4. Do NOT rely on `hub_router_ip_address` alone to steer spokes — it only seeds hub-internal route tables.

Note: GatewaySubnet routing (traffic entering from ER/VPN toward spokes) is covered separately in the "TODOs For Optional Next Step 2" section below.

## Route Enforcement Policy (Implemented)
A custom DeployIfNotExists (DINE) Azure Policy now enforces that spoke subnets route their egress through the FortiGate NVA. It is assigned to the **Landing Zones** management group so it automatically covers current and future spoke subscriptions under that MG.

Files:
- `lib/policy_definitions/Deploy-Spoke-RouteTable-NVA.alz_policy_definition.json` — custom DINE policy definition. Targets `Microsoft.Network/virtualNetworks/subnets`; if a subnet has no route table it deploys one with `0.0.0.0/0 -> VirtualAppliance -> nvaIpAddress` and `disableBgpRoutePropagation = true`, then associates it to the subnet.
- `lib/policy_assignments/Deploy-Spoke-RouteTable-NVA.alz_policy_assignment.json` — assignment `Deploy-Spoke-RT-NVA` (SystemAssigned identity, effect `DeployIfNotExists`).
- `lib/archetype_definitions/landing_zones_custom.alz_archetype_override.yaml` — adds the definition (`policy_definitions_to_add`) and the assignment (`policy_assignments_to_add`) to the `landing_zones` archetype.
- `platform-landing-zone.auto.tfvars` — `management_group_settings.policy_assignments_to_modify.landingzones` sets `nvaIpAddress = $${primary_fortigate_ilb_ip}` (single source of truth: `10.0.0.5`).

How it works:
- The Landing Zones MG (`landingzones`) uses the `landing_zones_custom` archetype, so the assignment lands there and inherits down to Corp/Online/Local spokes.
- The policy's SystemAssigned managed identity is granted `Network Contributor` (role id `4d97b98b-1d4f-4787-a291-c67834d212e7`) via the DINE `roleDefinitionIds`; the ALZ module creates the role assignment automatically.
- Well-known platform subnets are excluded by default: `GatewaySubnet`, `AzureFirewallSubnet`, `AzureFirewallManagementSubnet`, `AzureBastionSubnet`, `RouteServerSubnet`.

Prerequisites / behaviour to be aware of:
- The assignment `location` is hardcoded to `uksouth` in the assignment file — change it if you deploy to another region (needed for the managed identity).
- Existence check is "subnet already has ANY route table". Subnets that already have a route table are NOT modified (to avoid clobbering intentional custom routing). For strict enforcement, pair this with an Audit/Deny policy for route tables that lack the NVA default route, or manage those subnets via subnet vending.
- Remediation deploys a subnet PUT with `addressPrefix` + `routeTable`. Existing subnets that already have NSG/delegations should already have a route table (and thus be skipped); brand-new spoke subnets are the primary target. Validate with `terraform plan` and a policy compliance scan before relying on it in production.
- Existing non-compliant subnets require a remediation task (the DINE identity remediates new/updated subnets automatically; pre-existing ones need an on-demand remediation task).

## Redundancy Requirements (Pair of FortiGate NVAs)
Implemented in Terraform:
- **Availability Zones**: VM 01 in Zone 1, VM 02 in Zone 2 (`fortigate.zones`); zone-redundant Standard public IPs and LB frontends (`availability_zones_public_ip = ["1","2","3"]`).
- **LB sandwich**: external public Standard LB (`azurerm_lb.fortigate_external`) + internal Standard LB (`azurerm_lb.fortigate`) with HA-ports rule, floating IP and TCP/8008 health probes.
- **4 NICs per VM** on dedicated subnets (external/internal/hasync/hamgmt).

Still required as manual FortiGate OS-level configuration (not Terraform):
1. **FGCP Unicast HA** between the two units over port3 (HA-sync), with `ha-mgmt-interfaces` on port4. Inject via `fortigate.custom_data` (cloud-init) or configure post-boot. See the Fortinet default config in the ELB-ILB reference.
2. **Health-probe responder**: `config system probe-response / set mode http-probe` and `allowaccess probe-response` on port1/port2 so the Azure LB (probe source 168.63.129.16) marks the active unit healthy; add static routes for 168.63.129.16 via each data interface gateway.
3. **Manual secondary-node steps (Fortinet documented)**: in A/P on Azure you must set the port1 IP and tunnel interface IPs manually on the secondary FortiGate (HA does not sync these); loopback config must be copied manually.
4. **Licensing**: PAYG (current) needs no license file; for BYOL/FLEX inject the `.lic` via cloud-init MIME multipart.

## Notes / Next Work
- Spoke-egress enforcement is implemented via the `Deploy-Spoke-RT-NVA` policy on the Landing Zones MG. Run an on-demand remediation task for pre-existing spoke subnets.
- Provide the FGCP HA + probe-response bootstrap via `fortigate.custom_data` for both units (per-instance config differs: priority, unicast peer IP).
- Consider a companion Audit/Deny policy for spoke route tables that lack the NVA default route (strict enforcement).
- Publish inbound services by adding external-LB load-balancing rules + FortiGate VIPs as needed.

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

## Appendix: HA Design Evaluation — Active/Passive (chosen) vs Active/Active
This appendix records why we chose Active/Passive with load balancers (A/P) over Active/Active (A/A), with the primary decision criterion being **robustness / stability / reliability**.

References:
- A/P: https://docs.fortinet.com/document/fortigate-public-cloud/7.0.0/azure-administration-guide/983245 and https://github.com/fortinet/azure-templates/tree/main/FortiGate/Active-Passive-ELB-ILB
- A/A: https://github.com/fortinet/azure-templates/tree/main/FortiGate/Active-Active-ELB-ILB

### Core difference
- **A/P (our choice):** Two FortiGates form ONE cluster via **FGCP Unicast HA**. One unit active, one standby. FGCP synchronizes **configuration and sessions automatically**.
- **A/A:** Two (up to 8) **independent standalone** FortiGates, all active. **No FGCP.** Config sync only via `config system auto-scale` (or FortiManager); session sync optional via **FGSP**.

### Comparison (reliability focus)
| Criterion | A/P with LB (chosen) | A/A with LB |
|---|---|---|
| Traffic symmetry | Symmetric by design (single active unit) | Asymmetry risk -> requires SNAT or FGSP |
| Security inspection (IPS/UTM) | Full efficacy (unit sees both directions) | FGSP asymmetry reduces IPS efficacy (Fortinet warning); SNAT loses source IP |
| Configuration sync | Automatic via FGCP (mature, robust) | `auto-scale`/FortiManager -> more parts, higher drift risk |
| Session sync | FGCP session-pickup (integrated) | FGSP (separate to configure/maintain) |
| Failure modes / troubleshooting | Deterministic, simple (one active path) | More complex (two active paths, state consistency) |
| Failover | LB probe 2x/5s, max 15s | Same probe, but state consistency harder |
| Scale / throughput | Only 1 unit active (half capacity idle) | Higher aggregate throughput, horizontal up to 8 units |
| NIC topology | 4 NICs (ext/int/hasync/hamgmt) | 2 NICs (ext/int) — simpler |
| Availability Zones | Yes (Zone 1/2) | Yes (Zone 1/2) |

### Verdict (robust / stable / reliable)
A/P is the better fit for this criterion because:
1. **Deterministic symmetry** — all traffic traverses the active unit, so no asymmetry and no state race conditions; behaviour is predictable and stable.
2. **Integrity-strong sync** — FGCP synchronizes config AND sessions natively; A/A relies on two separate, independently maintained mechanisms (auto-scale + FGSP), adding failure sources and drift risk.
3. **Full security inspection** — A/A trades scale for compromises (FGSP asymmetry weakens IPS, or SNAT loses the source IP). For reliable security that is a regression.

A/A is advantageous only for raw **throughput / horizontal scale** (both units active). That is a performance benefit, not a reliability benefit.

### Decision
For the top criterion (robustness/stability/reliability) we keep **Active/Passive with LB**. Consider A/A only if a single active FortiGate VM becomes a throughput bottleneck — and even then prefer vertical scaling (larger VM SKU) before accepting A/A complexity (FGSP/auto-scale, SNAT trade-offs).

## Appendix: VM SKU Selection
Reference: Fortinet instance-type support https://docs.fortinet.com/document/fortigate-public-cloud/7.6.0/azure-administration-guide/562841/instance-type-support

### Key sizing facts
- **FortiGate BYOL license is priced per vCPU** (`FG-VM04` = 4 vCPU, `FG-VM08` = 8 vCPU). Minimizing vCPUs while still getting 4 NICs is the main cost lever.
- **4 NICs are required** for the A/P ELB-ILB design (port1 external, port2 internal, port3 HA-sync, port4 HA-mgmt).
- The `MaxNetworkInterfaces` value in Azure is authoritative and can differ from Fortinet's table. Verify with `az vm list-skus -l <region> --all` before committing.
- SKU/zone availability is **subscription- and region-specific**. Check with:
  ```
  az vm list-skus -l <region> --resource-type virtualMachines --all \
    --query "[?name=='Standard_F4as_v7'].{Name:name, Zones:locationInfo[0].zones, MaxNICs:capabilities[?name=='MaxNetworkInterfaces'].value|[0], Restriction:restrictions[0].reasonCode}" -o json
  ```

### Production recommendation (Salzgitter, germanywestcentral)
- **`Standard_F4as_v7`** — 4 vCPU (**FG-VM04**), **4 NICs**, 16 GB RAM, AMD EPYC 9005, compute-optimized, MANA. Best cost/performance for the 4-NIC A/P HA pair.
  - Note: the low-memory `F4als_v7` variant only supports **2 NICs** in Azure (despite Fortinet's table) — do NOT use it for the 4-NIC design. The base `F4as_v7` provides 4 NICs.
  - Available in germanywestcentral **zones 2+3** → AZ mapping `zones = { "01" = "2", "02" = "3" }`.
  - Currently `NotAvailableForSubscription` → requires a **quota/enablement request** in the connectivity subscription.
  - MANA family → requires **FortiOS 7.6.1+ / 8.0.0+** (our BYOL `_76` image with `version = "latest"` satisfies this).
  - Confirm Fasv7 support with Fortinet SE/FortiCare for production sign-off (same AMD/MANA platform as the listed Falsv7).
- Conservative fallback (no MANA, proven): `Standard_D8s_v5` / `Standard_D8ds_v5` — 8 vCPU (**FG-VM08**, higher license tier), 4 NICs, FortiOS 7.4.2+.

### MCAPS pre-test recommendation
- uksouth is **not enabled** in the MCAPS subscriptions (0 SKUs) → run the test in **germanywestcentral** (`starter_locations = ["germanywestcentral"]`).
- Older 4-NIC families (D8s_v5, DS3_v2, …) are `NotAvailableForSubscription` (quota-blocked) in the MCAPS sub, but the newest **`Standard_D4s_v7`** is available **without quota** (4 vCPU, 4 NICs, 16 GB) — **Zone 3 only**.
- Test profile: `vm_size = "Standard_D4s_v7"`, `instances = ["01"]` (or both in Zone 3), `license_model = "byol"` licensed as **FortiGate-VM Free Trial** via FortiCloud.
- Free Trial limits: **1 vCPU, ~1 Gbps, no HA** → functional/routing test only, not HA-failover validation.
- Verify availability in the subscription where the FortiGates deploy (connectivity `3f619ed6-...`), not only the management subscription.
