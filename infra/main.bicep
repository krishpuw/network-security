param location string = resourceGroup().location
param prefix string = 'seclab'

var lanPrefix = '10.0.0.0/24'
var dmzPrefix = '10.0.1.0/26'

var targetsPrefix = '10.0.1.64/27'
var attackerPrefix = '10.0.1.96/28'
var honeypotPrefix = '10.0.1.112/28'

@description('Your public IP as x.x.x.x/32. Leave empty to skip the admin rule.')
param adminIp string = ''




module nsgLan 'modules/nsg.bicep' = {
  name: 'nsg-lan'
  params: {
    name: 'nsg-${prefix}-snet-lan'
    location: location
    rules: [
      { name: 'Deny-DMZ-to-LAN',     priority: 100, direction: 'Inbound',  access: 'Deny',  protocol: '*', source: dmzPrefix, destination: lanPrefix, port: '*' }
      { name: 'Deny-Attacker-to-LAN',  priority: 110, direction: 'Inbound', access: 'Deny', protocol: '*', source: attackerPrefix, destination: lanPrefix, port: '*' }
    { name: 'Deny-Honeypot-to-LAN',  priority: 120, direction: 'Inbound', access: 'Deny', protocol: '*', source: honeypotPrefix, destination: lanPrefix, port: '*' }
      { name: 'Allow-LAN-Intra-In',  priority: 200, direction: 'Inbound',  access: 'Allow', protocol: '*', source: lanPrefix, destination: lanPrefix, port: '*' }
      { name: 'Allow-LAN-Intra-Out', priority: 200, direction: 'Outbound', access: 'Allow', protocol: '*', source: lanPrefix, destination: lanPrefix, port: '*' }
    ]
  }
}

module nsgDmz 'modules/nsg.bicep' = {
  name: 'nsg-dmz'
  params: {
    name: 'nsg-${prefix}-snet-dmz'
    location: location
    rules: [
    { name: 'Allow-Web-from-Attacker', priority: 210, direction: 'Inbound', access: 'Allow', protocol: 'Tcp', source: attackerPrefix, destination: dmzPrefix, port: '443' }
      { name: 'Deny-DMZ-to-LAN-Out', priority: 100, direction: 'Outbound', access: 'Deny',  protocol: '*',   source: dmzPrefix, destination: lanPrefix, port: '*' }
      { name: 'Allow-Web-from-LAN',  priority: 200, direction: 'Inbound',  access: 'Allow', protocol: 'Tcp', source: lanPrefix, destination: dmzPrefix, port: '443' }
    ]
  }
}

module nsgTargets 'modules/nsg.bicep' = {
  name: 'nsg-targets'
  params: {
    name: 'nsg-${prefix}-snet-targets'
    location: location
    rules: [
      { name: 'Deny-Internet-In',           priority: 100, direction: 'Inbound',  access: 'Deny',  protocol: '*', source: 'Internet',      destination: targetsPrefix,  port: '*' }
      { name: 'Allow-All-from-Attacker',    priority: 200, direction: 'Inbound',  access: 'Allow', protocol: '*', source: attackerPrefix,  destination: targetsPrefix,  port: '*' }
      { name: 'Allow-Callback-to-Attacker', priority: 200, direction: 'Outbound', access: 'Allow', protocol: '*', source: targetsPrefix,   destination: attackerPrefix, port: '*' }
    ]
  }
}

module nsgAttacker 'modules/nsg.bicep' = {
  name: 'nsg-attacker'
  params: {
    name: 'nsg-${prefix}-snet-attacker'
    location: location
    rules: concat(
      empty(adminIp) ? [] : [
        { name: 'Allow-Admin-SSH', priority: 200, direction: 'Inbound', access: 'Allow', protocol: 'Tcp', source: adminIp, destination: attackerPrefix, port: '22' }
      ],
      [
        { name: 'Allow-Callbacks-from-Targets', priority: 210, direction: 'Inbound',  access: 'Allow', protocol: '*', source: targetsPrefix,  destination: attackerPrefix,  port: '*' }
        { name: 'Allow-Attacker-to-VNet',       priority: 200, direction: 'Outbound', access: 'Allow', protocol: '*', source: attackerPrefix, destination: 'VirtualNetwork', port: '*' }
      ]
    )
  }
}

module nsgHoneypot 'modules/nsg.bicep' = {
  name: 'nsg-honeypot'
  params: {
    name: 'nsg-${prefix}-snet-honeypot'
    location: location
    rules: [
      { name: 'Deny-Honeypot-to-VNet',  priority: 100, direction: 'Outbound', access: 'Deny',  protocol: '*',   source: honeypotPrefix, destination: 'VirtualNetwork', port: '*' }
      { name: 'Allow-SSH-from-Internet', priority: 200, direction: 'Inbound',  access: 'Allow', protocol: 'Tcp', source: 'Internet',     destination: honeypotPrefix,   port: '22' }
      { name: 'Allow-SSH-from-Attacker', priority: 210, direction: 'Inbound',  access: 'Allow', protocol: 'Tcp', source: attackerPrefix, destination: honeypotPrefix,   port: '22' }
    ]
  }
}


resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: 'vnet-${prefix}'
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.0.0.0/16'] }
    subnets: [
      { name: 'snet-lan', properties: { addressPrefix: lanPrefix, networkSecurityGroup: { id: nsgLan.outputs.id } } }
      { name: 'snet-dmz', properties: { addressPrefix: dmzPrefix, networkSecurityGroup: { id: nsgDmz.outputs.id } } }
    //   { name: 'snet-targets',  properties: { addressPrefix: '10.0.1.64/27' } }
    //   { name: 'snet-attacker', properties: { addressPrefix: '10.0.1.96/28' } }
    //   { name: 'snet-honeypot', properties: { addressPrefix: '10.0.1.112/28' } }
      { name: 'snet-targets',  properties: { addressPrefix: targetsPrefix,  networkSecurityGroup: { id: nsgTargets.outputs.id } } }
      { name: 'snet-attacker', properties: { addressPrefix: attackerPrefix, networkSecurityGroup: { id: nsgAttacker.outputs.id } } }
      { name: 'snet-honeypot', properties: { addressPrefix: honeypotPrefix, networkSecurityGroup: { id: nsgHoneypot.outputs.id } } }
    ]
  }
}

output vnetId string = vnet.id
