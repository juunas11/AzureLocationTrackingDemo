param location string
param naming object
param adxAdminUserId string
param eventHubNamespaceName string
param prodLocationDataEventHubName string
param devLocationDataEventHubName string

var eventHubReceiverRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a638d3c7-ab3a-418d-83e6-5f17a39d4fde')

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

resource cluster 'Microsoft.Kusto/clusters@2022-12-29' = {
  name: naming.adxCluster
  location: location
  sku: {
    name: 'Dev(No SLA)_Standard_E2a_v4'
    tier: 'Basic'
    capacity: 1
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    trustedExternalTenants: []
    enableDiskEncryption: false
    enableStreamingIngest: false
    enablePurge: false
    enableDoubleEncryption: false
    engineType: 'V3'
    acceptedAudiences: []
    restrictOutboundNetworkAccess: 'Disabled'
    allowedFqdnList: []
    publicNetworkAccess: 'Enabled'
    allowedIpRangeList: []
    enableAutoStop: true
    publicIPType: 'IPv4'
  }
}

resource prodDb 'Microsoft.Kusto/clusters/databases@2022-12-29' = {
  parent: cluster
  name: naming.adxDbProd
  location: location
  kind: 'ReadWrite'
  properties: {
    hotCachePeriod: 'P7D'
  }
}

resource devDb 'Microsoft.Kusto/clusters/databases@2022-12-29' = {
  parent: cluster
  name: naming.adxDbDev
  location: location
  kind: 'ReadWrite'
  properties: {
    hotCachePeriod: 'P7D'
  }
}

resource prodEventReadRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(cluster.id, prodLocationDataEventHub.id, eventHubReceiverRoleDefinitionId)
  scope: prodLocationDataEventHub
  properties: {
    roleDefinitionId: eventHubReceiverRoleDefinitionId
    principalId: cluster.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource devEventReadRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(cluster.id, devLocationDataEventHub.id, eventHubReceiverRoleDefinitionId)
  scope: devLocationDataEventHub
  properties: {
    roleDefinitionId: eventHubReceiverRoleDefinitionId
    principalId: cluster.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource developerAdminAssignment 'Microsoft.Kusto/clusters/principalAssignments@2022-12-29' = {
  parent: cluster
  name: guid(cluster.id, adxAdminUserId, 'Admin')
  properties: {
    principalId: adxAdminUserId
    role: 'AllDatabasesAdmin'
    principalType: 'User'
    tenantId: subscription().tenantId
  }
}

output clusterName string = cluster.name
output clusterUri string = cluster.properties.uri
