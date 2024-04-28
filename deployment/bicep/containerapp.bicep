param location string = resourceGroup().location

// Parameters from command line
param containerRegistryName string
param containerAppEnvironmentName string
param containerAppIdentityName string
param cosmosAccountName string
param cosmosDatabaseName string
param cosmosVehicleContainerName string
param appInsightsConnectionString string
param deviceProvisioningServiceGlobalEndpoint string
param deviceProvisioningServiceIdScope string
@secure()
param dpsEnrollmentGroupPrimaryKey string

// Parameters from main.parameters.json
param cpuCores string
param memory string
param simulatedDeviceCount int
param minReplicas int
param maxReplicas int

var namingSuffix = uniqueString(resourceGroup().id)

var naming = {
  containerApp: 'ca-locationtracking${namingSuffix}'
}

resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2022-03-01' existing = {
  name: containerAppEnvironmentName
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-09-01' existing = {
  name: containerRegistryName
}

resource containerAppIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: containerAppIdentityName
}

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2023-11-15' existing = {
  name: cosmosAccountName
}

resource containerApp 'Microsoft.App/containerApps@2022-03-01' = {
  name: naming.containerApp
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${containerAppIdentity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppEnvironment.id
    configuration: {
      secrets: [
        {
          name: 'dps-enrollment-group-primary-key'
          value: dpsEnrollmentGroupPrimaryKey
        }
      ]
      activeRevisionsMode: 'Single'
      registries: [
        {
          server: containerRegistry.properties.loginServer
          identity: containerAppIdentity.id
        }
      ]
    }
    template: {
      revisionSuffix: ''
      containers: [
        {
          image: '${containerRegistry.properties.loginServer}/simulatedvehicle:latest'
          name: 'simulatedvehicle'
          resources: {
            #disable-next-line BCP036
            cpu: cpuCores
            memory: memory
          }
          env: [
            {
              name: 'ENVIRONMENT'
              value: 'prod'
            }
            {
              name: 'SIMULATED_DEVICE_COUNT'
              value: string(simulatedDeviceCount)
            }
            {
              name: 'MANAGED_IDENTITY_CLIENT_ID'
              value: containerAppIdentity.properties.clientId
            }
            {
              name: 'DEVICE_PROVISIONING_PRIMARY_KEY'
              secretRef: 'dps-enrollment-group-primary-key'
            }
            {
              name: 'DEVICE_PROVISIONING_GLOBAL_ENDPOINT'
              value: deviceProvisioningServiceGlobalEndpoint
            }
            {
              name: 'DEVICE_PROVISIONING_ID_SCOPE'
              value: deviceProvisioningServiceIdScope
            }
            {
              name: 'COSMOS_DB_ENDPOINT'
              value: cosmosAccount.properties.documentEndpoint
            }
            {
              name: 'COSMOS_DB_NAME'
              value: cosmosDatabaseName
            }
            {
              name: 'COSMOS_VEHICLE_CONTAINER_NAME'
              value: cosmosVehicleContainerName
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: appInsightsConnectionString
            }
          ]
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
      }
    }
  }
}

output containerAppName string = containerApp.name
