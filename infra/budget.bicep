// Monthly cost guardrail for the lab subscription. Deploy once, on day one:
//   az deployment sub create -l <region> -f infra/budget.bicep -p contactEmail=<you@example.com>

targetScope = 'subscription'

param budgetName string = 'budget-seclab'

@description('Monthly limit in the subscription billing currency.')
param amount int = 50

param contactEmail string

@description('First day of the current month. Budgets must start on the 1st.')
param startDate string = utcNow('yyyy-MM-01')

resource budget 'Microsoft.Consumption/budgets@2023-11-01' = {
  name: budgetName
  properties: {
    category: 'Cost'
    amount: amount
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: startDate
    }
    notifications: {
      actual50: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 50
        thresholdType: 'Actual'
        contactEmails: [contactEmail]
      }
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
