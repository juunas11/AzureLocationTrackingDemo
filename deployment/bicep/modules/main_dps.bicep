param location string
param naming object
param dpsSkuName string
param dpsCapacity int
param iotHubName string

resource iotHub 'Microsoft.Devices/IotHubs@2021-07-02' existing = {
  name: iotHubName
}

resource deviceProvisioningService 'Microsoft.Devices/provisioningServices@2022-12-12' = {
  name: naming.deviceProvisioningService
  location: location
  sku: {
    name: dpsSkuName
    capacity: dpsCapacity
  }
  properties: {
    allocationPolicy: 'Hashed'
    publicNetworkAccess: 'Enabled'
    iotHubs: [
      {
        connectionString: 'HostName=${iotHub.name}.azure-devices.net;SharedAccessKeyName=iothubowner;SharedAccessKey=${iotHub.listKeys().value[0].primaryKey}'
        location: location
      }
    ]
  }
}

output name string = deviceProvisioningService.name
output globalEndpoint string = deviceProvisioningService.properties.deviceProvisioningHostName
output idScope string = deviceProvisioningService.properties.idScope
