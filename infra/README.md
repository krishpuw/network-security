# infra/

Bicep for the lab network. Step 1 of the build order: one VNet, VLSM subnets, a default-deny NSG on every subnet, and route tables that switch on once the pfSense/OPNsense VM exists.

| File | What it deploys |
| --- | --- |
| `main.bicep` | VNet, 7 subnets, 7 NSGs, optional route tables (resource group scope) |
| `modules/nsg.bicep` | One NSG from a compact rule list, always ending in deny-all at priority 4096 |
| `budget.bicep` | Monthly budget with 50% / 80% / 100%-forecast email alerts (subscription scope) |
| `main.bicepparam` | Parameters. Copy to `main.local.bicepparam` (git-ignored) for your own IP |
| `deploy.sh` | `what-if`, confirm, then deploy |

## VLSM plan

`10.0.0.0/16`, allocated largest block first so every block lands on its own boundary. Azure reserves 5 addresses per subnet (network, gateway, 2 x DNS, broadcast), so the first usable host is always `.4` of the block.

| Subnet | Prefix | Range | Usable | Purpose |
| --- | --- | --- | --- | --- |
| `snet-lan` | `10.0.0.0/24` | 10.0.0.0 - 10.0.0.255 | 251 | Internal "corporate" hosts |
| `snet-dmz` | `10.0.1.0/26` | 10.0.1.0 - 10.0.1.63 | 59 | Web server, later the LLM firewall proxy |
| `snet-targets` | `10.0.1.64/27` | 10.0.1.64 - 10.0.1.95 | 27 | Metasploitable, no internet in or out |
| `snet-attacker` | `10.0.1.96/28` | 10.0.1.96 - 10.0.1.111 | 11 | Kali |
| `snet-honeypot` | `10.0.1.112/28` | 10.0.1.112 - 10.0.1.127 | 11 | Cowrie, the only public IP |
| `snet-fw-untrust` | `10.0.1.128/28` | 10.0.1.128 - 10.0.1.143 | 11 | pfSense WAN NIC |
| `snet-fw-trust` | `10.0.1.144/28` | 10.0.1.144 - 10.0.1.159 | 11 | pfSense LAN NIC (`10.0.1.148`) |
| free | `10.0.1.160` - `10.0.255.255` | | | Room for Bastion, an LLM subnet, etc. |

## Segmentation

Every NSG ends in `Deny-All-Inbound` and `Deny-All-Outbound` at 4096, which overrides Azure's built-in `AllowVnetInBound` / `AllowInternetOutBound`. Everything else is an explicit allow or an explicit deny placed above the allows.

| From \ To | LAN | DMZ | Targets | Attacker | Honeypot | Internet |
| --- | --- | --- | --- | --- | --- | --- |
| **LAN** | all | 80, 443 | - | - | - | 80, 443 |
| **DMZ** | **denied (both NSGs)** | | - | - | - | 80, 443 |
| **Targets** | - | - | | all (reverse shells) | - | **denied** |
| **Attacker** | **denied** | 80, 443 | all | | 22, 23 | 80, 443 |
| **Honeypot** | **denied** | - | - | - | | 80, 443 |
| **Internet** | - | - | **denied** | admin IP: 22, 3389 | 22, 23 (+ admin 22222) | |

All subnets with an agent may also reach the `AzureMonitor` service tag on 443 for log shipping. Admin rules only exist when `adminSourceAddress` is set.

Two rules worth knowing for the detections later:

- **DMZ -> LAN** is denied at the source (`Deny-DMZ-to-LAN-Out` on the DMZ NSG) and at the destination (`Deny-DMZ-to-LAN` on the LAN NSG). Either one showing up as a denied flow is the "DMZ -> LAN violation" signal.
- **Targets -> Attacker** is allowed on any port on purpose, so reverse shells work and the T1571 non-standard-port rule has real traffic to fire on.

## Firewall routing

Deploy with `firewallTrustIp = ''` first. Once the pfSense/OPNsense VM is up with its trust NIC on `10.0.1.148` (and IP forwarding on), set `firewallTrustIp = '10.0.1.148'` and redeploy. That creates a route table per workload subnet that sends traffic for every other workload subnet, plus `0.0.0.0/0`, to pfSense. The honeypot gets the inter-subnet routes but no default route, because it answers the internet from its own public IP.

`allowDefaultOutbound` (default `true`) keeps Azure's implicit outbound access on LAN, DMZ, Attacker and Honeypot so `apt` works before pfSense exists. `snet-targets` never has it. Set it to `false` once pfSense is the egress path.

## Deploy

```bash
az login
az account set --subscription "<your subscription>"

# Day one: budget alert
az deployment sub create -l eastus -f infra/budget.bicep -p contactEmail=<you@example.com> amount=50

# Network
cp infra/main.bicepparam infra/main.local.bicepparam   # set adminSourceAddress to your IP/32
./infra/deploy.sh rg-seclab eastus
```

Everything in step 1 (VNet, subnets, NSGs, route tables) is free. Cost starts with VMs and Log Analytics ingestion.

## Notes for step 2

New NSG flow logs can no longer be created (Azure stopped accepting them after 30 June 2025, and they retire in September 2027). Use **VNet flow logs** on `vnet-seclab` instead. They cover every subnet in one place, record the NSG rule that allowed or denied each flow, and feed Traffic Analytics the same way.
