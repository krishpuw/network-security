param name string
param location string
param rules array

// Added to every NSG, always last (priority 4096).
var denyAll = [
  {
    name: 'Deny-All-Inbound'
    priority: 4096
    direction: 'Inbound'
    access: 'Deny'
    protocol: '*'
    source: '*'
    destination: '*'
    port: '*'
  }
  {
    name: 'Deny-All-Outbound'
    priority: 4096
    direction: 'Outbound'
    access: 'Deny'
    protocol: '*'
    source: '*'
    destination: '*'
    port: '*'
  }
]

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: name
  location: location
  properties: {
    securityRules: [for r in concat(rules, denyAll): {
      name: r.name
      properties: {
        priority: r.priority
        direction: r.direction
        access: r.access
        protocol: r.protocol
        sourceAddressPrefix: r.source
        sourcePortRange: '*'
        destinationAddressPrefix: r.destination
        destinationPortRange: r.port
      }
    }]
  }
}

output id string = nsg.id