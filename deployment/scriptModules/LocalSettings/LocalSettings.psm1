function Show-ContainerLocalSettings {
    param(
        [Parameter(Mandatory = $true)]
        [object] $mainBicepOutputs,

        [Parameter(Mandatory = $true)]
        [string] $devEnrollmentGroupPrimaryKey
    )
    
    $appInsightsConnectionString = $mainBicepOutputs.appInsightsConnectionString.value
    $deviceProvisioningServiceGlobalEndpoint = $mainBicepOutputs.deviceProvisioningServiceGlobalEndpoint.value
    $deviceProvisioningServiceIdScope = $mainBicepOutputs.deviceProvisioningServiceIdScope.value
    $cosmosDatabaseName = $mainBicepOutputs.cosmosDatabaseName.value
    $cosmosVehicleContainerName = $mainBicepOutputs.cosmosVehicleContainerName.value

    Write-Host "User secrets needed to run AzureLocationTracking.VehicleSimulator locally:"
    $vehicleSimulatorSecrets = @{
        ENVIRONMENT                           = "dev"
        COSMOS_DB_ENDPOINT                    = "https://localhost:8081"
        COSMOS_DB_KEY                         = "C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw=="
        COSMOS_DB_NAME                        = $cosmosDatabaseName
        COSMOS_VEHICLE_CONTAINER_NAME         = $cosmosVehicleContainerName
        APPLICATIONINSIGHTS_CONNECTION_STRING = $appInsightsConnectionString
        DEVICE_PROVISIONING_PRIMARY_KEY       = $devEnrollmentGroupPrimaryKey
        DEVICE_PROVISIONING_GLOBAL_ENDPOINT   = $deviceProvisioningServiceGlobalEndpoint
        DEVICE_PROVISIONING_ID_SCOPE          = $deviceProvisioningServiceIdScope
    } | ConvertTo-Json
    Write-Host $vehicleSimulatorSecrets
}

function Show-FunctionLocalSettings {
    param(
        [Parameter(Mandatory = $true)]
        [object] $config,

        [Parameter(Mandatory = $true)]
        [object] $mainBicepOutputs,

        [Parameter(Mandatory = $true)]
        [string] $adAppClientId,

        [Parameter(Mandatory = $true)]
        [string] $adApplicationScopeIdentifier
    )
    
    $tenantId = $config.tenantId
    $subscriptionId = $config.subscriptionId
    $resourceGroup = $config.resourceGroup
    $adApplicationTenantId = $config.adApplicationTenantId
    $devSignalRHubName = $config.devSignalRHubName

    $eventHubNamespaceName = $mainBicepOutputs.eventHubNamespaceName.value
    $devLocationDataEventHubName = $mainBicepOutputs.devLocationDataEventHubName.value
    $devLocationDataEventHubKeyName = $mainBicepOutputs.devLocationDataEventHubKeyName.value
    $signalRName = $mainBicepOutputs.signalRName.value
    $appInsightsConnectionString = $mainBicepOutputs.appInsightsConnectionString.value
    $iotHubHostName = $mainBicepOutputs.iotHubHostName.value
    $adxClusterUri = $mainBicepOutputs.adxClusterUri.value
    $devAdxDbName = $mainBicepOutputs.devAdxDbName.value
    $cosmosDatabaseName = $mainBicepOutputs.cosmosDatabaseName.value
    $cosmosVehicleContainerName = $mainBicepOutputs.cosmosVehicleContainerName.value
    $cosmosVehiclesInGeofencesContainerName = $mainBicepOutputs.cosmosVehiclesInGeofencesContainerName.value
    $cosmosGeofenceContainerName = $mainBicepOutputs.cosmosGeofenceContainerName.value

    $devEventHubConnectionString = az eventhubs eventhub authorization-rule keys list `
        --subscription $subscriptionId -g $resourceGroup --namespace-name $eventHubNamespaceName `
        --eventhub-name $devLocationDataEventHubName --name $devLocationDataEventHubKeyName `
        --query primaryConnectionString -o tsv
    $devEventHubConnectionString = $devEventHubConnectionString.Substring(0, $devEventHubConnectionString.IndexOf(";EntityPath"))

    $signalRConnectionString = az signalr key list --subscription $subscriptionId -g $resourceGroup `
        -n $signalRName --query primaryConnectionString -o tsv

    Write-Host "local.settings.json content needed to run AzureLocationTracking.Functions locally:"
    $functionsSettings = @{
        IsEncrypted = $false
        Values      = @{
            AzureWebJobsStorage                   = "UseDevelopmentStorage=True"
            FUNCTIONS_WORKER_RUNTIME              = "dotnet-isolated"
            EventHubName                          = $devLocationDataEventHubName
            EventHubConnection                    = $devEventHubConnectionString
            AzureSignalRConnectionString          = $signalRConnectionString
            AzureSignalRHubName                   = $devSignalRHubName
            APPLICATIONINSIGHTS_CONNECTION_STRING = $appInsightsConnectionString
            LocalAuthTenantId                     = $tenantId
            MapsClientId                          = $mainBicepOutputs.mapsAccountClientId.value
            AzureAdTenantId                       = $adApplicationTenantId
            AzureAdClientId                       = $adAppClientId
            AzureAdAppScope                       = $adApplicationScopeIdentifier
            IotHubHostName                        = $iotHubHostName
            AdxClusterUri                         = $adxClusterUri
            AdxDbName                             = $devAdxDbName
            CosmosEndpoint                        = "https://localhost:8081"
            CosmosKey                             = "C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw=="
            CosmosDatabase                        = $cosmosDatabaseName
            CosmosVehicleContainer                = $cosmosVehicleContainerName
            CosmosVehiclesInGeofencesContainer    = $cosmosVehiclesInGeofencesContainerName
            CosmosGeofenceContainer               = $cosmosGeofenceContainerName
        }
    } | ConvertTo-Json
    Write-Host $functionsSettings
}

Export-ModuleMember -Function Show-ContainerLocalSettings, Show-FunctionLocalSettings