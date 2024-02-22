param location string
param naming object
param mapsReaderUserId string

var mapsSearchRenderReaderRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '6be48352-4f82-47c9-ad5e-0acacefdb005')

resource mapsAccount 'Microsoft.Maps/accounts@2021-12-01-preview' = {
  name: naming.mapsAccount
  location: location
  sku: {
    name: 'G2'
  }
  kind: 'Gen2'
  properties: {
    disableLocalAuth: true
    cors: {
      corsRules: [
        {
          allowedOrigins: [
            'http://localhost:7090'
            'http://localhost:5173'
            'https://${naming.functionsApp}.azurewebsites.net'
          ]
        }
      ]
    }
  }
}

resource developerMapsReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: mapsAccount
  name: guid(mapsAccount.id, mapsSearchRenderReaderRoleDefinitionId, mapsReaderUserId)
  properties: {
    roleDefinitionId: mapsSearchRenderReaderRoleDefinitionId
    principalId: mapsReaderUserId
    principalType: 'User'
  }
}

output name string = mapsAccount.name
output clientId string = mapsAccount.properties.uniqueId
