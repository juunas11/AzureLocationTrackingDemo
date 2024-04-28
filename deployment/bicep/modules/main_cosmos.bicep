param location string
param naming object
param cosmosContributorUserId string
param vehicleContainerThroughput int
param geofenceContainerThroughput int
param vehiclesInGeofencesContainerThroughput int

var cosmosContributorRoleDefinitionId = '00000000-0000-0000-0000-000000000002'

resource account 'Microsoft.DocumentDB/databaseAccounts@2023-11-15' = {
  name: naming.cosmosAccount
  location: location
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        locationName: location
      }
    ]
    consistencyPolicy: {
      // Session should be fine for our use case where a Function App instance
      // will be handling all events for a specific vehicle ID,
      // which is the partition key for the containers where it matters
      defaultConsistencyLevel: 'Session'
    }
    disableKeyBasedMetadataWriteAccess: true
    disableLocalAuth: true
    minimalTlsVersion: 'Tls12'
    publicNetworkAccess: 'Enabled'
  }
}

resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2023-11-15' = {
  name: naming.cosmosDatabase
  parent: account
  properties: {
    resource: {
      id: naming.cosmosDatabase
    }
  }
}

resource vehicleContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2023-11-15' = {
  name: naming.cosmosVehicleContainer
  parent: database
  properties: {
    options: {
      throughput: vehicleContainerThroughput
    }
    resource: {
      id: naming.cosmosVehicleContainer
      partitionKey: {
        paths: [
          '/id'
        ]
        kind: 'Hash'
      }
      // Keep the vehicles for 24 hours, automatic cleanup
      // This is just for the sake of the sample app
      defaultTtl: 86400
      indexingPolicy: {
        indexingMode: 'consistent'
        includedPaths: [
          {
            path: '/*'
          }
        ]
        excludedPaths: [
          {
            path: '/"_etag"/?'
          }
          {
            path: '/createdAt/?'
          }
        ]
        spatialIndexes: [
          {
            path: '/latestLocation/*'
            types: [
              'Point'
            ]
          }
        ]
      }
    }
  }
}

resource geofenceContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2023-11-15' = {
  name: naming.cosmosGeofenceContainer
  parent: database
  properties: {
    options: {
      throughput: geofenceContainerThroughput
    }
    resource: {
      id: naming.cosmosGeofenceContainer
      partitionKey: {
        paths: [
          '/gridSquare'
        ]
        kind: 'Hash'
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        includedPaths: [
          {
            path: '/*'
          }
        ]
        excludedPaths: [
          {
            path: '/"_etag"/?'
          }
          {
            path: '/name/?'
          }
        ]
        spatialIndexes: [
          {
            path: '/border/*'
            types: [
              'Polygon'
            ]
          }
        ]
      }
    }
  }
}

resource vehiclesInGeofencesContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2023-11-15' = {
  name: naming.cosmosVehiclesInGeofencesContainer
  parent: database
  properties: {
    options: {
      throughput: vehiclesInGeofencesContainerThroughput
    }
    resource: {
      id: naming.cosmosVehiclesInGeofencesContainer
      partitionKey: {
        paths: [
          '/vehicleId'
        ]
        kind: 'Hash'
      }
      defaultTtl: 86400
      indexingPolicy: {
        indexingMode: 'consistent'
        includedPaths: [
          {
            path: '/*'
          }
        ]
        excludedPaths: [
          {
            path: '/"_etag"/?'
          }
          {
            path: '/geofenceId/?'
          }
        ]
      }
    }
  }
}

resource developerCosmosContributorRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2023-11-15' = {
  name: guid(account.id, cosmosContributorUserId, cosmosContributorRoleDefinitionId)
  parent: account
  properties: {
    principalId: cosmosContributorUserId
    roleDefinitionId: resourceId(
      'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions',
      account.name,
      cosmosContributorRoleDefinitionId
    )
    scope: account.id
  }
}

output accountName string = account.name
output accountEndpoint string = account.properties.documentEndpoint
output databaseName string = database.name
output vehicleContainerName string = vehicleContainer.name
output geofenceContainerName string = geofenceContainer.name
output vehiclesInGeofencesContainerName string = vehiclesInGeofencesContainer.name
