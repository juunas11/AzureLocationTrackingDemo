param location string
param naming object
param acrPushUserId string
param eventHubNamespaceName string
param prodLocationDataEventHubName string
param logAnalyticsWorkspaceName string

var acrPullRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
var acrPushRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8311e382-0749-4cb8-b61a-304f252e45ec')
var eventHubSenderRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '2b629674-e913-4c01-ae53-ef4638d8f975')

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2021-11-01' existing = {
  name: eventHubNamespaceName
}

resource prodLocationDataEventHub 'Microsoft.EventHub/namespaces/eventhubs@2021-11-01' existing = {
  parent: eventHubNamespace
  name: prodLocationDataEventHubName
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2022-03-01' = {
  name: naming.containerAppEnvironment
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: listKeys(logAnalyticsWorkspace.id, '2020-08-01').primarySharedKey
      }
    }
  }
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-09-01' = {
  name: naming.containerRegistry
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
    zoneRedundancy: 'Disabled'
  }
}

resource userAcrPushRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: containerRegistry
  name: guid(containerRegistry.id, acrPushRoleDefinitionId, acrPushUserId)
  properties: {
    roleDefinitionId: acrPushRoleDefinitionId
    principalId: acrPushUserId
    principalType: 'User'
  }
}

resource containerAppIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: naming.containerAppIdentity
  location: location
}

resource containerAppAcrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: containerRegistry
  name: guid(containerRegistry.id, acrPullRoleDefinitionId, containerAppIdentity.id)
  properties: {
    roleDefinitionId: acrPullRoleDefinitionId
    principalId: containerAppIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource containerAppEventHubSenderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: prodLocationDataEventHub
  name: guid(prodLocationDataEventHub.id, eventHubSenderRoleDefinitionId, containerAppIdentity.id)
  properties: {
    roleDefinitionId: eventHubSenderRoleDefinitionId
    principalId: containerAppIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

output containerRegistryName string = containerRegistry.name
output containerAppEnvironmentName string = containerAppEnvironment.name
output containerAppIdentityName string = containerAppIdentity.name
