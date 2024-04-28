param location string
param naming object
param iotHubEventHubPartitionCount int
param eventHubSku string
param eventHubCapacity int

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2021-11-01' = {
  name: naming.eventHubNamespace
  location: location
  sku: {
    name: eventHubSku
    tier: eventHubSku
    capacity: eventHubCapacity
  }
  properties: {}
}

resource prodLocationDataEventHub 'Microsoft.EventHub/namespaces/eventhubs@2021-11-01' = {
  parent: eventHubNamespace
  name: naming.locationDataEventHubProd
  properties: {
    partitionCount: iotHubEventHubPartitionCount
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

// Used from local development environment
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
