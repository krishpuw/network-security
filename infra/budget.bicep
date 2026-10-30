targetScope = 'subscription'

param contactEmail string
param amount int = 50

@description('Budgets must start on the 1st of a month.')
param startDate string = utcNow('yyyy-MM-01')

resource budget 'Microsoft.Consumption/budgets@2023-11-01' = {
  name: 'budget-seclab'
  properties: {
    category: 'Cost'
    amount: amount
    timeGrain: 'Monthly'
    timePeriod: { startDate: startDate }
    notifications: {
      actual80: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 80
        thresholdType: 'Actual'
        contactEmails: [contactEmail]
      }
      forecast100: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 100
        thresholdType: 'Forecasted'
        contactEmails: [contactEmail]
      }
    }
  }
}
