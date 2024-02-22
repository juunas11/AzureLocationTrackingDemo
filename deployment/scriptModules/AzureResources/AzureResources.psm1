function Set-ResourceGroup {
    param (
        [Parameter(Mandatory = $true)]
        [object] $config
    )

    $subscriptionId = $config.subscriptionId
    $resourceGroup = $config.resourceGroup
    $location = $config.location

    $rgExists = az group exists --subscription "$subscriptionId" -g "$resourceGroup"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to check if resource group exists."
    }

    if ($rgExists -eq "false") {
        Write-Host "Resource group does not exist. Creating resource group..."
        az group create --subscription "$subscriptionId" -g "$resourceGroup" -l "$location"
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create resource group."
        }
    }
}

function Get-SignalRUpstreamUrls {
    param(
        [Parameter(Mandatory = $true)]
        [object] $config
    )

    $subscriptionId = $config.subscriptionId
    $resourceGroup = $config.resourceGroup
    $prodHubName = $config.prodSignalRHubName.ToLower()
    $devHubName = $config.devSignalRHubName.ToLower()

    Write-Host "Getting current SignalR service upstream URLs..."

    $signalRName = az signalr list --subscription "$subscriptionId" -g "$resourceGroup" --query "[].name" -o tsv
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to get SignalR service name."
    }

    if (-not $signalRName) {
        return @{
            prodUpstreamUrl = ""
            devUpstreamUrl  = ""
        }
    }

    $prodUpstreamUrl = az signalr show --subscription "$subscriptionId" -g "$resourceGroup" -n "$signalRName" --query "upstream.templates[?hubPattern == ``$($prodHubName)``].urlTemplate" -o tsv
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to get SignalR service production upstream URL."
    }

    $devUpstreamUrl = az signalr show --subscription "$subscriptionId" -g "$resourceGroup" -n "$signalRName" --query "upstream.templates[?hubPattern == ``$($devHubName)``].urlTemplate" -o tsv
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to get SignalR service development upstream URL."
    }

    return @{
        prodUpstreamUrl = $prodUpstreamUrl
        devUpstreamUrl  = $devUpstreamUrl
    }
}

function Set-SignalRUpstreamUrls {
    param(
        [Parameter(Mandatory = $true)]
        [object] $config,

        [Parameter(Mandatory = $true)]
        [string] $signalRName,

        [Parameter(Mandatory = $false)]
        [string] $currentProdUpstreamUrl,

        [Parameter(Mandatory = $false)]
        [string] $currentDevUpstreamUrl,

        [Parameter(Mandatory = $true)]
        [string] $functionsAppName,

        [Parameter(Mandatory = $true)]
        [string] $functionsAppHostName
    )

    $subscriptionId = $config.subscriptionId
    $resourceGroup = $config.resourceGroup
    $prodHubName = $config.prodSignalRHubName.ToLower()
    $devHubName = $config.devSignalRHubName.ToLower()

    Write-Host "Setting SignalR service upstream URLs..."

    # Note: I think this key is not going to exist on first deployment,
    # since we haven't deployed the Functions App content yet.
    # That will require running the deployment again.

    $functionsAppKey = az functionapp keys list --subscription "$subscriptionId" -g "$resourceGroup" -n "$functionsAppName" --query "systemKeys.signalr_extension" -o tsv
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to get Functions App key for SignalR extension"
    }

    if (-not $functionsAppKey) {
        Write-Host "Functions App key for SignalR extension not found (content not yet deployed?). Removing SignalR service production upstream URL."
        $updatedProdUpstreamUrl = ""
    }
    else {
        $updatedProdUpstreamUrl = "https://$functionsAppHostName/runtime/webhooks/signalr?code=$functionsAppKey"
    }

    if ($currentDevUpstreamUrl -and $updatedProdUpstreamUrl) {
        # Set both dev and prod upstream URLs
        az signalr upstream update --subscription "$subscriptionId" -g "$resourceGroup" -n "$signalRName" `
            --template url-template="$updatedProdUpstreamUrl" hub-pattern="$prodHubName" category-pattern="*" event-pattern="*" `
            --template url-template="$currentDevUpstreamUrl" hub-pattern="$devHubName" category-pattern="*" event-pattern="*" | Out-Null
    }
    elseif (-not $currentDevUpstreamUrl -and $updatedProdUpstreamUrl) {
        # Only set prod upstream URL
        az signalr upstream update --subscription "$subscriptionId" -g "$resourceGroup" -n "$signalRName" `
            --template url-template="$updatedProdUpstreamUrl" hub-pattern="$prodHubName" category-pattern="*" event-pattern="*" | Out-Null
    }
    elseif ($currentDevUpstreamUrl -and -not $updatedProdUpstreamUrl) {
        # Only set dev upstream URL
        az signalr upstream update --subscription "$subscriptionId" -g "$resourceGroup" -n "$signalRName" `
            --template url-template="$currentDevUpstreamUrl" hub-pattern="$devHubName" category-pattern="*" event-pattern="*" | Out-Null
    }
    else {
        az signalr upstream clear --subscription "$subscriptionId" -g "$resourceGroup" -n "$signalRName" | Out-Null
    }
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to set SignalR service upstream URLs."
    }
}

function Deploy-MainTemplate {
    param (
        [Parameter(Mandatory = $true)]
        [string] $bicepDirectoryPath,

        [Parameter(Mandatory = $true)]
        [object] $config,

        [Parameter(Mandatory = $true)]
        [string] $deploymentNamePrefix,

        [Parameter(Mandatory = $true)]
        [string] $adAppClientId,

        [Parameter(Mandatory = $true)]
        [string] $adApplicationScopeIdentifier
    )

    Push-Location $bicepDirectoryPath

    $subscriptionId = $config.subscriptionId
    $resourceGroup = $config.resourceGroup
    $developerUserId = $config.developerUserId
    $developerUsername = $config.developerUsername
    $developerIpAddress = $config.developerIpAddress
    $adApplicationTenantId = $config.adApplicationTenantId
    $prodSignalRHubName = $config.prodSignalRHubName
    $devSignalRHubName = $config.devSignalRHubName

    $signalRUpstreamUrls = Get-SignalRUpstreamUrls -config $config
    $prodSignalRUpstreamUrl = $signalRUpstreamUrls.prodUpstreamUrl
    $devSignalRUpstreamUrl = $signalRUpstreamUrls.devUpstreamUrl

    Write-Host "Running main.bicep deployment..."
    $mainBicepResult = az deployment group create --subscription "$subscriptionId" -g "$resourceGroup" -f "main.bicep" -n "$deploymentNamePrefix-Main" --mode "Incremental" `
        -p "@main.parameters.json" `
        -p acrPushUserId=$developerUserId sqlAdminUserId=$developerUserId mapsReaderUserId=$developerUserId adxAdminUserId=$developerUserId `
        -p sqlAdminUsername=$developerUsername sqlFirewallAllowedIpAddress=$developerIpAddress `
        -p functionsAdAppTenantId=$adApplicationTenantId functionsAdAppClientId=$adAppClientId functionsAdAppScope=$adApplicationScopeIdentifier `
        -p iotHubTwinContributorUserId=$developerUserId `
        -p prodSignalRUpstreamUrl=$prodSignalRUpstreamUrl devSignalRUpstreamUrl=$devSignalRUpstreamUrl `
        -p prodSignalRHubName=$prodSignalRHubName devSignalRHubName=$devSignalRHubName | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) {
        Pop-Location
        throw "Failed to deploy main.bicep."
    }

    $mainBicepOutputs = $mainBicepResult.properties.outputs

    Set-SignalRUpstreamUrls -config $config `
        -signalRName $mainBicepOutputs.signalRName.value `
        -currentProdUpstreamUrl $prodSignalRUpstreamUrl `
        -currentDevUpstreamUrl $devSignalRUpstreamUrl `
        -functionsAppName $mainBicepOutputs.functionsAppName.value `
        -functionsAppHostName $mainBicepOutputs.functionsAppHostName.value

    Pop-Location
    return $mainBicepOutputs
}

function Deploy-AdxDataConnectionsTemplate {
    param(
        [Parameter(Mandatory = $true)]
        [string] $bicepDirectoryPath,

        [Parameter(Mandatory = $true)]
        [object] $config,

        [Parameter(Mandatory = $true)]
        [object] $mainBicepOutputs,

        [Parameter(Mandatory = $true)]
        [string] $deploymentNamePrefix
    )

    Push-Location $bicepDirectoryPath

    $subscriptionId = $config.subscriptionId
    $resourceGroup = $config.resourceGroup

    $eventHubNamespaceName = $mainBicepOutputs.eventHubNamespaceName.value
    $prodLocationDataEventHubName = $mainBicepOutputs.prodLocationDataEventHubName.value
    $devLocationDataEventHubName = $mainBicepOutputs.devLocationDataEventHubName.value
    $eventHubConsumerGroupAdx = $mainBicepOutputs.eventHubConsumerGroupAdx.value
    $adxClusterName = $mainBicepOutputs.adxClusterName.value
    $prodAdxDbName = $mainBicepOutputs.prodAdxDbName.value
    $devAdxDbName = $mainBicepOutputs.devAdxDbName.value

    Write-Host "Running adxdataconnections.bicep deployment..."
    az deployment group create --subscription "$subscriptionId" -g "$resourceGroup" -f "adxdataconnections.bicep" -n "$deploymentNamePrefix-AdxDataConnections" --mode "Incremental" `
        -p "@adxdataconnections.parameters.json" `
        -p adxClusterName=$adxClusterName prodAdxDbName=$prodAdxDbName devAdxDbName=$devAdxDbName `
        -p eventHubNamespaceName=$eventHubNamespaceName prodLocationDataEventHubName=$prodLocationDataEventHubName devLocationDataEventHubName=$devLocationDataEventHubName `
        -p eventHubConsumerGroupAdx=$eventHubConsumerGroupAdx | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Pop-Location
        throw "Failed to deploy adxdataconnections.bicep."
    }
    
    Pop-Location
}

function Deploy-ContainerAppTemplate {
    param(
        [Parameter(Mandatory = $true)]
        [string] $bicepDirectoryPath,

        [Parameter(Mandatory = $true)]
        [object] $config,

        [Parameter(Mandatory = $true)]
        [object] $mainBicepOutputs,

        [Parameter(Mandatory = $true)]
        [string] $deploymentNamePrefix,

        [Parameter(Mandatory = $true)]
        [string] $prodEnrollmentGroupPrimaryKey
    )

    Push-Location $bicepDirectoryPath

    $subscriptionId = $config.subscriptionId
    $resourceGroup = $config.resourceGroup

    $containerRegistryName = $mainBicepOutputs.containerRegistryName.value
    $containerAppEnvironmentName = $mainBicepOutputs.containerAppEnvironmentName.value
    $containerAppIdentityName = $mainBicepOutputs.containerAppIdentityName.value
    $appInsightsConnectionString = $mainBicepOutputs.appInsightsConnectionString.value
    $deviceProvisioningServiceGlobalEndpoint = $mainBicepOutputs.deviceProvisioningServiceGlobalEndpoint.value
    $deviceProvisioningServiceIdScope = $mainBicepOutputs.deviceProvisioningServiceIdScope.value
    $iotHubHostName = $mainBicepOutputs.iotHubHostName.value
    $sqlServerFqdn = $mainBicepOutputs.sqlServerFqdn.value
    $sqlDbName = $mainBicepOutputs.sqlDbName.value

    Write-Host "Running containerapp.bicep deployment..."
    $containerAppBicepResult = az deployment group create --subscription "$subscriptionId" -g "$resourceGroup" -f "containerapp.bicep" -n "$deploymentNamePrefix-ContainerApp" --mode "Incremental" `
        -p "@containerapp.parameters.json" `
        -p containerAppEnvironmentName=$containerAppEnvironmentName containerRegistryName=$containerRegistryName containerAppIdentityName=$containerAppIdentityName `
        -p deviceProvisioningServiceGlobalEndpoint=$deviceProvisioningServiceGlobalEndpoint deviceProvisioningServiceIdScope=$deviceProvisioningServiceIdScope `
        -p dpsEnrollmentGroupPrimaryKey=$prodEnrollmentGroupPrimaryKey iotHubHostName=$iotHubHostName `
        -p sqlServerFqdn=$sqlServerFqdn sqlDbName=$sqlDbName appInsightsConnectionString=$appInsightsConnectionString | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) {
        Pop-Location
        throw "Failed to deploy containerapp.bicep."
    }

    Pop-Location
    return $containerAppBicepResult.properties.outputs
}

function Deploy-DashboardTemplate {
    param(
        [Parameter(Mandatory = $true)]
        [string] $bicepDirectoryPath,

        [Parameter(Mandatory = $true)]
        [object] $config,

        [Parameter(Mandatory = $true)]
        [object] $mainBicepOutputs,

        [Parameter(Mandatory = $true)]
        [object] $containerAppBicepOutputs,

        [Parameter(Mandatory = $true)]
        [string] $deploymentNamePrefix
    )

    Push-Location $bicepDirectoryPath

    $subscriptionId = $config.subscriptionId
    $resourceGroup = $config.resourceGroup

    $containerAppName = $containerAppBicepOutputs.containerAppName.value
    $appInsightsName = $mainBicepOutputs.appInsightsName.value
    $signalRName = $mainBicepOutputs.signalRName.value
    $sqlServerName = $mainBicepOutputs.sqlServerName.value
    $sqlDbName = $mainBicepOutputs.sqlDbName.value
    $eventHubNamespaceName = $mainBicepOutputs.eventHubNamespaceName.value
    $prodLocationDataEventHubName = $mainBicepOutputs.prodLocationDataEventHubName.value
    $iotHubName = $mainBicepOutputs.iotHubName.value
    $adxClusterName = $mainBicepOutputs.adxClusterName.value

    # Deploy dashboard (dependent on Container App)
    Write-Host "Running dashboard.bicep deployment..."
    az deployment group create --subscription "$subscriptionId" -g "$resourceGroup" -f "dashboard.bicep" -n "$deploymentNamePrefix-Dashboard" --mode "Incremental" `
        -p "@dashboard.parameters.json" `
        -p containerAppName=$containerAppName appInsightsName=$appInsightsName signalRName=$signalRName `
        -p sqlServerName=$sqlServerName sqlDbName=$sqlDbName `
        -p eventHubNamespaceName=$eventHubNamespaceName prodLocationDataEventHubName=$prodLocationDataEventHubName `
        -p iotHubName=$iotHubName adxClusterName=$adxClusterName | Out-Null

    if ($LASTEXITCODE -ne 0) {
        Pop-Location
        throw "Failed to deploy dashboard.bicep."
    }
    
    Pop-Location
}

Export-ModuleMember -Function Set-ResourceGroup, Deploy-MainTemplate, Deploy-AdxDataConnectionsTemplate, Deploy-ContainerAppTemplate, Deploy-DashboardTemplate, Set-SignalRUpstreamUrls, Get-SignalRUpstreamUrls
