param location string
param naming object
param sqlAdminUserId string
param sqlAdminUsername string
param sqlFirewallAllowedIpAddress string

resource sqlServer 'Microsoft.Sql/servers@2022-05-01-preview' = {
  name: naming.sqlServer
  location: location
  properties: {
    administrators: {
      administratorType: 'ActiveDirectory'
      azureADOnlyAuthentication: true
      principalType: 'User'
      tenantId: tenant().tenantId
      sid: sqlAdminUserId
      login: sqlAdminUsername
    }
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }

  resource azureFirewallRule 'firewallRules@2022-05-01-preview' = {
    name: 'Allow Azure'
    properties: {
      startIpAddress: '0.0.0.0'
      endIpAddress: '0.0.0.0'
    }
  }

  resource devFirewallRule 'firewallRules@2022-05-01-preview' = {
    name: 'Allow developer'
    properties: {
      startIpAddress: sqlFirewallAllowedIpAddress
      endIpAddress: sqlFirewallAllowedIpAddress
    }
  }
}

resource sqlDb 'Microsoft.Sql/servers/databases@2022-05-01-preview' = {
  parent: sqlServer
  name: naming.sqlDb
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
    capacity: 10
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 2147483648
  }
}

output serverName string = sqlServer.name
output serverFqdn string = sqlServer.properties.fullyQualifiedDomainName
output dbName string = sqlDb.name
