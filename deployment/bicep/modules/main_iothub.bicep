param location string
param naming object
param iotHubEventHubPartitionCount int
param iotHubSku string
param iotHubCapacity int
param iotHubTwinContributorUserId string
param eventHubNamespaceName string
param prodLocationDataEventHubName string
param devLocationDataEventHubName string

var eventHubSenderRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '2b629674-e913-4c01-ae53-ef4638d8f975'
)
var iotHubTwinContributorRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '494bdba2-168f-4f31-a0a1-191d2f7c028c'
)

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

resource iotHubIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: naming.iotHubIdentity
  location: location
}

resource iotHubProdEventSendRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(prodLocationDataEventHub.id, eventHubSenderRoleDefinitionId, iotHubIdentity.id)
  scope: prodLocationDataEventHub
  properties: {
    roleDefinitionId: eventHubSenderRoleDefinitionId
    principalId: iotHubIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource iotHubDevEventSendRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(devLocationDataEventHub.id, eventHubSenderRoleDefinitionId, iotHubIdentity.id)
  scope: devLocationDataEventHub
  properties: {
    roleDefinitionId: eventHubSenderRoleDefinitionId
    principalId: iotHubIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource iotHub 'Microsoft.Devices/IotHubs@2021-07-02' = {
  name: naming.iotHub
  location: location
  sku: {
    name: iotHubSku
    capacity: iotHubCapacity
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${iotHubIdentity.id}': {}
    }
  }
  properties: {
    eventHubEndpoints: {
      events: {
        partitionCount: iotHubEventHubPartitionCount
        retentionTimeInDays: 1
      }
    }
    routing: {
      endpoints: {
        eventHubs: [
          {
            name: naming.locationDataEventHubProd
            authenticationType: 'identityBased'
            identity: {
              userAssignedIdentity: iotHubIdentity.id
            }
            subscriptionId: subscription().subscriptionId
            resourceGroup: resourceGroup().name
            endpointUri: 'sb://${eventHubNamespace.name}.servicebus.windows.net'
            entityPath: naming.locationDataEventHubProd
          }
          {
            name: naming.locationDataEventHubDev
            authenticationType: 'identityBased'
            identity: {
              userAssignedIdentity: iotHubIdentity.id
            }
            subscriptionId: subscription().subscriptionId
            resourceGroup: resourceGroup().name
            endpointUri: 'sb://${eventHubNamespace.name}.servicebus.windows.net'
            entityPath: naming.locationDataEventHubDev
          }
        ]
      }
      routes: [
        {
          name: 'prodLocationData'
          source: 'DeviceMessages'
          condition: '$twin.tags.environment = "prod"'
          isEnabled: true
          endpointNames: [
            naming.locationDataEventHubProd
          ]
        }
        {
          name: 'devLocationData'
          source: 'DeviceMessages'
          condition: '$twin.tags.environment = "dev"'
          isEnabled: true
          endpointNames: [
            naming.locationDataEventHubDev
          ]
        }
      ]
      fallbackRoute: {
        name: '$fallback'
        source: 'DeviceMessages'
        endpointNames: [
          'events'
        ]
        isEnabled: true
      }
    }
  }
  dependsOn: [
    iotHubProdEventSendRoleAssignment
    iotHubDevEventSendRoleAssignment
  ]
}

resource developerIotHubTwinContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: iotHub
  name: guid(iotHub.id, iotHubTwinContributorRoleDefinitionId, iotHubTwinContributorUserId)
  properties: {
    roleDefinitionId: iotHubTwinContributorRoleDefinitionId
    principalId: iotHubTwinContributorUserId
    principalType: 'User'
  }
}

output name string = iotHub.name
output hostName string = iotHub.properties.hostName
