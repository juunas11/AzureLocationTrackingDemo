param location string
param naming object

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2021-11-01' = {
  name: naming.eventHubNamespace
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
    capacity: 1
  }
  properties: {}
}

resource prodLocationDataEventHub 'Microsoft.EventHub/namespaces/eventhubs@2021-11-01' = {
  parent: eventHubNamespace
  name: naming.locationDataEventHubProd
  properties: {
    partitionCount: 16
    messageRetentionInDays: 1
  }

  resource latestLocationUpdateConsumer 'consumergroups' = {
    name: naming.eventHubConsumerGroupLatestLocationUpdate
  }

  resource geofenceCheckConsumer 'consumergroups' = {
    name: naming.eventHubConsumerGroupGeofenceCheck
  }

  resource adxConsumer 'consumergroups' = {
    name: naming.eventHubConsumerGroupAdx
  }
}

resource devLocationDataEventHub 'Microsoft.EventHub/namespaces/eventhubs@2021-11-01' = {
  parent: eventHubNamespace
  name: naming.locationDataEventHubDev
  properties: {
    partitionCount: 4
    messageRetentionInDays: 1
  }

  resource latestLocationUpdateConsumer 'consumergroups' = {
    name: naming.eventHubConsumerGroupLatestLocationUpdate
  }

  resource geofenceCheckConsumer 'consumergroups' = {
    name: naming.eventHubConsumerGroupGeofenceCheck
  }

  resource adxConsumer 'consumergroups' = {
    name: naming.eventHubConsumerGroupAdx
  }

  resource devKey 'authorizationRules@2021-11-01' = {
    name: naming.eventHubDevKeyName
    properties: {
      rights: [
        'Manage'
        'Listen'
        'Send'
      ]
    }
  }
}

output namespaceName string = eventHubNamespace.name
output prodEventHubName string = prodLocationDataEventHub.name
output devEventHubName string = devLocationDataEventHub.name
