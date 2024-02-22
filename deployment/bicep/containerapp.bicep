param location string = resourceGroup().location
param containerRegistryName string
param containerAppEnvironmentName string
param containerAppIdentityName string
param sqlServerFqdn string
param sqlDbName string
param appInsightsConnectionString string
param deviceProvisioningServiceGlobalEndpoint string
param deviceProvisioningServiceIdScope string
param iotHubHostName string
@secure()
param dpsEnrollmentGroupPrimaryKey string

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
          image: '${containerRegistry.properties.loginServer}/simulatedtracker:latest'
          name: 'simulatedtracker'
          resources: {
            #disable-next-line BCP036
            cpu: '0.25'
            memory: '0.5Gi'
          }
          env: [
            {
              name: 'ENVIRONMENT'
              value: 'prod'
            }
            {
              name: 'SIMULATED_DEVICE_COUNT'
              value: '10'
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
              name: 'IOT_HUB_HOST_NAME'
              value: iotHubHostName
            }
            {
              name: 'SQL_CONNECTION_STRING'
              value: 'Server=${sqlServerFqdn}; Authentication=Active Directory Managed Identity; Encrypt=True; User Id=${containerAppIdentity.properties.clientId}; Database=${sqlDbName}'
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: appInsightsConnectionString
            }
          ]
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 1
      }
    }
  }
}

output containerAppName string = containerApp.name
