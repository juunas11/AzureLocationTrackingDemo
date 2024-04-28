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

    Write-Host "User secrets needed to run AzureLocationTracking.VehicleSimulator locally:"
    $vehicleSimulatorSecrets = @{
        SQL_CONNECTION_STRING                 = "<your-local-sql-db-connection-string>"
        ENVIRONMENT                           = "dev"
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
            SqlConnectionString                   = "<your-local-sql-db-connection-string>"
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
        }
    } | ConvertTo-Json
    Write-Host $functionsSettings
}

Export-ModuleMember -Function Show-ContainerLocalSettings, Show-FunctionLocalSettings