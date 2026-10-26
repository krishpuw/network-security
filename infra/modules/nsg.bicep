// One NSG built from a compact rule list. Every NSG gets explicit
// deny-all rules at priority 4096 so Azure's built-in AllowVnetInBound /
// AllowInternetOutBound defaults (priority 65000+) never apply.

@export()
type nsgRule = {
  name: string
  priority: int
  direction: 'Inbound' | 'Outbound'
  access: 'Allow' | 'Deny'
  protocol: 'Tcp' | 'Udp' | 'Icmp' | '*'
  @description('Address prefix or service tag, e.g. 10.0.1.0/26, Internet, AzureMonitor.')
  source: string
  destination: string
  @description('Destination ports. Use [\'*\'] for any.')
  ports: string[]
  description: string?
}

param name string
param location string
param tags object = {}
param rules nsgRule[]

var denyAll = [
  {
    name: 'Deny-All-Inbound'
    priority: 4096
    direction: 'Inbound'
    access: 'Deny'
    protocol: '*'
    source: '*'
    destination: '*'
    ports: ['*']
    description: 'Default deny. Overrides the built-in AllowVnetInBound rule.'
  }
  {
    name: 'Deny-All-Outbound'
    priority: 4096
    direction: 'Outbound'
    access: 'Deny'
    protocol: '*'
    source: '*'
    destination: '*'
    ports: ['*']
    description: 'Default deny. Overrides the built-in AllowVnetOutBound and AllowInternetOutBound rules.'
  }
]

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    securityRules: [
      for r in concat(rules, denyAll): {
        name: r.name
        properties: {
          priority: r.priority
          direction: r.direction
          access: r.access
          protocol: r.protocol
          sourceAddressPrefix: r.source
          sourcePortRange: '*'
          destinationAddressPrefix: r.destination
          destinationPortRange: length(r.ports) == 1 ? r.ports[0] : null
          destinationPortRanges: length(r.ports) > 1 ? r.ports : []
          description: r.?description ?? ''
        }
      }
    ]
  }
}

output id string = nsg.id
output name string = nsg.name
