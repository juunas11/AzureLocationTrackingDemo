param location string
param naming object
param functionsAdAppTenantId string
param functionsAdAppClientId string
param functionsAdAppScope string
param eventHubNamespaceName string
param prodLocationDataEventHubName string
param iotHubName string
param mapsAccountName string
param sqlServerName string
param sqlDbName string
param appInsightsName string
param signalRName string
param adxClusterName string
param prodAdxDbName string
param prodSignalRHubName string

var mapsSearchRenderReaderRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '6be48352-4f82-47c9-ad5e-0acacefdb005')
var iotHubTwinContributorRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '494bdba2-168f-4f31-a0a1-191d2f7c028c')
var eventHubReceiverRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a638d3c7-ab3a-418d-83e6-5f17a39d4fde')

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2021-11-01' existing = {
  name: eventHubNamespaceName
}

resource prodLocationDataEventHub 'Microsoft.EventHub/namespaces/eventhubs@2021-11-01' existing = {
  parent: eventHubNamespace
  name: prodLocationDataEventHubName
}

resource iotHub 'Microsoft.Devices/IotHubs@2021-07-02' existing = {
  name: iotHubName
}

resource mapsAccount 'Microsoft.Maps/accounts@2021-12-01-preview' existing = {
  name: mapsAccountName
}

resource sqlServer 'Microsoft.Sql/servers@2022-05-01-preview' existing = {
  name: sqlServerName
}

resource sqlDb 'Microsoft.Sql/servers/databases@2022-05-01-preview' existing = {
  parent: sqlServer
  name: sqlDbName
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

resource signalR 'Microsoft.SignalRService/signalR@2022-08-01-preview' existing = {
  name: signalRName
}

resource adxCluster 'Microsoft.Kusto/clusters@2022-12-29' existing = {
  name: adxClusterName
}

resource adxDb 'Microsoft.Kusto/clusters/databases@2022-12-29' existing = {
  parent: adxCluster
  name: prodAdxDbName
}

resource functionsStorage 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: naming.functionsStorage
  kind: 'StorageV2'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    publicNetworkAccess: 'Enabled'
    supportsHttpsTrafficOnly: true
  }
}

resource functionsPlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: naming.functionsPlan
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {}
}

resource functionsAppMapsIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: naming.functionsAppMapsIdentity
  location: location
}

resource functionsApp 'Microsoft.Web/sites@2022-03-01' = {
  name: naming.functionsApp
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${functionsAppMapsIdentity.id}': {}
    }
  }
  properties: {
    serverFarmId: functionsPlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${functionsStorage.name};AccountKey=${functionsStorage.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${functionsStorage.name};AccountKey=${functionsStorage.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(replace(naming.functionsApp, '-', ''))
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet-isolated'
        }
        {
          name: 'EventHubConnection__fullyQualifiedNamespace'
          value: '${eventHubNamespace.name}.servicebus.windows.net'
        }
        {
          name: 'EventHubName'
          value: prodLocationDataEventHub.name
        }
        {
          name: 'SqlConnectionString'
          value: 'Server=${sqlServer.name}${environment().suffixes.sqlServerHostname}; Database=${sqlDb.name}; Authentication=Active Directory Managed Identity; Encrypt=True;'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'AzureSignalRConnectionString'
          value: signalR.listKeys().primaryConnectionString
        }
        {
          name: 'AzureSignalRHubName'
          value: prodSignalRHubName
        }
        {
          name: 'MapsIdentityResourceId'
          value: functionsAppMapsIdentity.id
        }
        {
          name: 'MapsClientId'
          value: mapsAccount.properties.uniqueId
        }
        {
          name: 'AzureAdTenantId'
          value: functionsAdAppTenantId
        }
        {
          name: 'AzureAdClientId'
          value: functionsAdAppClientId
        }
        {
          name: 'AzureAdAppScope'
          value: functionsAdAppScope
        }
        {
          name: 'IotHubHostName'
          value: iotHub.properties.hostName
        }
        {
          name: 'AdxClusterUri'
          value: adxCluster.properties.uri
        }
        {
          name: 'AdxDbName'
          value: adxDb.name
        }
      ]
      ftpsState: 'Disabled'
      netFrameworkVersion: 'v6.0'
    }
  }
}

resource adxFunctionAppViewerAssignment 'Microsoft.Kusto/clusters/principalAssignments@2022-12-29' = {
  parent: adxCluster
  name: guid(adxCluster.id, functionsApp.id, 'Viewer')
  properties: {
    principalId: functionsApp.identity.principalId
    role: 'AllDatabasesViewer'
    principalType: 'App'
    tenantId: subscription().tenantId
  }
}

resource functionsAppEventHubReceiverRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: prodLocationDataEventHub
  name: guid(prodLocationDataEventHub.id, eventHubReceiverRoleDefinitionId, naming.functionsApp)
  properties: {
    roleDefinitionId: eventHubReceiverRoleDefinitionId
    principalId: functionsApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource functionsAppIotHubTwinContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: iotHub
  name: guid(iotHub.id, iotHubTwinContributorRoleDefinitionId, naming.functionsApp)
  properties: {
    roleDefinitionId: iotHubTwinContributorRoleDefinitionId
    principalId: functionsApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource functionsAppMapsReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: mapsAccount
  name: guid(mapsAccount.id, mapsSearchRenderReaderRoleDefinitionId, functionsAppMapsIdentity.id)
  properties: {
    roleDefinitionId: mapsSearchRenderReaderRoleDefinitionId
    principalId: functionsAppMapsIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

output appName string = functionsApp.name
output appSystemAssignedIdentityName string = functionsApp.name
output appHostName string = functionsApp.properties.defaultHostName
