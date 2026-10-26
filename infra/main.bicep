// Azure Network Security Lab - build order step 1
// VNet 10.0.0.0/16 split with VLSM, one default-deny NSG per subnet,
// DMZ -> LAN blocked in both directions, optional UDRs through pfSense.

targetScope = 'resourceGroup'

import { nsgRule } from 'modules/nsg.bicep'

@description('Short name used as a prefix for every resource.')
param prefix string = 'seclab'

param location string = resourceGroup().location

param vnetAddressSpace string = '10.0.0.0/16'

@description('VLSM plan, allocated largest block first. See infra/README.md.')
param subnetPrefixes object = {
  lan: '10.0.0.0/24'
  dmz: '10.0.1.0/26'
  targets: '10.0.1.64/27'
  attacker: '10.0.1.96/28'
  honeypot: '10.0.1.112/28'
  fwUntrust: '10.0.1.128/28'
  fwTrust: '10.0.1.144/28'
}

@description('Your own public IP in CIDR form (e.g. 203.0.113.7/32). Empty = no admin rules are created.')
param adminSourceAddress string = ''

@description('Private IP of the pfSense/OPNsense trust NIC. Empty = no route tables yet (deploy the firewall first, then redeploy with this set).')
param firewallTrustIp string = ''

@description('Default outbound internet access for the lan, dmz, attacker and honeypot subnets until pfSense is the egress path. The targets subnet never gets it.')
param allowDefaultOutbound bool = true

param tags object = {
  project: 'network-security-lab'
  environment: 'lab'
}

var p = subnetPrefixes
var hasAdmin = !empty(adminSourceAddress)
var useFirewall = !empty(firewallTrustIp)

// ---------- Reusable rules ----------

var allowAzureMonitorOut = {
  name: 'Allow-AzureMonitor-Out'
  priority: 300
  direction: 'Outbound'
  access: 'Allow'
  protocol: 'Tcp'
  source: '*'
  destination: 'AzureMonitor'
  ports: ['443']
  description: 'Azure Monitor Agent log shipping to Log Analytics / Sentinel.'
}

var allowWebOut = {
  name: 'Allow-Internet-Web-Out'
  priority: 310
  direction: 'Outbound'
  access: 'Allow'
  protocol: 'Tcp'
  source: '*'
  destination: 'Internet'
  ports: ['80', '443']
  description: 'Package updates.'
}

// ---------- Per-subnet rules ----------

var lanRules nsgRule[] = [
  {
    name: 'Deny-DMZ-to-LAN'
    priority: 100
    direction: 'Inbound'
    access: 'Deny'
    protocol: '*'
    source: p.dmz
    destination: p.lan
    ports: ['*']
    description: 'Core segmentation rule: a compromised DMZ host must not reach the LAN.'
  }
  {
    name: 'Deny-Honeypot-to-LAN'
    priority: 110
    direction: 'Inbound'
    access: 'Deny'
    protocol: '*'
    source: p.honeypot
    destination: p.lan
    ports: ['*']
  }
  {
    name: 'Deny-Attacker-to-LAN'
    priority: 120
    direction: 'Inbound'
    access: 'Deny'
    protocol: '*'
    source: p.attacker
    destination: p.lan
    ports: ['*']
    description: 'Kali reaches the LAN only by pivoting, which these rules should stop.'
  }
  {
    name: 'Allow-LAN-Intra-In'
    priority: 200
    direction: 'Inbound'
    access: 'Allow'
    protocol: '*'
    source: p.lan
    destination: p.lan
    ports: ['*']
  }
  {
    name: 'Allow-AzureLoadBalancer-In'
    priority: 210
    direction: 'Inbound'
    access: 'Allow'
    protocol: '*'
    source: 'AzureLoadBalancer'
    destination: '*'
    ports: ['*']
  }
  {
    name: 'Allow-LAN-to-DMZ-Web'
    priority: 200
    direction: 'Outbound'
    access: 'Allow'
    protocol: 'Tcp'
    source: p.lan
    destination: p.dmz
    ports: ['80', '443']
  }
  {
    name: 'Allow-LAN-Intra-Out'
    priority: 210
    direction: 'Outbound'
    access: 'Allow'
    protocol: '*'
    source: p.lan
    destination: p.lan
    ports: ['*']
  }
  allowAzureMonitorOut
  allowWebOut
]

var dmzRules nsgRule[] = [
  {
    name: 'Allow-Web-from-LAN'
    priority: 200
    direction: 'Inbound'
    access: 'Allow'
    protocol: 'Tcp'
    source: p.lan
    destination: p.dmz
    ports: ['80', '443']
  }
  {
    name: 'Allow-Web-from-Attacker'
    priority: 210
    direction: 'Inbound'
    access: 'Allow'
    protocol: 'Tcp'
    source: p.attacker
    destination: p.dmz
    ports: ['80', '443']
    description: 'Exposed attack surface for T1190 (exploit public-facing app).'
  }
  {
    name: 'Allow-AzureLoadBalancer-In'
    priority: 220
    direction: 'Inbound'
    access: 'Allow'
    protocol: '*'
    source: 'AzureLoadBalancer'
    destination: '*'
    ports: ['*']
  }
  {
    name: 'Deny-DMZ-to-LAN-Out'
    priority: 100
    direction: 'Outbound'
    access: 'Deny'
    protocol: '*'
    source: p.dmz
    destination: p.lan
    ports: ['*']
    description: 'Blocked at the source as well as at the LAN NSG.'
  }
  allowAzureMonitorOut
  allowWebOut
]

var targetsRules nsgRule[] = [
  {
    name: 'Deny-Internet-In'
    priority: 100
    direction: 'Inbound'
    access: 'Deny'
    protocol: '*'
    source: 'Internet'
    destination: '*'
    ports: ['*']
    description: 'Metasploitable is never reachable from the internet.'
  }
  {
    name: 'Allow-All-from-Attacker'
    priority: 200
    direction: 'Inbound'
    access: 'Allow'
    protocol: '*'
    source: p.attacker
    destination: p.targets
    ports: ['*']
  }
  {
    name: 'Deny-Internet-Out'
    priority: 100
    direction: 'Outbound'
    access: 'Deny'
    protocol: '*'
    source: '*'
    destination: 'Internet'
    ports: ['*']
    description: 'Vulnerable targets never talk to the internet.'
  }
  {
    name: 'Allow-Callback-to-Attacker'
    priority: 200
    direction: 'Outbound'
    access: 'Allow'
    protocol: '*'
    source: p.targets
    destination: p.attacker
    ports: ['*']
    description: 'Reverse shells back to Kali, so the T1571 non-standard-port detection has traffic to fire on.'
  }
]

var attackerRules nsgRule[] = concat(
  hasAdmin
    ? [
        {
          name: 'Allow-Admin-SSH-RDP'
          priority: 200
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          source: adminSourceAddress
          destination: p.attacker
          ports: ['22', '3389']
          description: 'Your own IP only.'
        }
      ]
    : [],
  [
    {
      name: 'Allow-Callbacks-from-Targets'
      priority: 210
      direction: 'Inbound'
      access: 'Allow'
      protocol: '*'
      source: p.targets
      destination: p.attacker
      ports: ['*']
    }
    {
      name: 'Allow-Attacker-to-VNet'
      priority: 200
      direction: 'Outbound'
      access: 'Allow'
      protocol: '*'
      source: p.attacker
      destination: 'VirtualNetwork'
      ports: ['*']
      description: 'Kali may send anything inside the lab. The destination subnet NSGs decide what lands.'
    }
    allowAzureMonitorOut
    allowWebOut
  ]
)

var honeypotRules nsgRule[] = concat(
  [
    {
      name: 'Allow-Honeypot-SSH-Telnet-Internet'
      priority: 200
      direction: 'Inbound'
      access: 'Allow'
      protocol: 'Tcp'
      source: 'Internet'
      destination: p.honeypot
      ports: ['22', '23']
      description: 'Cowrie listens here (iptables redirects 22/23 to 2222/2223 on the VM).'
    }
    {
      name: 'Allow-Honeypot-SSH-Telnet-Attacker'
      priority: 210
      direction: 'Inbound'
      access: 'Allow'
      protocol: 'Tcp'
      source: p.attacker
      destination: p.honeypot
      ports: ['22', '23']
      description: 'Hydra from Kali.'
    }
    {
      name: 'Deny-Honeypot-to-VNet'
      priority: 100
      direction: 'Outbound'
      access: 'Deny'
      protocol: '*'
      source: p.honeypot
      destination: 'VirtualNetwork'
      ports: ['*']
      description: 'Containment: the honeypot can never start a connection into the lab.'
    }
    allowAzureMonitorOut
    allowWebOut
  ],
  hasAdmin
    ? [
        {
          name: 'Allow-Admin-SSH'
          priority: 220
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          source: adminSourceAddress
          destination: p.honeypot
          ports: ['22222']
          description: 'Real sshd is moved to 22222 so Cowrie can own 22.'
        }
      ]
    : []
)

var fwUntrustRules nsgRule[] = concat(
  hasAdmin
    ? [
        {
          name: 'Allow-Admin-Firewall-GUI'
          priority: 200
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          source: adminSourceAddress
          destination: p.fwUntrust
          ports: ['443']
        }
      ]
    : [],
  [
    {
      name: 'Allow-Firewall-Egress'
      priority: 200
      direction: 'Outbound'
      access: 'Allow'
      protocol: '*'
      source: p.fwUntrust
      destination: 'Internet'
      ports: ['*']
      description: 'pfSense WAN is the lab egress once UDRs are on. pfSense does the filtering.'
    }
  ]
)

var fwTrustRules nsgRule[] = [
  {
    name: 'Allow-VNet-Transit-In'
    priority: 200
    direction: 'Inbound'
    access: 'Allow'
    protocol: '*'
    source: 'VirtualNetwork'
    destination: '*'
    ports: ['*']
    description: 'Routed traffic hits the firewall NIC with its original destination, so allow any destination.'
  }
  {
    name: 'Allow-VNet-Transit-Out'
    priority: 200
    direction: 'Outbound'
    access: 'Allow'
    protocol: '*'
    source: '*'
    destination: 'VirtualNetwork'
    ports: ['*']
  }
]

// ---------- Subnet table ----------

var subnetDefs = [
  { key: 'lan', name: 'snet-lan', rules: lanRules, workload: true, internetRoute: true, defaultOutbound: allowDefaultOutbound }
  { key: 'dmz', name: 'snet-dmz', rules: dmzRules, workload: true, internetRoute: true, defaultOutbound: allowDefaultOutbound }
  { key: 'targets', name: 'snet-targets', rules: targetsRules, workload: true, internetRoute: true, defaultOutbound: false }
  { key: 'attacker', name: 'snet-attacker', rules: attackerRules, workload: true, internetRoute: true, defaultOutbound: allowDefaultOutbound }
  // The honeypot keeps its own public IP, so it gets no 0.0.0.0/0 route (that would make internet replies asymmetric).
  { key: 'honeypot', name: 'snet-honeypot', rules: honeypotRules, workload: true, internetRoute: false, defaultOutbound: allowDefaultOutbound }
  { key: 'fwUntrust', name: 'snet-fw-untrust', rules: fwUntrustRules, workload: false, internetRoute: false, defaultOutbound: true }
  { key: 'fwTrust', name: 'snet-fw-trust', rules: fwTrustRules, workload: false, internetRoute: false, defaultOutbound: false }
]

var workloadDefs = filter(subnetDefs, s => s.workload)

// ---------- Resources ----------

module nsgs 'modules/nsg.bicep' = [
  for s in subnetDefs: {
    name: 'nsg-${s.name}'
    params: {
      name: 'nsg-${prefix}-${s.name}'
      location: location
      tags: tags
      rules: s.rules
    }
  }
]

// Each workload subnet sends traffic for every other workload subnet (and, except the honeypot, the internet)
// to the pfSense trust NIC. Only created once firewallTrustIp is set.
resource routeTables 'Microsoft.Network/routeTables@2024-05-01' = [
  for s in workloadDefs: if (useFirewall) {
    name: 'rt-${prefix}-${s.name}'
    location: location
    tags: tags
    properties: {
      disableBgpRoutePropagation: true
      routes: concat(
        map(filter(workloadDefs, o => o.key != s.key), o => {
          name: 'to-${o.name}'
          properties: {
            addressPrefix: p[o.key]
            nextHopType: 'VirtualAppliance'
            nextHopIpAddress: firewallTrustIp
          }
        }),
        s.internetRoute
          ? [
              {
                name: 'default-via-firewall'
                properties: {
                  addressPrefix: '0.0.0.0/0'
                  nextHopType: 'VirtualAppliance'
                  nextHopIpAddress: firewallTrustIp
                }
              }
            ]
          : []
      )
    }
  }
]

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: 'vnet-${prefix}'
  dependsOn: [routeTables]
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [vnetAddressSpace]
    }
    subnets: [
      for (s, i) in subnetDefs: {
        name: s.name
        properties: {
          addressPrefix: p[s.key]
          networkSecurityGroup: {
            id: nsgs[i].outputs.id
          }
          routeTable: useFirewall && s.workload
            ? {
                id: resourceId('Microsoft.Network/routeTables', 'rt-${prefix}-${s.name}')
              }
            : null
          defaultOutboundAccess: s.defaultOutbound
          privateEndpointNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

// ---------- Outputs ----------

output vnetId string = vnet.id
output vnetName string = vnet.name
output subnetIds object = toObject(subnetDefs, s => s.key, s => resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, s.name))
output nsgIds object = toObject(subnetDefs, s => s.key, s => resourceId('Microsoft.Network/networkSecurityGroups', 'nsg-${prefix}-${s.name}'))
