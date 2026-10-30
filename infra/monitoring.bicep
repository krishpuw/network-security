param location string = resourceGroup().location
param prefix string = 'seclab'

@description('Daily ingestion cap in GB, to protect your credit.')
param dailyCapGb int = 1

resource law 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'law-${prefix}'
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
    workspaceCapping: { dailyQuotaGb: dailyCapGb }
  }
}

resource sentinel 'Microsoft.SecurityInsights/onboardingStates@2024-03-01' = {
  scope: law
  name: 'default'
  properties: {}
}

output workspaceId string = law.id
