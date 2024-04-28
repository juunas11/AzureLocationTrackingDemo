function Initialize-Cosmos {
    param(
        [Parameter(Mandatory = $true)]
        [object] $config,

        [Parameter(Mandatory = $true)]
        [object] $mainBicepOutputs,
        
        [Parameter(Mandatory = $true)]
        [string] $cosmosInitializerFolder
    )

    $tenantId = $config.tenantId

    $cosmosAccountEndpoint = $mainBicepOutputs.cosmosAccountEndpoint.value
    $cosmosDatabaseName = $mainBicepOutputs.cosmosDatabaseName.value
    $cosmosGeofenceContainerName = $mainBicepOutputs.cosmosGeofenceContainerName.value

    Push-Location $cosmosInitializerFolder

    dotnet run azure "$cosmosAccountEndpoint" "$tenantId" "$cosmosDatabaseName" "$cosmosGeofenceContainerName"

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to initialize Cosmos DB"
    }
    
    Pop-Location
}

Export-ModuleMember -Function Initialize-Cosmos
