param location string = resourceGroup().location

// Parameters from command line
param acrPushUserId string
param cosmosContributorUserId string
param mapsReaderUserId string
param adxAdminUserId string
param functionsAdAppTenantId string
param functionsAdAppClientId string
param functionsAdAppScope string
param iotHubTwinContributorUserId string
param prodSignalRHubName string
param devSignalRHubName string
@secure()
param prodSignalRUpstreamUrl string
@secure()
param devSignalRUpstreamUrl string

// Parameters from main.parameters.json
param containerRegistrySku string
param dpsSkuName string
param dpsCapacity int
param iotHubEventHubPartitionCount int
param iotHubSku string
param iotHubCapacity int
param eventHubSku string
param eventHubCapacity int
param adxSkuName string
param adxSkuTier string
param adxCapacity int
param signalRSku string
param signalRCapacity int
param vehicleContainerThroughput int
param geofenceContainerThroughput int
param vehiclesInGeofencesContainerThroughput int

var appName = 'locationtracking'
var namingSuffix = uniqueString(resourceGroup().id)
var naming = {
  adxCluster: 'adxloctra${namingSuffix}'
  adxDbDev: 'LocationDataDev'
  adxDbProd: 'LocationDataProd'
  appInsights: 'ai-${appName}-${namingSuffix}'
  containerAppEnvironment: 'cae-${appName}-${namingSuffix}'
  containerAppIdentity: 'ca-id-${appName}-${namingSuffix}'
  containerRegistry: 'cr${appName}${namingSuffix}'
  cosmosAccount: 'cosmos-${appName}-${namingSuffix}'
  cosmosDatabase: 'LocationDataDb'
  cosmosGeofenceContainer: 'Geofences'
  cosmosVehicleContainer: 'Vehicles'
  cosmosVehiclesInGeofencesContainer: 'VehiclesInGeofences'
  deviceProvisioningService: 'dps-${appName}-${namingSuffix}'
  eventHubConsumerGroupAdx: 'azureDataExplorer'
  eventHubConsumerGroupGeofenceCheck: 'geofenceCheck'
  eventHubConsumerGroupLatestLocationUpdate: 'latestLocationUpdate'
  eventHubDevKeyName: 'dev'
  eventHubNamespace: 'eh-${appName}-${namingSuffix}'
  functionsApp: 'func-${appName}-${namingSuffix}'
  functionsAppMapsIdentity: 'func-id-maps-${appName}-${namingSuffix}'
  functionsPlan: 'fp-${appName}-${namingSuffix}'
  functionsStorage: 'stolt${namingSuffix}'
  iotHub: 'iot-${appName}-${namingSuffix}'
  iotHubIdentity: 'iot-id-${appName}-${namingSuffix}'
  locationDataEventHubProd: 'locationdata'
  locationDataEventHubDev: 'locationdatadev'
  logAnalytics: 'log-${appName}-${namingSuffix}'
  mapsAccount: 'maps-${appName}-${namingSuffix}'
  signalR: 'sig-${appName}-${namingSuffix}'
}

module eventHub 'modules/main_eventhub.bicep' = {
  name: '${deployment().name}-eventhub'
  params: {
    location: location
    naming: naming
    iotHubEventHubPartitionCount: iotHubEventHubPartitionCount
    eventHubSku: eventHubSku
    eventHubCapacity: eventHubCapacity
  }
}

module iotHub 'modules/main_iothub.bicep' = {
  name: '${deployment().name}-iothub'
  params: {
    location: location
    naming: naming
    iotHubEventHubPartitionCount: iotHubEventHubPartitionCount
    iotHubSku: iotHubSku
    iotHubCapacity: iotHubCapacity
    eventHubNamespaceName: eventHub.outputs.namespaceName
    prodLocationDataEventHubName: eventHub.outputs.prodEventHubName
    devLocationDataEventHubName: eventHub.outputs.devEventHubName
    iotHubTwinContributorUserId: iotHubTwinContributorUserId
  }
}

module deviceProvisioningService 'modules/main_dps.bicep' = {
  name: '${deployment().name}-dps'
  params: {
    location: location
    naming: naming
    dpsSkuName: dpsSkuName
    dpsCapacity: dpsCapacity
    iotHubName: iotHub.outputs.name
  }
}

module adx 'modules/main_adx.bicep' = {
  name: '${deployment().name}-adx'
  params: {
    location: location
    naming: naming
    adxSkuName: adxSkuName
    adxSkuTier: adxSkuTier
    adxCapacity: adxCapacity
    eventHubNamespaceName: eventHub.outputs.namespaceName
    prodLocationDataEventHubName: eventHub.outputs.prodEventHubName
    devLocationDataEventHubName: eventHub.outputs.devEventHubName
    adxAdminUserId: adxAdminUserId
  }
}

module logging 'modules/main_logging.bicep' = {
  name: '${deployment().name}-logging'
  params: {
    location: location
    naming: naming
  }
}

module containers 'modules/main_containers.bicep' = {
  name: '${deployment().name}-containers'
  params: {
    location: location
    naming: naming
    containerRegistrySku: containerRegistrySku
    acrPushUserId: acrPushUserId
    eventHubNamespaceName: eventHub.outputs.namespaceName
    prodLocationDataEventHubName: eventHub.outputs.prodEventHubName
    logAnalyticsWorkspaceName: logging.outputs.logAnalyticsWorkspaceName
    cosmosAccountName: cosmos.outputs.accountName
    cosmosDatabaseName: cosmos.outputs.databaseName
    cosmosVehicleContainerName: cosmos.outputs.vehicleContainerName
  }
}

module cosmos 'modules/main_cosmos.bicep' = {
  name: '${deployment().name}-cosmos'
  params: {
    location: location
    naming: naming
    cosmosContributorUserId: cosmosContributorUserId
    vehicleContainerThroughput: vehicleContainerThroughput
    geofenceContainerThroughput: geofenceContainerThroughput
    vehiclesInGeofencesContainerThroughput: vehiclesInGeofencesContainerThroughput
  }
}

module signalr 'modules/main_signalr.bicep' = {
  name: '${deployment().name}-signalr'
  params: {
    location: location
    naming: naming
    signalRSku: signalRSku
    signalRCapacity: signalRCapacity
    devUpstreamUrl: devSignalRUpstreamUrl
    prodUpstreamUrl: prodSignalRUpstreamUrl
    devHubName: devSignalRHubName
    prodHubName: prodSignalRHubName
  }
}

module maps 'modules/main_maps.bicep' = {
  name: '${deployment().name}-maps'
  params: {
    location: location
    naming: naming
    mapsReaderUserId: mapsReaderUserId
  }
}

module functions 'modules/main_functions.bicep' = {
  name: '${deployment().name}-functions'
  params: {
    location: location
    naming: naming
    functionsAdAppTenantId: functionsAdAppTenantId
    functionsAdAppClientId: functionsAdAppClientId
    functionsAdAppScope: functionsAdAppScope
    eventHubNamespaceName: eventHub.outputs.namespaceName
    prodLocationDataEventHubName: eventHub.outputs.prodEventHubName
    signalRName: signalr.outputs.name
    prodSignalRHubName: prodSignalRHubName
    adxClusterName: adx.outputs.clusterName
    prodAdxDbName: naming.adxDbProd
    appInsightsName: logging.outputs.appInsightsName
    iotHubName: iotHub.outputs.name
    mapsAccountName: maps.outputs.name
    cosmosAccountName: cosmos.outputs.accountName
  }
}

output deviceProvisioningServiceName string = deviceProvisioningService.outputs.name
output deviceProvisioningServiceGlobalEndpoint string = deviceProvisioningService.outputs.globalEndpoint
output deviceProvisioningServiceIdScope string = deviceProvisioningService.outputs.idScope
output iotHubHostName string = iotHub.outputs.hostName
output iotHubName string = iotHub.outputs.name
output eventHubNamespaceName string = eventHub.outputs.namespaceName
output prodLocationDataEventHubName string = eventHub.outputs.prodEventHubName
output devLocationDataEventHubName string = eventHub.outputs.devEventHubName
output devLocationDataEventHubKeyName string = naming.eventHubDevKeyName
output eventHubConsumerGroupAdx string = naming.eventHubConsumerGroupAdx
output containerRegistryName string = containers.outputs.containerRegistryName
output containerAppEnvironmentName string = containers.outputs.containerAppEnvironmentName
output containerAppIdentityName string = containers.outputs.containerAppIdentityName
output logAnalyticsWorkspaceName string = logging.outputs.logAnalyticsWorkspaceName
output cosmosAccountName string = cosmos.outputs.accountName
output cosmosAccountEndpoint string = cosmos.outputs.accountEndpoint
output cosmosDatabaseName string = cosmos.outputs.databaseName
output cosmosGeofenceContainerName string = cosmos.outputs.geofenceContainerName
output cosmosVehicleContainerName string = cosmos.outputs.vehicleContainerName
output cosmosVehiclesInGeofencesContainerName string = cosmos.outputs.vehiclesInGeofencesContainerName
output functionsAppName string = functions.outputs.appName
output functionsAppIdentityName string = functions.outputs.appSystemAssignedIdentityName
output functionsAppHostName string = functions.outputs.appHostName
output appInsightsName string = logging.outputs.appInsightsName
output appInsightsConnectionString string = logging.outputs.appInsightsConnectionString
output signalRName string = signalr.outputs.name
output adxClusterName string = adx.outputs.clusterName
output adxClusterUri string = adx.outputs.clusterUri
output prodAdxDbName string = naming.adxDbProd
output devAdxDbName string = naming.adxDbDev
output mapsAccountClientId string = maps.outputs.clientId
