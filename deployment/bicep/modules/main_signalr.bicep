param location string
param naming object
@allowed([
  'Free_F1'
  'Standard_S1'
  'Premium_P1'
])
param signalRSku string
param signalRCapacity int
param prodHubName string
param devHubName string
@secure()
param prodUpstreamUrl string
@secure()
param devUpstreamUrl string

var defaultUpstreamTemplates = []
var upstreamTemplatesWithProd = concat(defaultUpstreamTemplates, !empty(prodUpstreamUrl) ? [
    {
      urlTemplate: prodUpstreamUrl
      hubPattern: toLower(prodHubName)
      eventPattern: '*'
      categoryPattern: '*'
      auth: {
        type: 'None'
      }
    }
  ] : [])
var upstreamTemplatesWithProdAndDev = concat(upstreamTemplatesWithProd, !empty(devUpstreamUrl) ? [
    {
      urlTemplate: devUpstreamUrl
      hubPattern: toLower(devHubName)
      eventPattern: '*'
      categoryPattern: '*'
      auth: {
        type: 'None'
      }
    }
  ] : [])

resource signalR 'Microsoft.SignalRService/signalR@2023-02-01' = {
  name: naming.signalR
  location: location
  kind: 'SignalR'
  sku: {
    name: signalRSku
    capacity: signalRCapacity
  }
  properties: {
    cors: {
      allowedOrigins: [
        'http://localhost:7090'
        'http://localhost:5173'
        'https://${naming.functionsApp}.azurewebsites.net'
      ]
    }
    features: [
      {
        flag: 'ServiceMode'
        value: 'Serverless'
        properties: {}
      }
    ]
    serverless: {
      connectionTimeoutInSeconds: 30
    }
    publicNetworkAccess: 'Enabled'
    upstream: {
      templates: upstreamTemplatesWithProdAndDev
    }
  }
}

output name string = signalR.name
