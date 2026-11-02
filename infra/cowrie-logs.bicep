param location string = resourceGroup().location
param prefix string = 'seclab'

resource law 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: 'law-${prefix}'
}

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' existing = {
  name: 'vm-${prefix}-honeypot'
}

resource table 'Microsoft.OperationalInsights/workspaces/tables@2022-10-01' = {
  parent: law
  name: 'CowrieRaw_CL'
  properties: {
    schema: {
      name: 'CowrieRaw_CL'
      columns: [
        { name: 'TimeGenerated', type: 'datetime' }
        { name: 'RawData', type: 'string' }
      ]
    }
  }
}

resource dcr 'Microsoft.Insights/dataCollectionRules@2023-03-11' = {
  name: 'dcr-${prefix}-cowrie'
  location: location
  kind: 'Linux'
  dependsOn: [table]
  properties: {
    streamDeclarations: {
      'Custom-CowrieRaw_CL': {
        columns: [
          { name: 'TimeGenerated', type: 'datetime' }
          { name: 'RawData', type: 'string' }
        ]
      }
    }
    dataSources: {
      logFiles: [
        {
          name: 'cowrieJson'
          streams: ['Custom-CowrieRaw_CL']
          filePatterns: ['/home/cowrie/cowrie/var/log/cowrie/cowrie.json']
          format: 'text'
        }
      ]
    }
    destinations: {
      logAnalytics: [
        { name: 'law', workspaceResourceId: law.id }
      ]
    }
    dataFlows: [
      {
        streams: ['Custom-CowrieRaw_CL']
        destinations: ['law']
        transformKql: 'source'
        outputStream: 'Custom-CowrieRaw_CL'
      }
    ]
  }
}

resource ama 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  parent: vm
  name: 'AzureMonitorLinuxAgent'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorLinuxAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
  }
}

resource assoc 'Microsoft.Insights/dataCollectionRuleAssociations@2022-06-01' = {
  scope: vm
  name: 'dcra-${prefix}-cowrie'
  dependsOn: [ama]
  properties: {
    dataCollectionRuleId: dcr.id
  }
}
