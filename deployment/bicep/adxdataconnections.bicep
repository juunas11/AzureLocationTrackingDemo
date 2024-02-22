param location string = resourceGroup().location

param adxClusterName string
param prodAdxDbName string
param devAdxDbName string
param eventHubNamespaceName string
param prodLocationDataEventHubName string
param devLocationDataEventHubName string
param eventHubConsumerGroupAdx string

resource adxCluster 'Microsoft.Kusto/clusters@2022-12-29' existing = {
  name: adxClusterName
}

resource prodAdxDb 'Microsoft.Kusto/clusters/databases@2022-12-29' existing = {
  parent: adxCluster
  name: prodAdxDbName
}

resource devAdxDb 'Microsoft.Kusto/clusters/databases@2022-12-29' existing = {
  parent: adxCluster
  name: devAdxDbName
}

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2021-11-01' existing = {
  name: eventHubNamespaceName
}

resource prodLocationDataEventHub 'Microsoft.EventHub/namespaces/eventhubs@2021-11-01' existing = {
  parent: eventHubNamespace
  name: prodLocationDataEventHubName
}

resource devLocationDataEventHub 'Microsoft.EventHub/namespaces/eventhubs@2021-11-01' existing = {
  parent: eventHubNamespace
  name: devLocationDataEventHubName
}

resource prodEventHubConnection 'Microsoft.Kusto/clusters/databases/dataConnections@2022-12-29' = {
  parent: prodAdxDb
  name: 'prod-locationdata'
  location: location
  kind: 'EventHub'
  properties: {
    eventHubResourceId: prodLocationDataEventHub.id
    consumerGroup: eventHubConsumerGroupAdx
    compression: 'None'
    tableName: 'locations'
    dataFormat: 'MULTIJSON'
    mappingRuleName: 'locations_mapping'
    managedIdentityResourceId: adxCluster.id
  }
}
resource devEventHubConnection 'Microsoft.Kusto/clusters/databases/dataConnections@2022-12-29' = {
  parent: devAdxDb
  name: 'dev-locationdata'
  location: location
  kind: 'EventHub'
  properties: {
    eventHubResourceId: devLocationDataEventHub.id
    consumerGroup: eventHubConsumerGroupAdx
    compression: 'None'
    tableName: 'locations'
    dataFormat: 'MULTIJSON'
    mappingRuleName: 'locations_mapping'
    managedIdentityResourceId: adxCluster.id
  }
  dependsOn: [
    prodEventHubConnection
  ]
}
